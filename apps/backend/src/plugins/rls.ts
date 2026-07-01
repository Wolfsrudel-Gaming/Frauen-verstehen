import fp from "fastify-plugin";
import type { FastifyInstance } from "fastify";
import { pool } from "../db/client.js";

// Wraps every authenticated request in a transaction that sets app.*
// session vars so Postgres RLS policies can enforce org isolation.
// Usage: add this as a preHandler on routes that need RLS.
export default fp(async function rlsPlugin(app: FastifyInstance) {
  app.decorate(
    "withRlsContext",
    async <T>(orgId: string, userId: string, fn: (client: typeof pool) => Promise<T>): Promise<T> => {
      const client = await pool.connect();
      try {
        await client.query("BEGIN");
        await client.query("SET LOCAL app.current_org_id = $1", [orgId]);
        await client.query("SET LOCAL app.current_user_id = $1", [userId]);
        // Clear bypass so RLS policies are enforced
        await client.query("SET LOCAL app.bypass_rls = 'off'");
        const result = await fn(pool);
        await client.query("COMMIT");
        return result;
      } catch (err) {
        await client.query("ROLLBACK");
        throw err;
      } finally {
        client.release();
      }
    },
  );
});
