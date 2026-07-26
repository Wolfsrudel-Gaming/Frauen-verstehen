import type { FastifyInstance } from "fastify";
import { eq, and, desc, getTableColumns } from "drizzle-orm";
import { withOrg } from "../../db/with-org.js";
import { trips, tripScores } from "../../db/schema.js";
import { scoreAndStoreTrip } from "../scoring/service.js";

export default async function tripRoutes(app: FastifyInstance) {
  // -----------------------------------------------------------------------
  // GET /trips — list trips in current org (most recent first), incl. score
  // -----------------------------------------------------------------------
  app.get("/trips", { preHandler: [app.authenticate] }, async (req) => {
    const { orgId, sub } = req.user;
    return withOrg(orgId, sub, (tx) =>
      tx
        .select({
          ...getTableColumns(trips),
          score: tripScores.totalScore,
          scoreConfidence: tripScores.confidenceWeight,
          scoreSource: tripScores.sourceType,
          scoreBreakdown: tripScores.breakdown,
        })
        .from(trips)
        .leftJoin(tripScores, eq(tripScores.tripId, trips.id))
        .where(eq(trips.orgId, orgId))
        .orderBy(desc(trips.startedAt)),
    );
  });

  // -----------------------------------------------------------------------
  // POST /trips/start — start a new trip
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      vehicleId?: string;
      startOdometer?: number;
      startTrigger?: string;
      notes?: string;
    };
  }>(
    "/trips/start",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          properties: {
            vehicleId: { type: "string" },
            startOdometer: { type: "integer" },
            startTrigger: { type: "string", enum: ["manual", "auto_obd", "auto_gps", "auto_bt"] },
            notes: { type: "string" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const { vehicleId, startOdometer, startTrigger = "manual", notes } = req.body;

      const [trip] = await withOrg(orgId, sub, (tx) =>
        tx
          .insert(trips)
          .values({
            orgId,
            driverUserId: sub,
            vehicleId: vehicleId ?? null,
            startOdometer: startOdometer ?? null,
            startTrigger,
            notes: notes ?? null,
            status: "in_progress",
          })
          .returning(),
      );
      return reply.code(201).send(trip);
    },
  );

  // -----------------------------------------------------------------------
  // POST /trips/:id/end — end an in-progress trip
  // -----------------------------------------------------------------------
  app.post<{
    Params: { id: string };
    Body: {
      endOdometer?: number;
      distanceKm?: string;
      endTrigger?: string;
      notes?: string;
    };
  }>(
    "/trips/:id/end",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          properties: {
            endOdometer: { type: "integer" },
            distanceKm: { type: "string" },
            endTrigger: { type: "string", enum: ["manual", "auto_obd", "auto_gps", "auto_bt"] },
            notes: { type: "string" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const { endOdometer, distanceKm, endTrigger = "manual", notes } = req.body;

      const [trip] = await withOrg(orgId, sub, async (tx) => {
        const [existing] = await tx
          .select()
          .from(trips)
          .where(and(eq(trips.id, req.params.id), eq(trips.orgId, orgId)));

        if (!existing) return [];
        if (existing.status !== "in_progress") return [];

        return tx
          .update(trips)
          .set({
            status: "completed",
            endedAt: new Date(),
            endOdometer: endOdometer ?? null,
            // Keep the distance accumulated from GPS points unless the
            // client explicitly provides one.
            distanceKm: distanceKm ?? existing.distanceKm,
            endTrigger,
            notes: notes ?? existing.notes,
            updatedAt: new Date(),
          })
          .where(eq(trips.id, req.params.id))
          .returning();
      });

      if (!trip) return reply.code(404).send({ error: "Trip not found or already ended" });

      // Score the completed trip. Failures must never fail the trip end.
      try {
        await withOrg(orgId, sub, (tx) => scoreAndStoreTrip(tx, orgId, trip.id));
      } catch (err) {
        req.log.warn({ err, tripId: trip.id }, "trip scoring failed");
      }
      return trip;
    },
  );

  // -----------------------------------------------------------------------
  // GET /trips/:id — get a single trip
  // -----------------------------------------------------------------------
  app.get<{ Params: { id: string } }>(
    "/trips/:id",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [trip] = await withOrg(orgId, sub, (tx) =>
        tx
          .select()
          .from(trips)
          .where(and(eq(trips.id, req.params.id), eq(trips.orgId, orgId))),
      );
      if (!trip) return reply.code(404).send({ error: "Trip not found" });
      return trip;
    },
  );

  // -----------------------------------------------------------------------
  // PATCH /trips/:id — update trip metadata (notes, odometer corrections)
  // -----------------------------------------------------------------------
  app.patch<{
    Params: { id: string };
    Body: Partial<{
      notes: string;
      startOdometer: number;
      endOdometer: number;
      distanceKm: string;
    }>;
  }>(
    "/trips/:id",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [updated] = await withOrg(orgId, sub, (tx) =>
        tx
          .update(trips)
          .set({ ...req.body, updatedAt: new Date() })
          .where(and(eq(trips.id, req.params.id), eq(trips.orgId, orgId)))
          .returning(),
      );
      if (!updated) return reply.code(404).send({ error: "Trip not found" });
      return updated;
    },
  );

  // -----------------------------------------------------------------------
  // POST /trips/:id/discard — mark a trip as discarded
  // -----------------------------------------------------------------------
  app.post<{ Params: { id: string } }>(
    "/trips/:id/discard",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [updated] = await withOrg(orgId, sub, (tx) =>
        tx
          .update(trips)
          .set({ status: "discarded", updatedAt: new Date() })
          .where(
            and(
              eq(trips.id, req.params.id),
              eq(trips.orgId, orgId),
              eq(trips.status, "in_progress"),
            ),
          )
          .returning({ id: trips.id }),
      );
      if (!updated) return reply.code(404).send({ error: "Trip not found or not in-progress" });
      return { ok: true };
    },
  );
}
