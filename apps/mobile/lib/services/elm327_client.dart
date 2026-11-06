import 'dart:async';
import 'dart:convert';
import 'ble_service.dart';

// ELM327 AT command client.
// Handles the prompt-based request/response protocol over BLE.
//
// Robustness notes (learned the hard way):
// - The RX line can hold stale bytes when we attach (e.g. the tail of the
//   auto-detect probe's ATI response, ending in '>'). Without draining,
//   every command would complete with the PREVIOUS command's response and
//   the whole init sequence desynchronises — protocol detection and the
//   supported-PID bitmaps then parse garbage and polling reads nothing.
//   Therefore: drain until the line is quiet before init, and clear the
//   buffer at the start of every command.
// - ATZ reboots the adapter; it needs a long timeout and prints a banner.
class Elm327Client {
  static const Duration _cmdTimeout = Duration(seconds: 5);
  static const String _prompt = '>';

  final StringBuffer _buf = StringBuffer();
  StreamSubscription<List<int>>? _rxSub;
  Completer<String>? _pending;
  DateTime _lastRx = DateTime.fromMillisecondsSinceEpoch(0);

  // -------------------------------------------------------------------------
  // Open the ELM327 channel and run initialisation sequence
  // Returns the detected OBD protocol name (e.g. 'ISO 15765-4 CAN')
  // -------------------------------------------------------------------------
  Future<String> init() async {
    _rxSub ??= BleService.rxStream.listen(_onBytes, onError: _onError);

    // Absorb any stale bytes (probe residue, old banners) until the line
    // has been quiet for a moment — only then is request/response reliable.
    await _drainUntilQuiet();

    await _cmd('ATZ', timeout: const Duration(seconds: 8)); // reset (reboots)
    await _drainUntilQuiet(maxWait: const Duration(seconds: 1));
    await _cmd('ATE0');  // echo off
    await _cmd('ATL0');  // line feeds off
    await _cmd('ATS0');  // spaces off  ← keeps response parsing simple
    await _cmd('ATH0');  // headers off
    await _cmd('ATAT2'); // adaptive timing mode 2
    await _cmd('ATSP0'); // auto detect protocol

    // Trigger protocol detection by querying PID support bitmap.
    // First contact with the ECU can take a while (SEARCHING...).
    await _cmd('0100', timeout: const Duration(seconds: 15));

    // Get the detected protocol
    final proto = await _cmd('ATDP');
    return proto.trim();
  }

  // -------------------------------------------------------------------------
  // Send a single command, wait for the '>' prompt, return the response
  // -------------------------------------------------------------------------
  Future<String> sendCommand(String cmd, {Duration? timeout}) async {
    return _cmd(cmd, timeout: timeout);
  }

  // -------------------------------------------------------------------------
  // Read supported PIDs (mode 01, PID 00/20/40/60/80)
  // Returns a set of supported PID numbers in hex (e.g. {'0C', '0D', '05'})
  // -------------------------------------------------------------------------
  Future<Set<String>> supportedPids() async {
    final supported = <String>{};
    for (final pid in ['0100', '0120', '0140', '0160', '0180']) {
      try {
        final response = await _cmd(pid);
        final bits = parsePidBitmap(response, pid);
        if (bits.isEmpty && pid != '0100') break; // end of supported ranges
        supported.addAll(bits);
      } catch (_) {
        break; // stop at first unsupported range
      }
    }
    return supported;
  }

  // -------------------------------------------------------------------------
  // Read stored DTCs (mode 03)
  // Returns list of DTC strings e.g. ['P0301', 'P0420']
  // -------------------------------------------------------------------------
  Future<List<String>> readDtcs() async {
    final response = await _cmd('03', timeout: const Duration(seconds: 8));
    return parseDtcs(response);
  }

  Future<void> dispose() async {
    await _rxSub?.cancel();
    _rxSub = null;
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) {
      p.complete(''); // release any waiter without an unhandled error
    }
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  void _onBytes(List<int> bytes) {
    _lastRx = DateTime.now();
    _buf.write(utf8.decode(bytes, allowMalformed: true));
    final raw = _buf.toString();
    if (raw.contains(_prompt)) {
      final response = raw.replaceAll(_prompt, '').trim();
      _buf.clear();
      if (_pending != null && !_pending!.isCompleted) {
        _pending!.complete(response);
        _pending = null;
      }
    }
  }

