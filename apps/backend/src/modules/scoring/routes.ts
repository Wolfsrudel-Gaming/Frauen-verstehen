import type { FastifyInstance } from "fastify";
import { eq, and, gte, sql } from "drizzle-orm";
import { withOrg } from "../../db/with-org.js";
import { trips, tripScores, scoreDefinitions, vehicles, users } from "../../db/schema.js";
import { scoreAndStoreTrip } from "./service.js";
import { DEFAULT_WEIGHTS, DEFAULT_THRESHOLDS } from "./engine.js";

function rangeStart(range: string | undefined): Date | null {
  const now = Date.now();
  switch (range) {
    case "week":
      return new Date(now - 7 * 24 * 3600 * 1000);
    case "month":
      return new Date(now - 30 * 24 * 3600 * 1000);
    default:
      return null; // all time
  }
}

export default async function scoringRoutes(app: FastifyInstance) {
  // -----------------------------------------------------------------------
  // GET /trips/:id/score — stored score for a trip
  // -----------------------------------------------------------------------
  app.get<{ Params: { id: string } }>(
    "/trips/:id/score",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [score] = await withOrg(orgId, sub, (tx) =>
        tx
          .select()
          .from(tripScores)
          .where(and(eq(tripScores.tripId, req.params.id), eq(tripScores.orgId, orgId))),
      );
      if (!score) return reply.code(404).send({ error: "No score for this trip" });
      return score;
    },
  );

  // -----------------------------------------------------------------------
  // POST /trips/:id/score — (re)compute the score for a completed trip
  // -----------------------------------------------------------------------
  app.post<{ Params: { id: string } }>(
    "/trips/:id/score",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const result = await withOrg(orgId, sub, (tx) => scoreAndStoreTrip(tx, orgId, req.params.id));
      if (!result) {
        return reply
          .code(422)
          .send({ error: "Trip cannot be scored (not completed or too little data)" });
      }
      return result;
    },
  );

  // -----------------------------------------------------------------------
  // GET /leaderboard?range=week|month|all&source=combined|obd|gps&category=car
  // Confidence-weighted average score per driver.
  // -----------------------------------------------------------------------
  app.get<{ Querystring: { range?: string; source?: string; category?: string } }>(
    "/leaderboard",
    { preHandler: [app.authenticate] },
    async (req) => {
      const { orgId, sub } = req.user;
      const { range, source, category } = req.query;
      const start = rangeStart(range);

      return withOrg(orgId, sub, async (tx) => {
        const conditions = [eq(tripScores.orgId, orgId)];
        if (start) conditions.push(gte(tripScores.computedAt, start));
        if (source && source !== "all" && source !== "combined-all") {
          conditions.push(eq(tripScores.sourceType, source));
        }
        if (category) conditions.push(eq(vehicles.category, category));

        const rows = await tx
          .select({
            driverUserId: tripScores.driverUserId,
            username: users.username,
            weightedScore: sql<string>`
              sum(${tripScores.totalScore} * ${tripScores.confidenceWeight})
              / nullif(sum(${tripScores.confidenceWeight}), 0)
            `,
            tripCount: sql<string>`count(*)`,
            avgConfidence: sql<string>`avg(${tripScores.confidenceWeight})`,
          })
          .from(tripScores)
          .innerJoin(trips, eq(tripScores.tripId, trips.id))
          .leftJoin(vehicles, eq(trips.vehicleId, vehicles.id))
          .leftJoin(users, eq(tripScores.driverUserId, users.id))
          .where(and(...conditions))
          .groupBy(tripScores.driverUserId, users.username)
          .orderBy(
            sql`sum(${tripScores.totalScore} * ${tripScores.confidenceWeight})
                / nullif(sum(${tripScores.confidenceWeight}), 0) DESC NULLS LAST`,
          );

        return rows.map((r, i) => ({
          rank: i + 1,
          driverUserId: r.driverUserId,
          username: r.username ?? "(unbekannt)",
          score: r.weightedScore != null ? Math.round(Number(r.weightedScore) * 10) / 10 : null,
          tripCount: Number(r.tripCount),
          avgConfidence:
            r.avgConfidence != null ? Math.round(Number(r.avgConfidence) * 100) / 100 : null,
        }));
      });
    },
  );

  // -----------------------------------------------------------------------
  // GET /score-definition — active weights/thresholds (defaults if unset)
  // -----------------------------------------------------------------------
  app.get("/score-definition", { preHandler: [app.authenticate] }, async (req) => {
    const { orgId, sub } = req.user;
    const [def] = await withOrg(orgId, sub, (tx) =>
      tx
        .select()
        .from(scoreDefinitions)
        .where(and(eq(scoreDefinitions.orgId, orgId), eq(scoreDefinitions.isActive, true)))
        .limit(1),
    );
    return (
      def ?? {
        name: "default",
        weights: DEFAULT_WEIGHTS,
        thresholds: DEFAULT_THRESHOLDS,
        isActive: true,
        builtIn: true,
      }
    );
  });

  // -----------------------------------------------------------------------
  // PUT /score-definition — admin-only: set org weights/thresholds
  // -----------------------------------------------------------------------
  app.put<{ Body: { weights?: Record<string, number>; thresholds?: Record<string, number> } }>(
    "/score-definition",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          properties: {
            weights: { type: "object" },
            thresholds: { type: "object" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub, role } = req.user;
      if (role !== "admin") return reply.code(403).send({ error: "Admin only" });

      const weights = { ...DEFAULT_WEIGHTS, ...(req.body.weights ?? {}) };
      const thresholds = { ...DEFAULT_THRESHOLDS, ...(req.body.thresholds ?? {}) };

      return withOrg(orgId, sub, async (tx) => {
        const [existing] = await tx
          .select({ id: scoreDefinitions.id })
          .from(scoreDefinitions)
          .where(and(eq(scoreDefinitions.orgId, orgId), eq(scoreDefinitions.isActive, true)))
          .limit(1);

        if (existing) {
          const [updated] = await tx
            .update(scoreDefinitions)
            .set({ weights, thresholds, updatedAt: new Date() })
            .where(eq(scoreDefinitions.id, existing.id))
            .returning();
          return updated;
        }
        const [created] = await tx
          .insert(scoreDefinitions)
          .values({ orgId, weights, thresholds })
          .returning();
        return created;
      });
    },
  );
}
