import type { FastifyInstance } from "fastify";
import { eq } from "drizzle-orm";
import { db } from "../../db/client.js";
import { organizations, orgMemberships, users } from "../../db/schema.js";

export default async function orgRoutes(app: FastifyInstance) {
  // GET /orgs — list all orgs the current user is a member of
  app.get("/orgs", { preHandler: [app.authenticate] }, async (req) => {
    const memberships = await db
      .select({
        id: organizations.id,
        name: organizations.name,
        slug: organizations.slug,
        role: orgMemberships.role,
        displayName: orgMemberships.displayName,
      })
      .from(orgMemberships)
      .innerJoin(organizations, eq(organizations.id, orgMemberships.orgId))
      .where(eq(orgMemberships.userId, req.user.sub));
    return { orgs: memberships };
  });

  // POST /orgs — create a new org (authenticated user becomes admin)
  app.post<{ Body: { name: string; slug: string } }>(
    "/orgs",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          required: ["name", "slug"],
          properties: {
            name: { type: "string" },
            slug: { type: "string", pattern: "^[a-z0-9-]+$" },
          },
        },
      },
    },
    async (req, reply) => {
      const { name, slug } = req.body;
      const [org] = await db.insert(organizations).values({ name, slug }).returning();
      await db.insert(orgMemberships).values({
        orgId: org.id,
        userId: req.user.sub,
        role: "admin",
      });
      return reply.code(201).send(org);
    },
  );

  // GET /orgs/:orgId/members — list members (admin only)
  app.get<{ Params: { orgId: string } }>(
    "/orgs/:orgId/members",
    { preHandler: [app.authenticate, app.requireAdmin] },
    async (req) => {
      const members = await db
        .select({
          userId: users.id,
          username: users.username,
          email: users.email,
          role: orgMemberships.role,
          displayName: orgMemberships.displayName,
        })
        .from(orgMemberships)
        .innerJoin(users, eq(users.id, orgMemberships.userId))
        .where(eq(orgMemberships.orgId, req.params.orgId));
      return { members };
    },
  );

  // POST /orgs/:orgId/members — invite a user to an org (admin only)
  app.post<{
    Params: { orgId: string };
    Body: { username: string; role: string; displayName?: string };
  }>(
    "/orgs/:orgId/members",
    {
      preHandler: [app.authenticate, app.requireAdmin],
      schema: {
        body: {
          type: "object",
          required: ["username", "role"],
          properties: {
            username: { type: "string" },
            role: { type: "string", enum: ["admin", "driver", "viewer"] },
            displayName: { type: "string" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId } = req.params;
      const { username, role, displayName } = req.body;

      const [user] = await db.select().from(users).where(eq(users.username, username));
      if (!user) return reply.code(404).send({ error: "User not found" });

      const [membership] = await db
        .insert(orgMemberships)
        .values({ orgId, userId: user.id, role, displayName: displayName ?? null })
        .returning();

      return reply.code(201).send(membership);
    },
  );
}
