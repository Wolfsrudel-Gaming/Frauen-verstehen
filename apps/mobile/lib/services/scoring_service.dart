import 'dart:math';

// Driving-behaviour scoring — Dart port of the backend engine
// (apps/backend/src/modules/scoring/engine.ts). Used for offline mode so
// trips scored on-device match trips scored by the server.
// IMPORTANT: change both implementations together.

class ScoringWeights {
  final double harshAccel;
  final double harshBrake;
  final double smoothness;
  final double overRev;
  final double overheat;

  const ScoringWeights({
    this.harshAccel = 2.0,
    this.harshBrake = 2.5,
    this.smoothness = 5.0,
    this.overRev = 50,
    this.overheat = 10,
  });
}

class ScoringThresholds {
  final double harshAccelMs2;
  final double harshBrakeMs2;
  final int overRevRpm;
  final int overheatC;

  const ScoringThresholds({
    this.harshAccelMs2 = 2.5,
    this.harshBrakeMs2 = -3.0,
    this.overRevRpm = 4000,
    this.overheatC = 105,
  });
}

class GpsSample {
  final double? speedKmh;
  final DateTime recordedAt;
  const GpsSample({required this.speedKmh, required this.recordedAt});
}

class ObdSample {
  final int? rpmX4;
  final int? coolantTempC;
  final DateTime recordedAt;
  const ObdSample({this.rpmX4, this.coolantTempC, required this.recordedAt});
}

class TripScoreResult {
  final double totalScore; // 0..100
  final double confidenceWeight; // 0..1
  final String sourceType; // 'combined' | 'obd' | 'gps'
  final Map<String, dynamic> breakdown;

  const TripScoreResult({
    required this.totalScore,
    required this.confidenceWeight,
    required this.sourceType,
    required this.breakdown,
  });
}

class ScoringService {
  static const int _minPoints = 5;
  static const double _minDistanceKm = 0.3;
  static const double _minDtS = 0.5;
  static const double _maxDtS = 10;

  static double _round(double v, int digits) {
    final f = pow(10, digits).toDouble();
    return (v * f).roundToDouble() / f;
  }

  static TripScoreResult? computeTripScore(
    List<GpsSample> gps,
    List<ObdSample> obd,
    double distanceKm, {
    ScoringWeights weights = const ScoringWeights(),
    ScoringThresholds thresholds = const ScoringThresholds(),
  }) {
    final speedSamples = gps.where((p) => p.speedKmh != null).toList();
    if (speedSamples.length < _minPoints || distanceKm < _minDistanceKm) return null;

    // ---- acceleration series from consecutive GPS speeds ----
    final accels = <double>[];
    for (int i = 1; i < speedSamples.length; i++) {
      final dtS = speedSamples[i]
              .recordedAt
              .difference(speedSamples[i - 1].recordedAt)
              .inMilliseconds /
          1000.0;
      if (dtS < _minDtS || dtS > _maxDtS) continue;
      final dvMs = (speedSamples[i].speedKmh! - speedSamples[i - 1].speedKmh!) * 1000 / 3600;
      accels.add(dvMs / dtS);
    }

    final harshAccelCount = accels.where((a) => a > thresholds.harshAccelMs2).length;
    final harshBrakeCount = accels.where((a) => a < thresholds.harshBrakeMs2).length;
    final per100 = 100 / distanceKm;
    final harshAccelPer100 = harshAccelCount * per100;
    final harshBrakePer100 = harshBrakeCount * per100;

    final mean = accels.isNotEmpty ? accels.reduce((a, b) => a + b) / accels.length : 0.0;
    final stdDev = accels.isNotEmpty
        ? sqrt(accels.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) / accels.length)
        : 0.0;

    // ---- OBD metrics ----
    final rpmSamples = obd.where((r) => r.rpmX4 != null).toList();
    final overRevCount =
        rpmSamples.where((r) => r.rpmX4! / 4 > thresholds.overRevRpm).length;
    final overRevFraction = rpmSamples.isNotEmpty ? overRevCount / rpmSamples.length : 0.0;
    final coolantValues =
        obd.where((r) => r.coolantTempC != null).map((r) => r.coolantTempC!).toList();
    final maxCoolant = coolantValues.isNotEmpty ? coolantValues.reduce(max) : null;
    final overheated = maxCoolant != null && maxCoolant > thresholds.overheatC;

    // ---- penalties (each capped, same as backend) ----
    final penalties = <String, double>{
      'harshAccel': min(40, harshAccelPer100 * weights.harshAccel),
      'harshBrake': min(40, harshBrakePer100 * weights.harshBrake),
      'smoothness': min(10, max(0, stdDev - 1.0) * weights.smoothness),
      'overRev': min(10, overRevFraction * weights.overRev),
      'overheat': overheated ? weights.overheat : 0,
    };

    final totalPenalty = penalties.values.reduce((a, b) => a + b);
    final totalScore = max(0.0, min(100.0, 100 - totalPenalty));

    // ---- confidence ----
    final hasObd = obd.length >= 10;
    var confidence = 0.6;
    if (speedSamples.length >= 50) confidence += 0.2;
    if (hasObd) confidence += 0.2;
    confidence = min(1.0, confidence);

    final sourceType = hasObd ? (gps.isNotEmpty ? 'combined' : 'obd') : 'gps';

    return TripScoreResult(
      totalScore: _round(totalScore, 1),
      confidenceWeight: _round(confidence, 2),
      sourceType: sourceType,
      breakdown: {
        'metrics': {
          'points': speedSamples.length,
          'obdReadings': obd.length,
          'distanceKm': _round(distanceKm, 3),
          'harshAccelCount': harshAccelCount,
          'harshBrakeCount': harshBrakeCount,
          'harshAccelPer100Km': _round(harshAccelPer100, 1),
          'harshBrakePer100Km': _round(harshBrakePer100, 1),
          'accelStdDevMs2': _round(stdDev, 2),
          'overRevFraction': _round(overRevFraction, 3),
          'maxCoolantC': maxCoolant,
        },
        'penalties': penalties.map((k, v) => MapEntry(k, _round(v, 1))),
      },
    );
  }
}
