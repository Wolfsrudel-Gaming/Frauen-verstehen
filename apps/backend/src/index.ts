import Fastify from "fastify";
import { env } from "./env.js";
import { pool } from "./db/client.js";

const app = Fastify({ logger: true });

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

app.listen({ port: env.port, host: "0.0.0.0" }).catch((err) => {
  app.log.error(err);
  process.exit(1);
});
