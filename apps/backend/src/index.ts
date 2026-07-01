import Fastify from "fastify";
import { env } from "./env.js";
import { pool } from "./db/client.js";
import jwtPlugin from "./plugins/jwt.js";
import authRoutes from "./modules/auth/routes.js";
import orgRoutes from "./modules/orgs/routes.js";

const app = Fastify({ logger: true });

await app.register(jwtPlugin);

app.get("/health", async () => {
  let dbOk = false;
  try {
    await pool.query("SELECT 1");
    dbOk = true;
  } catch {
    dbOk = false;
  }
  return { status: "ok", db: dbOk ? "connected" : "unreachable" };
});

await app.register(authRoutes);
await app.register(orgRoutes);

app.listen({ port: env.port, host: "0.0.0.0" }).catch((err) => {
  app.log.error(err);
  process.exit(1);
});
