// Driving-behaviour scoring engine (M5).
//
// Pure functions — no DB access — so the algorithm is unit-testable and can
// be kept in sync with the Dart port used for offline mode in the mobile app
// (apps/mobile/lib/services/scoring_service.dart). Change both together.

export type ScoringWeights = {
  harshAccel: number; // penalty points per harsh-accel event per 100 km
  harshBrake: number; // penalty points per harsh-brake event per 100 km
  smoothness: number; // penalty per m/s² of accel stddev above 1.0
  overRev: number; // penalty per fraction of samples above overRevRpm
  overheat: number; // flat penalty when coolant exceeded overheatC
};

export type ScoringThresholds = {
  harshAccelMs2: number; // accel above this (m/s²) counts as harsh
  harshBrakeMs2: number; // accel below this (negative, m/s²) counts as harsh
  overRevRpm: number;
  overheatC: number;
};

export const DEFAULT_WEIGHTS: ScoringWeights = {
  harshAccel: 2.0,
  harshBrake: 2.5,
  smoothness: 5.0,
  overRev: 50,
  overheat: 10,
};

export const DEFAULT_THRESHOLDS: ScoringThresholds = {
  harshAccelMs2: 2.5,
  harshBrakeMs2: -3.0,
  overRevRpm: 4000,
  overheatC: 105,
};

export type GpsSample = { speedKmh: number | null; recordedAt: Date };
export type ObdSample = { rpmX4: number | null; coolantTempC: number | null; recordedAt: Date };

export type ScoreBreakdown = {
  metrics: {
    points: number;
    obdReadings: number;
    distanceKm: number;
    harshAccelCount: number;
    harshBrakeCount: number;
    harshAccelPer100Km: number;
    harshBrakePer100Km: number;
    accelStdDevMs2: number;
    overRevFraction: number;
    maxCoolantC: number | null;
  };
  penalties: {
    harshAccel: number;
    harshBrake: number;
    smoothness: number;
    overRev: number;
    overheat: number;
  };
};

export type TripScoreResult = {
  totalScore: number; // 0..100
  confidenceWeight: number; // 0..1
  sourceType: "combined" | "obd" | "gps";
  breakdown: ScoreBreakdown;
};

// Minimum data for a meaningful score
const MIN_POINTS = 5;
const MIN_DISTANCE_KM = 0.3;

// Acceleration samples derived from GPS speed deltas are only trusted when
// the gap between fixes is sane.
const MIN_DT_S = 0.5;
const MAX_DT_S = 10;

export function computeTripScore(
  gps: GpsSample[],
  obd: ObdSample[],
  distanceKm: number,
  weights: ScoringWeights = DEFAULT_WEIGHTS,
  thresholds: ScoringThresholds = DEFAULT_THRESHOLDS,
): TripScoreResult | null {
  const speedSamples = gps.filter((p) => p.speedKmh != null);
  if (speedSamples.length < MIN_POINTS || distanceKm < MIN_DISTANCE_KM) return null;

  // ---- acceleration series from consecutive GPS speeds ----
  const accels: number[] = [];
  for (let i = 1; i < speedSamples.length; i++) {
    const dtS = (speedSamples[i].recordedAt.getTime() - speedSamples[i - 1].recordedAt.getTime()) / 1000;
    if (dtS < MIN_DT_S || dtS > MAX_DT_S) continue;
    const dvMs = ((speedSamples[i].speedKmh! - speedSamples[i - 1].speedKmh!) * 1000) / 3600;
    accels.push(dvMs / dtS);
  }

  const harshAccelCount = accels.filter((a) => a > thresholds.harshAccelMs2).length;
  const harshBrakeCount = accels.filter((a) => a < thresholds.harshBrakeMs2).length;
  const per100 = 100 / distanceKm;
  const harshAccelPer100 = harshAccelCount * per100;
  const harshBrakePer100 = harshBrakeCount * per100;

  const mean = accels.length ? accels.reduce((s, a) => s + a, 0) / accels.length : 0;
  const stdDev = accels.length
    ? Math.sqrt(accels.reduce((s, a) => s + (a - mean) ** 2, 0) / accels.length)
    : 0;

  // ---- OBD metrics ----
  const rpmSamples = obd.filter((r) => r.rpmX4 != null);
  const overRevCount = rpmSamples.filter((r) => r.rpmX4! / 4 > thresholds.overRevRpm).length;
  const overRevFraction = rpmSamples.length ? overRevCount / rpmSamples.length : 0;
  const coolantValues = obd.filter((r) => r.coolantTempC != null).map((r) => r.coolantTempC!);
  const maxCoolant = coolantValues.length ? Math.max(...coolantValues) : null;
  const overheated = maxCoolant != null && maxCoolant > thresholds.overheatC;

  // ---- penalties (each capped so one bad metric can't zero the score) ----
  const penalties = {
    harshAccel: Math.min(40, harshAccelPer100 * weights.harshAccel),
    harshBrake: Math.min(40, harshBrakePer100 * weights.harshBrake),
    smoothness: Math.min(10, Math.max(0, stdDev - 1.0) * weights.smoothness),
    overRev: Math.min(10, overRevFraction * weights.overRev),
    overheat: overheated ? weights.overheat : 0,
  };

  const totalPenalty = Object.values(penalties).reduce((s, p) => s + p, 0);
  const totalScore = Math.max(0, Math.min(100, 100 - totalPenalty));

  // ---- confidence: more data → more trust; OBD adds trust ----
  const hasObd = obd.length >= 10;
  let confidence = 0.6;
  if (speedSamples.length >= 50) confidence += 0.2;
  if (hasObd) confidence += 0.2;
  confidence = Math.min(1.0, confidence);

  const sourceType: TripScoreResult["sourceType"] = hasObd
    ? gps.length > 0
      ? "combined"
      : "obd"
    : "gps";

  return {
    totalScore: Math.round(totalScore * 10) / 10,
    confidenceWeight: Math.round(confidence * 100) / 100,
    sourceType,
    breakdown: {
      metrics: {
        points: speedSamples.length,
        obdReadings: obd.length,
        distanceKm: Math.round(distanceKm * 1000) / 1000,
        harshAccelCount,
        harshBrakeCount,
        harshAccelPer100Km: Math.round(harshAccelPer100 * 10) / 10,
        harshBrakePer100Km: Math.round(harshBrakePer100 * 10) / 10,
        accelStdDevMs2: Math.round(stdDev * 100) / 100,
        overRevFraction: Math.round(overRevFraction * 1000) / 1000,
        maxCoolantC: maxCoolant,
      },
      penalties: {
        harshAccel: Math.round(penalties.harshAccel * 10) / 10,
        harshBrake: Math.round(penalties.harshBrake * 10) / 10,
        smoothness: Math.round(penalties.smoothness * 10) / 10,
        overRev: Math.round(penalties.overRev * 10) / 10,
        overheat: Math.round(penalties.overheat * 10) / 10,
      },
    },
  };
}
