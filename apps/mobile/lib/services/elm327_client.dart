import 'dart:async';
import 'dart:convert';
import 'ble_service.dart';

// ELM327 AT command client.
// Handles the prompt-based request/response protocol over BLE.
class Elm327Client {
  static const Duration _cmdTimeout = Duration(seconds: 5);
  static const String _prompt = '>';

  final StringBuffer _buf = StringBuffer();
  StreamSubscription<List<int>>? _rxSub;
  Completer<String>? _pending;

  // -------------------------------------------------------------------------
  // Open the ELM327 channel and run initialisation sequence
  // Returns the detected OBD protocol name (e.g. 'ISO 15765-4 CAN')
  // -------------------------------------------------------------------------
  Future<String> init() async {
    _rxSub = BleService.rxStream.listen(_onBytes, onError: _onError);

    await _cmd('ATZ');    // reset
    await _cmd('ATE0');   // echo off
    await _cmd('ATL0');   // line feeds off
    await _cmd('ATS0');   // spaces off  ← keeps response parsing simple
    await _cmd('ATH0');   // headers off
    await _cmd('ATAT2'); // adaptive timing mode 2
    await _cmd('ATSP0'); // auto detect protocol

    // Trigger protocol detection by querying PID support bitmap
    await _cmd('0100', timeout: const Duration(seconds: 10));

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
        final bits = _parsePidBitmap(response, pid);
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
    return _parseDtcs(response);
  }

  Future<void> dispose() async {
    await _rxSub?.cancel();
    _pending?.completeError(Exception('Disposed'));
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  void _onBytes(List<int> bytes) {
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
    _pending?.completeError(err);
    _pending = null;
  }

  Future<String> _cmd(String cmd, {Duration? timeout}) async {
    _pending = Completer<String>();
    await BleService.write(cmd);
    return _pending!.future.timeout(timeout ?? _cmdTimeout, onTimeout: () {
      _pending = null;
      throw TimeoutException('ELM327 command timeout: $cmd', timeout ?? _cmdTimeout);
    });
  }

  Set<String> _parsePidBitmap(String response, String requestPid) {
    // Response is like "41 00 BE 3F A8 13" (header off, no spaces after ATS0)
    // ATS0 means spaces ARE removed — response is "4100BE3FA813"
    final clean = response.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (clean.length < 12) return {};

    // Skip service byte (41) + PID echo (00) = first 4 hex chars
    final dataHex = clean.substring(4);
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

  List<String> _parseDtcs(String response) {
    // Mode 03 response (ATS0): "430301200000" — 43 = response mode
    // Each DTC is 2 bytes: first nibble encodes type (P/C/B/U)
    final clean = response.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    if (clean.length < 4 || clean.startsWith('43') == false) return [];

    final data = clean.substring(2); // strip "43"
    final dtcs = <String>[];
    for (int i = 0; i + 4 <= data.length; i += 4) {
      final word = int.tryParse(data.substring(i, i + 4), radix: 16);
      if (word == null || word == 0) continue;

      final type = (word >> 14) & 0x3;
      final code = (word & 0x3FFF).toString().padLeft(4, '0');
      final prefix = ['P', 'C', 'B', 'U'][type];
      dtcs.add('$prefix$code');
    }
    return dtcs;
  }
}