  void _onError(Object err) {
    final p = _pending;
    _pending = null;
    if (p != null && !p.isCompleted) p.completeError(err);
  }

  Future<String> _cmd(String cmd, {Duration? timeout}) async {
    // Drop anything a previous command or stray banner left behind —
    // responses must always belong to the command just sent.
    _buf.clear();
    final completer = Completer<String>();
    _pending = completer;
    await BleService.write(cmd);
    return completer.future.timeout(timeout ?? _cmdTimeout, onTimeout: () {
      if (identical(_pending, completer)) _pending = null;
      throw TimeoutException('ELM327 command timeout: $cmd', timeout ?? _cmdTimeout);
    });
  }

  /// Waits until no bytes have arrived for [quiet], discarding everything.
  Future<void> _drainUntilQuiet({
    Duration quiet = const Duration(milliseconds: 300),
    Duration maxWait = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      final sinceLast = DateTime.now().difference(_lastRx);
      if (sinceLast >= quiet) break;
      await Future.delayed(const Duration(milliseconds: 60));
    }
    _buf.clear();
  }

  // Public + static so the decoding logic is unit-testable without BLE.
  static Set<String> parsePidBitmap(String response, String requestPid) {
    // Response is like "41 00 BE 3F A8 13" (header off, no spaces after ATS0)
    // ATS0 means spaces ARE removed — response is "4100BE3FA813"
    final clean = response.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (clean.length < 12) return {};

    // The echoed PID in the response must match the request — otherwise this
    // is a stale/foreign response and must not be parsed as a bitmap.
    final expectedHeader = '41${requestPid.substring(2)}'.toUpperCase();
    final idx = clean.toUpperCase().indexOf(expectedHeader);
    if (idx < 0 || clean.length < idx + 4 + 8) return {};

    final dataHex = clean.substring(idx + 4);
    final value = int.tryParse(dataHex.substring(0, 8), radix: 16);
    if (value == null) return {};

    final baseStr = requestPid.substring(2); // '00', '20', ...
    final base = int.parse(baseStr, radix: 16);
    final pids = <String>{};

    for (int bit = 0; bit < 32; bit++) {
      if ((value >> (31 - bit)) & 1 == 1) {
        final pidNum = base + bit + 1;
        pids.add(pidNum.toRadixString(16).padLeft(2, '0').toUpperCase());
      }
    }
    return pids;
  }

  static List<String> parseDtcs(String response) {
    // Mode 03 responses, one frame per line (ATS0 removes spaces):
    //   CAN (ISO 15765-4):  "4302030104 20" → "43" + count byte + DTC pairs
    //   Legacy (K-Line):    "43030104200000" → "43" + 3 DTC pairs, 0-padded
    // Each DTC is 2 bytes; the top 2 bits of the word encode P/C/B/U.
    final dtcs = <String>[];

    for (final line in response.split(RegExp(r'[\r\n]+'))) {
      final clean = line.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
      if (clean.length < 4 || !clean.startsWith('43')) continue;

      var data = clean.substring(2); // strip "43"
      // CAN frames carry a DTC-count byte after "43"; legacy frames don't.
      // With the count byte the payload length is ≡ 2 (mod 4), without it ≡ 0.
      if (data.length % 4 == 2) data = data.substring(2);

      for (int i = 0; i + 4 <= data.length; i += 4) {
        final word = int.tryParse(data.substring(i, i + 4), radix: 16);
        if (word == null || word == 0) continue; // 0000 = padding

        final type = (word >> 14) & 0x3;
        final prefix = ['P', 'C', 'B', 'U'][type];
        // DTC digits: bits 13-12 (first digit 0-3), then three hex nibbles
        final d1 = (word >> 12) & 0x3;
        final rest = (word & 0x0FFF).toRadixString(16).padLeft(3, '0').toUpperCase();
        final code = '$prefix$d1$rest';
        if (!dtcs.contains(code)) dtcs.add(code);
      }
    }
    return dtcs;
  }
}
