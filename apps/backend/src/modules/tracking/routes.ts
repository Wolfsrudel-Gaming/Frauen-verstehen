import type { FastifyInstance } from "fastify";
import { eq, and, asc } from "drizzle-orm";
import { sql } from "drizzle-orm";
import { db } from "../../db/client.js";
import { trips, tripSegments, tripPoints } from "../../db/schema.js";

type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];

async function withOrg<T>(orgId: string, userId: string, fn: (tx: Tx) => Promise<T>): Promise<T> {
  return db.transaction(async (tx) => {
    await tx.execute(sql`SET LOCAL app.current_org_id = ${orgId}`);
    await tx.execute(sql`SET LOCAL app.current_user_id = ${userId}`);
    await tx.execute(sql`SET LOCAL app.bypass_rls = 'off'`);
    return fn(tx);
  });
}

type PointInput = {
  lat: number;
  lon: number;
  altitudeM?: number;
  accuracyM?: number;
  speedKmh?: number;
  headingDeg?: number;
  isEstimated?: boolean;
  recordedAt: string; // ISO 8601
};

// Haversine distance in km between two lat/lon pairs
function haversineKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function calcDistanceKm(points: PointInput[]): number {
  let total = 0;
  for (let i = 1; i < points.length; i++) {
    total += haversineKm(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon);
  }
  return total;
}

export default async function trackingRoutes(app: FastifyInstance) {
  // -----------------------------------------------------------------------
  // POST /trips/:id/points — batch ingest GPS points for a trip
  // Body: { points: PointInput[], segmentId?: string }
  // Creates a segment if segmentId not provided and there's no open one.
  // Updates trip.distance_km from all recorded points.
  // -----------------------------------------------------------------------
  app.post<{
    Params: { id: string };
    Body: { points: PointInput[]; segmentId?: string; sourceType?: string };
  }>(
    "/trips/:id/points",
    {
      preHandler: [app.authenticate],
      schema: {
        params: { type: "object", required: ["id"], properties: { id: { type: "string" } } },
        body: {
          type: "object",
          required: ["points"],
          properties: {
            points: {
              type: "array",
              items: {
                type: "object",
                required: ["lat", "lon", "recordedAt"],
                properties: {
                  lat: { type: "number" },
                  lon: { type: "number" },
                  altitudeM: { type: "number" },
                  accuracyM: { type: "number" },
                  speedKmh: { type: "number" },
                  headingDeg: { type: "number" },
                  isEstimated: { type: "boolean" },
                  recordedAt: { type: "string" },
                },
              },
            },
            segmentId: { type: "string" },
            sourceType: { type: "string" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const tripId = req.params.id;
      const { points, segmentId: providedSegmentId, sourceType = "smartphone_gps" } = req.body;

      if (!points.length) return reply.code(400).send({ error: "No points provided" });

      const result = await withOrg(orgId, sub, async (tx) => {
        // Verify the trip exists and belongs to this org
        const [trip] = await tx
          .select()
          .from(trips)
          .where(and(eq(trips.id, tripId), eq(trips.orgId, orgId)));
        if (!trip) return null;

        // Resolve or create the segment
        let segmentId = providedSegmentId;
        if (!segmentId) {
          const sortedPoints = [...points].sort(
            (a, b) => new Date(a.recordedAt).getTime() - new Date(b.recordedAt).getTime(),
          );
          const [seg] = await tx
            .insert(tripSegments)
            .values({
              tripId,
              orgId,
              sourceType,
              startedAt: new Date(sortedPoints[0].recordedAt),
            })
            .returning();
          segmentId = seg.id;
        }

        // Insert all points
        await tx.insert(tripPoints).values(
          points.map((p) => ({
            tripId,
            segmentId,
            orgId,
            lat: String(p.lat),
            lon: String(p.lon),
            altitudeM: p.altitudeM != null ? String(p.altitudeM) : null,
            accuracyM: p.accuracyM != null ? String(p.accuracyM) : null,
            speedKmh: p.speedKmh != null ? String(p.speedKmh) : null,
            headingDeg: p.headingDeg != null ? String(p.headingDeg) : null,
            isEstimated: p.isEstimated ?? false,
            recordedAt: new Date(p.recordedAt),
          })),
        );

        // Recompute distanceKm from all points for this trip
        const allPoints = await tx
          .select({ lat: tripPoints.lat, lon: tripPoints.lon, recordedAt: tripPoints.recordedAt })
          .from(tripPoints)
          .where(eq(tripPoints.tripId, tripId))
          .orderBy(asc(tripPoints.recordedAt));

        const distKm = calcDistanceKm(
          allPoints.map((p) => ({ lat: Number(p.lat), lon: Number(p.lon), recordedAt: String(p.recordedAt) })),
        );

        await tx
          .update(trips)
          .set({ distanceKm: distKm.toFixed(3), updatedAt: new Date() })
          .where(eq(trips.id, tripId));

        return { segmentId, pointsInserted: points.length, distanceKm: distKm.toFixed(3) };
      });

      if (!result) return reply.code(404).send({ error: "Trip not found" });
      return reply.code(201).send(result);
    },
  );

  // -----------------------------------------------------------------------
  // GET /trips/:id/points — retrieve all GPS points for a trip
  // -----------------------------------------------------------------------
  app.get<{ Params: { id: string } }>(
    "/trips/:id/points",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const tripId = req.params.id;

      const points = await withOrg(orgId, sub, (tx) =>
        tx
          .select()
          .from(tripPoints)
          .where(and(eq(tripPoints.tripId, tripId), eq(tripPoints.orgId, orgId)))
          .orderBy(asc(tripPoints.recordedAt)),
      );

      return points;
    },
  );

  // -----------------------------------------------------------------------
  // GET /trips/:id/segments — list segments for a trip
  // -----------------------------------------------------------------------
  app.get<{ Params: { id: string } }>(
    "/trips/:id/segments",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const tripId = req.params.id;

      const segments = await withOrg(orgId, sub, (tx) =>
        tx
          .select()
          .from(tripSegments)
          .where(and(eq(tripSegments.tripId, tripId), eq(tripSegments.orgId, orgId))),
      );

      return segments;
    },
  );

  // -----------------------------------------------------------------------
  // PATCH /trips/:id/segments/:segId — close a segment (set ended_at)
  // -----------------------------------------------------------------------
  app.patch<{ Params: { id: string; segId: string } }>(
    "/trips/:id/segments/:segId",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;

      const [updated] = await withOrg(orgId, sub, (tx) =>
        tx
          .update(tripSegments)
          .set({ endedAt: new Date() })
          .where(
            and(
              eq(tripSegments.id, req.params.segId),
              eq(tripSegments.tripId, req.params.id),
              eq(tripSegments.orgId, orgId),
            ),
          )
          .returning(),
      );

      if (!updated) return reply.code(404).send({ error: "Segment not found" });
      return updated;
    },
  );
}
