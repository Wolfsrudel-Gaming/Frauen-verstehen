import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/scoring_service.dart';

// Mirrors apps/backend/test/scoring.test.ts — both engines must agree.
List<GpsSample> gpsSeries(List<double> speedsKmh) {
  final t0 = DateTime.parse('2026-01-01T10:00:00Z');
  return List.generate(
    speedsKmh.length,
    (i) => GpsSample(speedKmh: speedsKmh[i], recordedAt: t0.add(Duration(seconds: i))),
  );
}

List<ObdSample> obdSeries(List<int> rpms, {int coolant = 90}) {
  final t0 = DateTime.parse('2026-01-01T10:00:00Z');
  return List.generate(
    rpms.length,
    (i) => ObdSample(
      rpmX4: rpms[i] * 4,
      coolantTempC: coolant,
      recordedAt: t0.add(Duration(seconds: i * 2)),
    ),
  );
}

void main() {
  test('returns null with too little data', () {
    expect(ScoringService.computeTripScore(gpsSeries([10, 20]), [], 5), isNull);
    expect(
      ScoringService.computeTripScore(gpsSeries([10, 20, 30, 40, 50, 60]), [], 0.1),
      isNull,
    );
  });

  test('perfect score for smooth constant driving', () {
    final result =
        ScoringService.computeTripScore(gpsSeries(List.filled(60, 50.0)), [], 10);
    expect(result, isNotNull);
    expect(result!.totalScore, 100);
    expect(result.sourceType, 'gps');
  });

  test('penalises harsh braking', () {
    final speeds = [...List.filled(30, 50.0), 15.0, 15.0, 15.0, 15.0, 15.0];
    final result = ScoringService.computeTripScore(gpsSeries(speeds), [], 1);
    expect(result, isNotNull);
    final metrics = result!.breakdown['metrics'] as Map<String, dynamic>;
    expect(metrics['harshBrakeCount'], greaterThanOrEqualTo(1));
    expect(result.totalScore, lessThan(100));
  });

  test('matches backend confidence tiers', () {
    final few = ScoringService.computeTripScore(gpsSeries(List.filled(10, 50.0)), [], 5);
    final many = ScoringService.computeTripScore(gpsSeries(List.filled(100, 50.0)), [], 5);
    final withObd = ScoringService.computeTripScore(
      gpsSeries(List.filled(100, 50.0)),
      obdSeries(List.filled(30, 2000)),
      5,
    );
    expect(few!.confidenceWeight, 0.6);
    expect(many!.confidenceWeight, 0.8);
    expect(withObd!.confidenceWeight, 1.0);
    expect(withObd.sourceType, 'combined');
  });

  test('caps over-rev penalty and flags overheat', () {
    final smooth = gpsSeries(List.filled(60, 50.0));
    final result = ScoringService.computeTripScore(
      smooth,
      obdSeries(List.filled(30, 5500), coolant: 112),
      10,
    );
    final penalties = result!.breakdown['penalties'] as Map<String, double>;
    expect(penalties['overRev'], 10); // capped
    expect(penalties['overheat'], 10);
    expect(result.totalScore, 80);
  });

  test('ignores GPS gaps too long for acceleration inference', () {
    final t0 = DateTime.parse('2026-01-01T10:00:00Z');
    final gps = [
      GpsSample(speedKmh: 10, recordedAt: t0),
      GpsSample(speedKmh: 10, recordedAt: t0.add(const Duration(seconds: 1))),
      GpsSample(speedKmh: 10, recordedAt: t0.add(const Duration(seconds: 2))),
      GpsSample(speedKmh: 100, recordedAt: t0.add(const Duration(seconds: 62))),
      GpsSample(speedKmh: 100, recordedAt: t0.add(const Duration(seconds: 63))),
      GpsSample(speedKmh: 100, recordedAt: t0.add(const Duration(seconds: 64))),
    ];
    final result = ScoringService.computeTripScore(gps, [], 5);
    final metrics = result!.breakdown['metrics'] as Map<String, dynamic>;
    expect(metrics['harshAccelCount'], 0);
  });
}
