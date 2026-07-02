import type { FastifyInstance } from "fastify";
import { eq, and, asc, isNull } from "drizzle-orm";
import { withOrg } from "../../db/with-org.js";
import { trips, obdSessions, obdReadings, dtcEvents, vehicles } from "../../db/schema.js";

type ReadingInput = {
  recordedAt: string;
  rpmX4?: number;
  speedKmh?: number;
  coolantTempC?: number;
  throttlePos?: number;
  fuelLevelPct?: number;
  intakeAirTempC?: number;
  mafGps?: number;
  rawPids?: Record<string, string>;
};

export default async function obdRoutes(app: FastifyInstance) {
  // -----------------------------------------------------------------------
  // POST /trips/:id/obd/sessions — start an OBD session (BLE connected)
  // -----------------------------------------------------------------------
  app.post<{
    Params: { id: string };
    Body: { adapterName?: string; adapterMac?: string };
  }>(
    "/trips/:id/obd/sessions",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          properties: {
            adapterName: { type: "string" },
            adapterMac: { type: "string" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const tripId = req.params.id;

      const [session] = await withOrg(orgId, sub, async (tx) => {
        const [trip] = await tx
          .select({ id: trips.id })
          .from(trips)
          .where(and(eq(trips.id, tripId), eq(trips.orgId, orgId)));
        if (!trip) return [];
        return tx
          .insert(obdSessions)
          .values({ tripId, orgId, adapterName: req.body.adapterName, adapterMac: req.body.adapterMac })
          .returning();
      });

      if (!session) return reply.code(404).send({ error: "Trip not found" });
      return reply.code(201).send(session);
    },
  );

  // -----------------------------------------------------------------------
  // PATCH /trips/:id/obd/sessions/:sid — close session + set protocol
  // -----------------------------------------------------------------------
  app.patch<{
    Params: { id: string; sid: string };
    Body: { elmProtocol?: string };
  }>(
    "/trips/:id/obd/sessions/:sid",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [updated] = await withOrg(orgId, sub, (tx) =>
        tx
          .update(obdSessions)
          .set({ disconnectedAt: new Date(), elmProtocol: req.body.elmProtocol ?? null })
          .where(
            and(
              eq(obdSessions.id, req.params.sid),
              eq(obdSessions.tripId, req.params.id),
              eq(obdSessions.orgId, orgId),
            ),
          )
          .returning(),
      );
      if (!updated) return reply.code(404).send({ error: "Session not found" });
      return updated;
    },
  );

  // -----------------------------------------------------------------------
  // POST /trips/:id/obd/readings — batch ingest OBD readings
  // -----------------------------------------------------------------------
  app.post<{
    Params: { id: string };
    Body: { readings: ReadingInput[]; sessionId?: string };
  }>(
    "/trips/:id/obd/readings",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          required: ["readings"],
          properties: {
            readings: {
              type: "array",
              items: {
                type: "object",
                required: ["recordedAt"],
                properties: {
                  recordedAt: { type: "string" },
                  rpmX4: { type: "integer" },
                  speedKmh: { type: "integer" },
                  coolantTempC: { type: "integer" },
                  throttlePos: { type: "number" },
                  fuelLevelPct: { type: "number" },
                  intakeAirTempC: { type: "integer" },
                  mafGps: { type: "number" },
                  rawPids: { type: "object" },
                },
              },
            },
            sessionId: { type: "string" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const tripId = req.params.id;
      const { readings, sessionId } = req.body;

      if (!readings.length) return reply.code(400).send({ error: "No readings provided" });

      const inserted = await withOrg(orgId, sub, async (tx) => {
        const [trip] = await tx
          .select({ id: trips.id })
          .from(trips)
          .where(and(eq(trips.id, tripId), eq(trips.orgId, orgId)));
        if (!trip) return null;

        await tx.insert(obdReadings).values(
          readings.map((r) => ({
            tripId,
            orgId,
            sessionId: sessionId ?? null,
            recordedAt: new Date(r.recordedAt),
            rpmX4: r.rpmX4 ?? null,
            speedKmh: r.speedKmh ?? null,
            coolantTempC: r.coolantTempC ?? null,
            throttlePos: r.throttlePos != null ? String(r.throttlePos) : null,
            fuelLevelPct: r.fuelLevelPct != null ? String(r.fuelLevelPct) : null,
            intakeAirTempC: r.intakeAirTempC ?? null,
            mafGps: r.mafGps != null ? String(r.mafGps) : null,
            rawPids: r.rawPids ?? null,
          })),
        );
        return readings.length;
      });

      if (inserted === null) return reply.code(404).send({ error: "Trip not found" });
      return reply.code(201).send({ inserted });
    },
  );

  // -----------------------------------------------------------------------
  // GET /trips/:id/obd/readings — retrieve OBD readings for a trip
  // -----------------------------------------------------------------------
  app.get<{ Params: { id: string } }>(
    "/trips/:id/obd/readings",
    { preHandler: [app.authenticate] },
    async (req) => {
      const { orgId, sub } = req.user;
      return withOrg(orgId, sub, (tx) =>
        tx
          .select()
          .from(obdReadings)
          .where(and(eq(obdReadings.tripId, req.params.id), eq(obdReadings.orgId, orgId)))
          .orderBy(asc(obdReadings.recordedAt)),
      );
    },
  );

  // -----------------------------------------------------------------------
  // GET /trips/:id/dtc — list all DTC events recorded during this trip
  // -----------------------------------------------------------------------
  app.get<{ Params: { id: string } }>(
    "/trips/:id/dtc",
    { preHandler: [app.authenticate] },
    async (req) => {
      const { orgId, sub } = req.user;
      return withOrg(orgId, sub, (tx) =>
        tx
          .select()
          .from(dtcEvents)
          .where(and(eq(dtcEvents.tripId, req.params.id), eq(dtcEvents.orgId, orgId)))
          .orderBy(asc(dtcEvents.detectedAt)),
      );
    },
  );

  // -----------------------------------------------------------------------
  // POST /trips/:id/dtc — report DTC codes found during this trip
  // Body: { codes: Array<{ code, description?, severity? }>, vehicleId? }
  // -----------------------------------------------------------------------
  app.post<{
    Params: { id: string };
    Body: {
      codes: Array<{ code: string; description?: string; severity?: string }>;
      vehicleId?: string;
    };
  }>(
    "/trips/:id/dtc",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          required: ["codes"],
          properties: {
            codes: {
              type: "array",
              items: {
                type: "object",
                required: ["code"],
                properties: {
                  code: { type: "string" },
                  description: { type: "string" },
                  severity: { type: "string", enum: ["info", "warning", "error"] },
                },
              },
            },
            vehicleId: { type: "string" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const tripId = req.params.id;
      const { codes, vehicleId } = req.body;

      const inserted = await withOrg(orgId, sub, async (tx) => {
        const [trip] = await tx
          .select({ id: trips.id })
          .from(trips)
          .where(and(eq(trips.id, tripId), eq(trips.orgId, orgId)));
        if (!trip) return null;

        return tx
          .insert(dtcEvents)
          .values(
            codes.map((c) => ({
              tripId,
              orgId,
              vehicleId: vehicleId ?? null,
              code: c.code,
              description: c.description ?? null,
              severity: c.severity ?? "warning",
            })),
          )
          .returning();
      });

      if (inserted === null) return reply.code(404).send({ error: "Trip not found" });
      return reply.code(201).send(inserted);
    },
  );

  // -----------------------------------------------------------------------
  // GET /vehicles/:vid/dtc — list active (uncleared) DTCs for a vehicle
  // -----------------------------------------------------------------------
  app.get<{ Params: { vid: string } }>(
    "/vehicles/:vid/dtc",
    { preHandler: [app.authenticate] },
    async (req) => {
      const { orgId, sub } = req.user;
      return withOrg(orgId, sub, (tx) =>
        tx
          .select()
          .from(dtcEvents)
          .where(
            and(
              eq(dtcEvents.vehicleId, req.params.vid),
              eq(dtcEvents.orgId, orgId),
              isNull(dtcEvents.clearedAt),
            ),
          ),
      );
    },
  );

  // -----------------------------------------------------------------------
  // POST /vehicles/:vid/dtc/clear — mark all DTCs as cleared for a vehicle
  // -----------------------------------------------------------------------
  app.post<{ Params: { vid: string } }>(
    "/vehicles/:vid/dtc/clear",
    { preHandler: [app.authenticate] },
    async (req) => {
      const { orgId, sub } = req.user;
      const cleared = await withOrg(orgId, sub, (tx) =>
        tx
          .update(dtcEvents)
          .set({ clearedAt: new Date() })
          .where(
            and(
              eq(dtcEvents.vehicleId, req.params.vid),
              eq(dtcEvents.orgId, orgId),
              isNull(dtcEvents.clearedAt),
            ),
          )
          .returning({ id: dtcEvents.id }),
      );
      return { cleared: cleared.length };
    },
  );
}
