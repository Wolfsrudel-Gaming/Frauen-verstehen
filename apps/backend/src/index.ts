import Fastify from "fastify";
import { env } from "./env.js";
import { pool } from "./db/client.js";
import jwtPlugin from "./plugins/jwt.js";
import authRoutes from "./modules/auth/routes.js";
import orgRoutes from "./modules/orgs/routes.js";
import vehicleRoutes from "./modules/vehicles/routes.js";
import tripRoutes from "./modules/trips/routes.js";
import trackingRoutes from "./modules/tracking/routes.js";
import obdRoutes from "./modules/obd/routes.js";
import scoringRoutes from "./modules/scoring/routes.js";
import statsRoutes from "./modules/stats/routes.js";

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
await app.register(vehicleRoutes);
await app.register(tripRoutes);
await app.register(trackingRoutes);
await app.register(obdRoutes);
await app.register(scoringRoutes);
await app.register(statsRoutes);

app.listen({ port: env.port, host: "0.0.0.0" }).catch((err) => {
  app.log.error(err);
  process.exit(1);
});
