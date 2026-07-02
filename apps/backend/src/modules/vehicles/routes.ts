import type { FastifyInstance } from "fastify";
import { eq, and } from "drizzle-orm";
import { withOrg } from "../../db/with-org.js";
import { vehicles, vehicleAssignments } from "../../db/schema.js";

export default async function vehicleRoutes(app: FastifyInstance) {
  // -----------------------------------------------------------------------
  // GET /vehicles — list all active vehicles in current org
  // -----------------------------------------------------------------------
  app.get("/vehicles", { preHandler: [app.authenticate] }, async (req) => {
    const { orgId, sub } = req.user;
    return withOrg(orgId, sub, (tx) =>
      tx.select().from(vehicles).where(eq(vehicles.orgId, orgId)),
    );
  });

  // -----------------------------------------------------------------------
  // POST /vehicles — create a vehicle
  // -----------------------------------------------------------------------
  app.post<{
    Body: {
      make: string;
      model: string;
      year?: number;
      licensePlate?: string;
      vin?: string;
      category?: string;
      protocolSupport?: string;
      purchasePrice?: string;
      purchaseDate?: string;
      odometerAtPurchase?: number;
      notes?: string;
    };
  }>(
    "/vehicles",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          required: ["make", "model"],
          properties: {
            make: { type: "string" },
            model: { type: "string" },
            year: { type: "integer" },
            licensePlate: { type: "string" },
            vin: { type: "string" },
            category: { type: "string", enum: ["car", "motorcycle", "bicycle", "ebike", "oldtimer", "truck", "van", "other"] },
            protocolSupport: { type: "string", enum: ["obd2", "gps_only", "none"] },
            purchasePrice: { type: "string" },
            purchaseDate: { type: "string" },
            odometerAtPurchase: { type: "integer" },
            notes: { type: "string" },
          },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [vehicle] = await withOrg(orgId, sub, (tx) =>
        tx
          .insert(vehicles)
          .values({ orgId, ...req.body })
          .returning(),
      );
      return reply.code(201).send(vehicle);
    },
  );

  // -----------------------------------------------------------------------
  // GET /vehicles/:id — get a single vehicle
  // -----------------------------------------------------------------------
  app.get<{ Params: { id: string } }>(
    "/vehicles/:id",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [vehicle] = await withOrg(orgId, sub, (tx) =>
        tx
          .select()
          .from(vehicles)
          .where(and(eq(vehicles.id, req.params.id), eq(vehicles.orgId, orgId))),
      );
      if (!vehicle) return reply.code(404).send({ error: "Vehicle not found" });
      return vehicle;
    },
  );

  // -----------------------------------------------------------------------
  // PATCH /vehicles/:id — update a vehicle
  // -----------------------------------------------------------------------
  app.patch<{
    Params: { id: string };
    Body: Partial<{
      make: string;
      model: string;
      year: number;
      licensePlate: string;
      vin: string;
      category: string;
      protocolSupport: string;
      purchasePrice: string;
      purchaseDate: string;
      odometerAtPurchase: number;
      notes: string;
      isActive: boolean;
    }>;
  }>(
    "/vehicles/:id",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [updated] = await withOrg(orgId, sub, (tx) =>
        tx
          .update(vehicles)
          .set({ ...req.body, updatedAt: new Date() })
          .where(and(eq(vehicles.id, req.params.id), eq(vehicles.orgId, orgId)))
          .returning(),
      );
      if (!updated) return reply.code(404).send({ error: "Vehicle not found" });
      return updated;
    },
  );

  // -----------------------------------------------------------------------
  // DELETE /vehicles/:id — deactivate (soft delete) a vehicle
  // -----------------------------------------------------------------------
  app.delete<{ Params: { id: string } }>(
    "/vehicles/:id",
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const [updated] = await withOrg(orgId, sub, (tx) =>
        tx
          .update(vehicles)
          .set({ isActive: false, updatedAt: new Date() })
          .where(and(eq(vehicles.id, req.params.id), eq(vehicles.orgId, orgId)))
          .returning({ id: vehicles.id }),
      );
      if (!updated) return reply.code(404).send({ error: "Vehicle not found" });
      return { ok: true };
    },
  );

  // -----------------------------------------------------------------------
  // POST /vehicles/:id/assign — assign vehicle to a user in this org
  // -----------------------------------------------------------------------
  app.post<{ Params: { id: string }; Body: { userId: string } }>(
    "/vehicles/:id/assign",
    {
      preHandler: [app.authenticate],
      schema: {
        body: {
          type: "object",
          required: ["userId"],
          properties: { userId: { type: "string" } },
        },
      },
    },
    async (req, reply) => {
      const { orgId, sub } = req.user;
      const vehicleId = req.params.id;
      const { userId } = req.body;

      const [assignment] = await withOrg(orgId, sub, async (tx) => {
        // Close any existing open assignment for this vehicle
        await tx
          .update(vehicleAssignments)
          .set({ unassignedAt: new Date() })
          .where(
            and(
              eq(vehicleAssignments.vehicleId, vehicleId),
              eq(vehicleAssignments.orgId, orgId),
            ),
          );
        return tx
          .insert(vehicleAssignments)
          .values({ vehicleId, userId, orgId })
          .returning();
      });
      return reply.code(201).send(assignment);
    },
  );
}
