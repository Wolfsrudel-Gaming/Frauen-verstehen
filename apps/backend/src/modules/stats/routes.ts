import type { FastifyInstance } from "fastify";
import { eq, and, sql, desc, isNull, gte, max } from "drizzle-orm";
import { withOrg } from "../../db/with-org.js";
import { trips, tripScores, vehicles, dtcEvents, obdReadings } from "../../db/schema.js";

export default async function statsRoutes(app: FastifyInstance) {
  // -----------------------------------------------------------------------
  // GET /stats/overview — org totals for the dashboard
  // -----------------------------------------------------------------------
  app.get<{ Querystring: { days?: string } }>(
    "/stats/overview",
    { preHandler: [app.authenticate] },
    async (req) => {
      const { orgId, sub } = req.user;
      const days = req.query.days ? Number(req.query.days) : null;
      const since = days ? new Date(Date.now() - days * 24 * 3600 * 1000) : null;

      return withOrg(orgId, sub, async (tx) => {
        const tripConditions = [eq(trips.orgId, orgId), eq(trips.status, "completed")];
        if (since) tripConditions.push(gte(trips.startedAt, since));

        const [totals] = await tx
          .select({
            tripCount: sql<string>`count(*)`,
            totalKm: sql<string>`coalesce(sum(${trips.distanceKm}), 0)`,
            totalSeconds: sql<string>`
              coalesce(sum(extract(epoch from (${trips.endedAt} - ${trips.startedAt}))), 0)
            `,
          })
          .from(trips)
          .where(and(...tripConditions));

        const scoreConditions = [eq(tripScores.orgId, orgId)];
        if (since) scoreConditions.push(gte(tripScores.computedAt, since));

        const [scoreAgg] = await tx
          .select({
            avgScore: sql<string>`
              sum(${tripScores.totalScore} * ${tripScores.confidenceWeight})
              / nullif(sum(${tripScores.confidenceWeight}), 0)
            `,
            scoredTrips: sql<string>`count(*)`,
            bestScore: sql<string>`max(${tripScores.totalScore})`,
          })
          .from(tripScores)
          .where(and(...scoreConditions));

        const [vehicleAgg] = await tx
          .select({ activeVehicles: sql<string>`count(*)` })
          .from(vehicles)
          .where(and(eq(vehicles.orgId, orgId), eq(vehicles.isActive, true)));

        const [dtcAgg] = await tx
          .select({ openDtcs: sql<string>`count(*)` })
          .from(dtcEvents)
          .where(and(eq(dtcEvents.orgId, orgId), isNull(dtcEvents.clearedAt)));

        const [obdAgg] = await tx
          .select({ obdReadingCount: sql<string>`count(*)` })
          .from(obdReadings)
          .where(eq(obdReadings.orgId, orgId));

        return {
          tripCount: Number(totals?.tripCount ?? 0),
          totalKm: Math.round(Number(totals?.totalKm ?? 0) * 10) / 10,
          totalHours: Math.round((Number(totals?.totalSeconds ?? 0) / 3600) * 10) / 10,
          avgScore:
            scoreAgg?.avgScore != null ? Math.round(Number(scoreAgg.avgScore) * 10) / 10 : null,
          bestScore:
            scoreAgg?.bestScore != null ? Math.round(Number(scoreAgg.bestScore) * 10) / 10 : null,
          scoredTrips: Number(scoreAgg?.scoredTrips ?? 0),
          activeVehicles: Number(vehicleAgg?.activeVehicles ?? 0),
          openDtcs: Number(dtcAgg?.openDtcs ?? 0),
          obdReadings: Number(obdAgg?.obdReadingCount ?? 0),
        };
      });
    },
  );

  // -----------------------------------------------------------------------
  // GET /vehicles/:vid/stats — per-vehicle totals
  // -----------------------------------------------------------------------
  app.get<{ Params: { vid: string } }>(
    "/vehicles/:vid/stats",
    { preHandler: [app.authenticate] },
    async (req) => {
      const { orgId, sub } = req.user;
      const vid = req.params.vid;

      return withOrg(orgId, sub, async (tx) => {
        const [totals] = await tx
          .select({
            tripCount: sql<string>`count(*)`,
            totalKm: sql<string>`coalesce(sum(${trips.distanceKm}), 0)`,
            // max() keeps the column type so this serialises as ISO 8601
            lastTripAt: max(trips.startedAt),
          })
          .from(trips)
          .where(
            and(eq(trips.orgId, orgId), eq(trips.vehicleId, vid), eq(trips.status, "completed")),
          );

        const [scoreAgg] = await tx
          .select({
            avgScore: sql<string>`
              sum(${tripScores.totalScore} * ${tripScores.confidenceWeight})
              / nullif(sum(${tripScores.confidenceWeight}), 0)
            `,
          })
          .from(tripScores)
          .innerJoin(trips, eq(tripScores.tripId, trips.id))
          .where(and(eq(tripScores.orgId, orgId), eq(trips.vehicleId, vid)));

        const [dtcAgg] = await tx
          .select({ openDtcs: sql<string>`count(*)` })
          .from(dtcEvents)
          .where(
            and(
              eq(dtcEvents.orgId, orgId),
              eq(dtcEvents.vehicleId, vid),
              isNull(dtcEvents.clearedAt),
            ),
          );

        return {
          tripCount: Number(totals?.tripCount ?? 0),
          totalKm: Math.round(Number(totals?.totalKm ?? 0) * 10) / 10,
          lastTripAt: totals?.lastTripAt ?? null,
          avgScore:
            scoreAgg?.avgScore != null ? Math.round(Number(scoreAgg.avgScore) * 10) / 10 : null,
          openDtcs: Number(dtcAgg?.openDtcs ?? 0),
        };
      });
    },
  );

  // -----------------------------------------------------------------------
  // GET /vehicles/:vid/trips — trips recorded with this vehicle
  // -----------------------------------------------------------------------
  app.get<{ Params: { vid: string } }>(
    "/vehicles/:vid/trips",
    { preHandler: [app.authenticate] },
    async (req) => {
      const { orgId, sub } = req.user;
      return withOrg(orgId, sub, (tx) =>
        tx
          .select({
            id: trips.id,
            status: trips.status,
            startedAt: trips.startedAt,
            endedAt: trips.endedAt,
            distanceKm: trips.distanceKm,
            score: tripScores.totalScore,
          })
          .from(trips)
          .leftJoin(tripScores, eq(tripScores.tripId, trips.id))
          .where(and(eq(trips.orgId, orgId), eq(trips.vehicleId, req.params.vid)))
          .orderBy(desc(trips.startedAt))
          .limit(50),
      );
    },
  );
}
