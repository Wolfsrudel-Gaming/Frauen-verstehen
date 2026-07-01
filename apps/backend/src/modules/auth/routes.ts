import type { FastifyInstance } from "fastify";
import { hash, compare } from "bcryptjs";
import { TOTP, Secret } from "otpauth";
import { eq, and } from "drizzle-orm";
import { db } from "../../db/client.js";
import { users, organizations, orgMemberships, auditLog } from "../../db/schema.js";

const BCRYPT_ROUNDS = 12;

function makeTotpUri(username: string, secret: Secret): string {
  const totp = new TOTP({ issuer: "DriverAnalytics", label: username, secret });
  return totp.toString();
}

function verifyTotp(secret: string, token: string): boolean {
  const totp = new TOTP({ secret: Secret.fromBase32(secret) });
  return totp.validate({ token, window: 1 }) !== null;
}

async function writeAudit(
  actorUserId: string | null,
  action: string,
  orgId?: string,
  meta?: Record<string, unknown>,
) {
  await db.insert(auditLog).values({
    actorUserId,
    action,
    orgId: orgId ?? null,
    metadata: meta ?? null,
  });
}

export default async function authRoutes(app: FastifyInstance) {
  // -----------------------------------------------------------------------
  // POST /auth/register
  // Creates a user + (optionally) an org and grants admin membership.
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      username: string;
      password: string;
      email?: string;
      orgName?: string;
      orgSlug?: string;
    };
  }>("/auth/register", {
    schema: {
      body: {
        type: "object",
        required: ["username", "password"],
        properties: {
          username: { type: "string", minLength: 3 },
          password: { type: "string", minLength: 8 },
          email: { type: "string", format: "email" },
          orgName: { type: "string" },
          orgSlug: { type: "string" },
        },
      },
    },
  }, async (req, reply) => {
    const { username, password, email, orgName, orgSlug } = req.body;
    const passwordHash = await hash(password, BCRYPT_ROUNDS);

    const [user] = await db
      .insert(users)
      .values({ username, email: email ?? null, passwordHash })
      .returning();

    let orgId: string | undefined;

    if (orgName && orgSlug) {
      const [org] = await db
        .insert(organizations)
        .values({ name: orgName, slug: orgSlug })
        .returning();
      orgId = org.id;
      await db.insert(orgMemberships).values({ orgId: org.id, userId: user.id, role: "admin" });
      await writeAudit(user.id, "org.created", org.id, { orgName });
    }

    await writeAudit(user.id, "user.registered");

    return reply.code(201).send({ id: user.id, username: user.username, orgId });
  });

  // -----------------------------------------------------------------------
  // POST /auth/login
  // -----------------------------------------------------------------------
  app.post<{
    Body: { username: string; password: string; totpToken?: string; orgId?: string };
  }>("/auth/login", {
    schema: {
      body: {
        type: "object",
        required: ["username", "password"],
        properties: {
          username: { type: "string" },
          password: { type: "string" },
          totpToken: { type: "string" },
          orgId: { type: "string" },
        },
      },
    },
  }, async (req, reply) => {
    const { username, password, totpToken, orgId: requestedOrgId } = req.body;

    const [user] = await db.select().from(users).where(eq(users.username, username));
    if (!user) return reply.code(401).send({ error: "Invalid credentials" });

    const valid = await compare(password, user.passwordHash);
    if (!valid) return reply.code(401).send({ error: "Invalid credentials" });

    // TOTP required for admin accounts that have it enabled
    if (user.totpEnabled) {
      if (!totpToken) return reply.code(401).send({ error: "TOTP token required" });
      if (!verifyTotp(user.totpSecret!, totpToken)) {
        return reply.code(401).send({ error: "Invalid TOTP token" });
      }
    }

    // Find which orgs the user belongs to
    const memberships = await db
      .select({ orgId: orgMemberships.orgId, role: orgMemberships.role })
      .from(orgMemberships)
      .where(eq(orgMemberships.userId, user.id));

    const targetMembership = requestedOrgId
      ? memberships.find((m) => m.orgId === requestedOrgId)
      : memberships[0];

    if (!targetMembership && !user.isGlobalAdmin) {
      return reply.code(403).send({ error: "No organization membership" });
    }

    const orgId = targetMembership?.orgId ?? "";
    const role = targetMembership?.role ?? "viewer";

    const token = app.jwt.sign({
      sub: user.id,
      orgId,
      role,
      isGlobalAdmin: user.isGlobalAdmin,
    });

    await writeAudit(user.id, "user.login", orgId);

    return { token, orgId, role, orgs: memberships };
  });

  // -----------------------------------------------------------------------
  // GET /auth/me — returns current user + org info
  // -----------------------------------------------------------------------
  app.get("/auth/me", { preHandler: [app.authenticate] }, async (req) => {
    const { sub, orgId, role, isGlobalAdmin } = req.user;

    const [user] = await db
      .select({ id: users.id, username: users.username, email: users.email, totpEnabled: users.totpEnabled })
      .from(users)
      .where(eq(users.id, sub));

    const memberships = await db
      .select({ orgId: orgMemberships.orgId, role: orgMemberships.role, displayName: orgMemberships.displayName, orgName: organizations.name, orgSlug: organizations.slug })
      .from(orgMemberships)
      .innerJoin(organizations, eq(organizations.id, orgMemberships.orgId))
      .where(eq(orgMemberships.userId, sub));

    return { user: { ...user, isGlobalAdmin }, activeOrgId: orgId, activeRole: role, orgs: memberships };
  });

  // -----------------------------------------------------------------------
  // POST /auth/switch-org — swap the active org in the JWT
  // -----------------------------------------------------------------------
  app.post<{ Body: { orgId: string } }>(
    "/auth/switch-org",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          required: ["orgId"],
          properties: { orgId: { type: "string" } },
        },
      },
    },
    async (req, reply) => {
      const { sub, isGlobalAdmin } = req.user;
      const { orgId } = req.body;

      const [membership] = await db
        .select()
        .from(orgMemberships)
        .where(and(eq(orgMemberships.userId, sub), eq(orgMemberships.orgId, orgId)));

      if (!membership && !isGlobalAdmin) {
        return reply.code(403).send({ error: "Not a member of that organization" });
      }

      const role = membership?.role ?? "viewer";
      const token = app.jwt.sign({ sub, orgId, role, isGlobalAdmin });
      return { token, orgId, role };
    },
  );

  // -----------------------------------------------------------------------
  // POST /auth/totp/setup — generate TOTP secret for admin (returns QR URI)
  // -----------------------------------------------------------------------
  app.post("/auth/totp/setup", { preHandler: [app.authenticate] }, async (req, reply) => {
    const { sub, role, isGlobalAdmin } = req.user;
    if (role !== "admin" && !isGlobalAdmin) {
      return reply.code(403).send({ error: "Only admins can set up TOTP" });
    }

    const [user] = await db.select().from(users).where(eq(users.id, sub));
    if (user.totpEnabled) return reply.code(409).send({ error: "TOTP already enabled" });

    const secret = new Secret();
    await db.update(users).set({ totpSecret: secret.base32 }).where(eq(users.id, sub));

    return { uri: makeTotpUri(user.username, secret) };
  });

  // -----------------------------------------------------------------------
  // POST /auth/totp/verify — confirm the TOTP code and activate 2FA
  // -----------------------------------------------------------------------
  app.post<{ Body: { token: string } }>(
    "/auth/totp/verify",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          required: ["token"],
          properties: { token: { type: "string" } },
        },
      },
    },
    async (req, reply) => {
      const { sub } = req.user;
      const [user] = await db.select().from(users).where(eq(users.id, sub));

      if (!user.totpSecret) return reply.code(400).send({ error: "Run /auth/totp/setup first" });
      if (!verifyTotp(user.totpSecret, req.body.token)) {
        return reply.code(400).send({ error: "Invalid TOTP token" });
      }

      await db.update(users).set({ totpEnabled: true }).where(eq(users.id, sub));
      await writeAudit(sub, "user.totp_enabled");

      return { ok: true };
    },
  );

  // -----------------------------------------------------------------------
  // POST /admin/users/:userId/reset-password  (admin-only)
  // -----------------------------------------------------------------------
  app.post<{ Params: { userId: string }; Body: { newPassword: string } }>(
    "/admin/users/:userId/reset-password",
    {
      preHandler: [app.authenticate, app.requireAdmin],
      schema: {
        params: { type: "object", required: ["userId"], properties: { userId: { type: "string" } } },
        body: {
          type: "object",
          required: ["newPassword"],
          properties: { newPassword: { type: "string", minLength: 8 } },
        },
      },
    },
    async (req, reply) => {
      const { userId } = req.params;
      const passwordHash = await hash(req.body.newPassword, BCRYPT_ROUNDS);
      const updated = await db
        .update(users)
        .set({ passwordHash })
        .where(eq(users.id, userId))
        .returning({ id: users.id });
      if (!updated.length) return reply.code(404).send({ error: "User not found" });
      await writeAudit(req.user.sub, "user.password_reset", req.user.orgId, { targetUserId: userId });
      return { ok: true };
    },
  );
}
