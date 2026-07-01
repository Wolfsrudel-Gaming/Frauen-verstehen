import 'elm327_client.dart';

// OBD-II PID decoder — wraps the ELM327 client with typed PID reads.
// All values are decoded per the SAE J1979 specification.
class ObdReading {
  final DateTime recordedAt;
  final int? rpmX4;       // RPM = rpmX4 / 4.0
  final int? speedKmh;
  final int? coolantTempC;
  final double? throttlePosPct;
  final double? fuelLevelPct;
  final int? intakeAirTempC;
  final double? mafGps;
  final Map<String, String> rawPids;

  double? get rpm => rpmX4 != null ? rpmX4! / 4.0 : null;

  const ObdReading({
    required this.recordedAt,
    this.rpmX4,
    this.speedKmh,
    this.coolantTempC,
    this.throttlePosPct,
    this.fuelLevelPct,
    this.intakeAirTempC,
    this.mafGps,
    this.rawPids = const {},
  });

  Map<String, dynamic> toJson() => {
    'recordedAt': recordedAt.toIso8601String(),
    if (rpmX4 != null) 'rpmX4': rpmX4,
    if (speedKmh != null) 'speedKmh': speedKmh,
    if (coolantTempC != null) 'coolantTempC': coolantTempC,
    if (throttlePosPct != null) 'throttlePos': throttlePosPct,
    if (fuelLevelPct != null) 'fuelLevelPct': fuelLevelPct,
    if (intakeAirTempC != null) 'intakeAirTempC': intakeAirTempC,
    if (mafGps != null) 'mafGps': mafGps,
    'rawPids': rawPids,
  };
}

class Obd2Adapter {
  final Elm327Client _elm;
  Set<String> _supported = {};

  Obd2Adapter(this._elm);

  Future<String> init() async {
    final protocol = await _elm.init();
    _supported = await _elm.supportedPids();
    return protocol;
  }

  bool supports(String pid) => _supported.contains(pid.toUpperCase());

  // -------------------------------------------------------------------------
  // Poll one full reading cycle — only queries PIDs the ECU supports
  // -------------------------------------------------------------------------
  Future<ObdReading> poll() async {
    final raw = <String, String>{};
    int? rpmX4;
    int? speedKmh;
    int? coolantTempC;
    double? throttlePos;
    double? fuelLevel;
    int? intakeAirTemp;
    double? mafGps;

    // RPM — PID 0C
    if (supports('0C')) {
      final r = await _sendPid('010C');
      if (r != null) {
        final bytes = _parseResponseBytes(r, '41', '0C', 4);
        if (bytes != null) rpmX4 = (bytes[0] << 8) | bytes[1]; // raw × 4
        raw['0C'] = r;
      }
    }

    // Vehicle speed — PID 0D
    if (supports('0D')) {
      final r = await _sendPid('010D');
      if (r != null) {
        final bytes = _parseResponseBytes(r, '41', '0D', 2);
        if (bytes != null) speedKmh = bytes[0];
        raw['0D'] = r;
      }
    }

    // Coolant temperature — PID 05
    if (supports('05')) {
      final r = await _sendPid('0105');
      if (r != null) {
        final bytes = _parseResponseBytes(r, '41', '05', 2);
        if (bytes != null) coolantTempC = bytes[0] - 40;
        raw['05'] = r;
      }
    }

    // Throttle position — PID 11
    if (supports('11')) {
      final r = await _sendPid('0111');
      if (r != null) {
        final bytes = _parseResponseBytes(r, '41', '11', 2);
        if (bytes != null) throttlePos = bytes[0] * 100.0 / 255.0;
        raw['11'] = r;
      }
    }

    // Fuel level — PID 2F
    if (supports('2F')) {
      final r = await _sendPid('012F');
      if (r != null) {
        final bytes = _parseResponseBytes(r, '41', '2F', 2);
        if (bytes != null) fuelLevel = bytes[0] * 100.0 / 255.0;
        raw['2F'] = r;
      }
    }

    // Intake air temperature — PID 0F
    if (supports('0F')) {
      final r = await _sendPid('010F');
      if (r != null) {
        final bytes = _parseResponseBytes(r, '41', '0F', 2);
        if (bytes != null) intakeAirTemp = bytes[0] - 40;
        raw['0F'] = r;
      }
    }

    // MAF air flow rate — PID 10
    if (supports('10')) {
      final r = await _sendPid('0110');
      if (r != null) {
        final bytes = _parseResponseBytes(r, '41', '10', 4);
        if (bytes != null) mafGps = ((bytes[0] << 8) | bytes[1]) / 100.0;
        raw['10'] = r;
      }
    }

    return ObdReading(
      recordedAt: DateTime.now().toUtc(),
      rpmX4: rpmX4,
      speedKmh: speedKmh,
      coolantTempC: coolantTempC,
      throttlePosPct: throttlePos,
      fuelLevelPct: fuelLevel,
      intakeAirTempC: intakeAirTemp,
      mafGps: mafGps,
      rawPids: raw,
    );
  }

  // -------------------------------------------------------------------------
  // Read stored DTC codes (mode 03)
  // -------------------------------------------------------------------------
  Future<List<String>> readDtcs() => _elm.readDtcs();

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  Future<String?> _sendPid(String pid) async {
    try {
      return await _elm.sendCommand(pid);
    } catch (_) {
      return null;
    }
  }

  // Parse ELM327 response bytes (ATS0 removes spaces, so response is hex run)
  // Expected pattern: "41<PID><data_bytes>"
  List<int>? _parseResponseBytes(String response, String mode, String pid, int expectedHexLen) {
    final clean = response.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');
    final header = '$mode$pid'.toUpperCase();
    final idx = clean.toUpperCase().indexOf(header);
    if (idx < 0) return null;

    final dataStart = idx + header.length;
    if (clean.length < dataStart + expectedHexLen - 2) return null; // -2 for header already counted

    final dataHex = clean.substring(dataStart, dataStart + (expectedHexLen - 2));
    final bytes = <int>[];
    for (int i = 0; i + 2 <= dataHex.length; i += 2) {
      final b = int.tryParse(dataHex.substring(i, i + 2), radix: 16);
      if (b != null) bytes.add(b);
    }
    return bytes.isEmpty ? null : bytes;
  }
}
