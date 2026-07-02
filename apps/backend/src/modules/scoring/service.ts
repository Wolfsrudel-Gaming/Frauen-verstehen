import { eq, and, asc } from "drizzle-orm";
import type { Tx } from "../../db/with-org.js";
import { trips, tripPoints, obdReadings, tripScores, scoreDefinitions } from "../../db/schema.js";
import {
  computeTripScore,
  DEFAULT_WEIGHTS,
  DEFAULT_THRESHOLDS,
  type ScoringWeights,
  type ScoringThresholds,
  type TripScoreResult,
} from "./engine.js";

// Computes and stores the score for a completed trip. Returns null when the
// trip has too little data to score (short/discarded trips).
export async function scoreAndStoreTrip(
  tx: Tx,
  orgId: string,
  tripId: string,
): Promise<TripScoreResult | null> {
  const [trip] = await tx
    .select({
      id: trips.id,
      driverUserId: trips.driverUserId,
      distanceKm: trips.distanceKm,
      status: trips.status,
    })
    .from(trips)
    .where(and(eq(trips.id, tripId), eq(trips.orgId, orgId)));
  if (!trip || trip.status !== "completed") return null;

  const distanceKm = trip.distanceKm != null ? Number(trip.distanceKm) : 0;

  const points = await tx
    .select({ speedKmh: tripPoints.speedKmh, recordedAt: tripPoints.recordedAt })
    .from(tripPoints)
    .where(and(eq(tripPoints.tripId, tripId), eq(tripPoints.orgId, orgId)))
    .orderBy(asc(tripPoints.recordedAt));

  const obd = await tx
    .select({
      rpmX4: obdReadings.rpmX4,
      coolantTempC: obdReadings.coolantTempC,
      recordedAt: obdReadings.recordedAt,
    })
    .from(obdReadings)
    .where(and(eq(obdReadings.tripId, tripId), eq(obdReadings.orgId, orgId)))
    .orderBy(asc(obdReadings.recordedAt));

  const [def] = await tx
    .select({ weights: scoreDefinitions.weights, thresholds: scoreDefinitions.thresholds })
    .from(scoreDefinitions)
    .where(and(eq(scoreDefinitions.orgId, orgId), eq(scoreDefinitions.isActive, true)))
    .limit(1);

  const weights = { ...DEFAULT_WEIGHTS, ...((def?.weights as Partial<ScoringWeights>) ?? {}) };
  const thresholds = {
    ...DEFAULT_THRESHOLDS,
    ...((def?.thresholds as Partial<ScoringThresholds>) ?? {}),
  };

  const result = computeTripScore(
    points.map((p) => ({
      speedKmh: p.speedKmh != null ? Number(p.speedKmh) : null,
      recordedAt: p.recordedAt,
    })),
    obd.map((r) => ({ rpmX4: r.rpmX4, coolantTempC: r.coolantTempC, recordedAt: r.recordedAt })),
    distanceKm,
    weights,
    thresholds,
  );
  if (!result) return null;

  await tx
    .insert(tripScores)
    .values({
      tripId,
      orgId,
      driverUserId: trip.driverUserId,
      totalScore: String(result.totalScore),
      breakdown: result.breakdown,
      confidenceWeight: String(result.confidenceWeight),
      sourceType: result.sourceType,
    })
    .onConflictDoUpdate({
      target: tripScores.tripId,
      set: {
        totalScore: String(result.totalScore),
        breakdown: result.breakdown,
        confidenceWeight: String(result.confidenceWeight),
        sourceType: result.sourceType,
        computedAt: new Date(),
      },
    });

  return result;
}
