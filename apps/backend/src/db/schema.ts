import {
  pgTable,
  uuid,
  text,
  timestamp,
  boolean,
  jsonb,
  unique,
  integer,
  numeric,
  date,
} from "drizzle-orm/pg-core";

// ---------------------------------------------------------------------------
// Organizations
// ---------------------------------------------------------------------------

export const organizations = pgTable("organizations", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: text("name").notNull(),
  slug: text("slug").notNull().unique(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

// ---------------------------------------------------------------------------
// Users (global — not org-scoped; membership is in org_memberships)
// ---------------------------------------------------------------------------

export const users = pgTable("users", {
  id: uuid("id").primaryKey().defaultRandom(),
  username: text("username").notNull().unique(),
  email: text("email").unique(),
  passwordHash: text("password_hash").notNull(),
  isGlobalAdmin: boolean("is_global_admin").notNull().default(false),
  totpSecret: text("totp_secret"),
  totpEnabled: boolean("totp_enabled").notNull().default(false),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

// ---------------------------------------------------------------------------
// Org memberships — links a user to an organization with a role
// ---------------------------------------------------------------------------

export const orgMemberships = pgTable(
  "org_memberships",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    orgId: uuid("org_id")
      .notNull()
      .references(() => organizations.id, { onDelete: "cascade" }),
    userId: uuid("user_id")
      .notNull()
      .references(() => users.id, { onDelete: "cascade" }),
    // 'admin' can manage org settings and members
    // 'driver' can record trips and view own stats
    // 'viewer' read-only access
    role: text("role").notNull().default("driver"),
    // Optional org-specific display name that overrides username within the org
    displayName: text("display_name"),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
    updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (t) => ({
    uniqueOrgUser: unique("org_memberships_org_user_unique").on(t.orgId, t.userId),
  }),
);

// ---------------------------------------------------------------------------
// Vehicles
// category: 'car' | 'motorcycle' | 'bicycle' | 'ebike' | 'oldtimer' | 'truck' | 'van' | 'other'
// protocol_support: 'obd2' | 'gps_only' | 'none'
// ---------------------------------------------------------------------------

export const vehicles = pgTable("vehicles", {
  id: uuid("id").primaryKey().defaultRandom(),
  orgId: uuid("org_id")
    .notNull()
    .references(() => organizations.id, { onDelete: "cascade" }),
  make: text("make").notNull(),
  model: text("model").notNull(),
  year: integer("year"),
  licensePlate: text("license_plate"),
  vin: text("vin"),
  category: text("category").notNull().default("car"),
  protocolSupport: text("protocol_support").notNull().default("obd2"),
  purchasePrice: numeric("purchase_price", { precision: 10, scale: 2 }),
  purchaseDate: date("purchase_date"),
  odometerAtPurchase: integer("odometer_at_purchase"),
  notes: text("notes"),
  isActive: boolean("is_active").notNull().default(true),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

// ---------------------------------------------------------------------------
// Vehicle assignments — who is currently assigned to which vehicle
// ---------------------------------------------------------------------------

export const vehicleAssignments = pgTable("vehicle_assignments", {
  id: uuid("id").primaryKey().defaultRandom(),
  vehicleId: uuid("vehicle_id")
    .notNull()
    .references(() => vehicles.id, { onDelete: "cascade" }),
  userId: uuid("user_id")
    .notNull()
    .references(() => users.id, { onDelete: "cascade" }),
  orgId: uuid("org_id")
    .notNull()
    .references(() => organizations.id, { onDelete: "cascade" }),
  assignedAt: timestamp("assigned_at", { withTimezone: true }).defaultNow().notNull(),
  unassignedAt: timestamp("unassigned_at", { withTimezone: true }),
});

// ---------------------------------------------------------------------------
// Trips
// status: 'in_progress' | 'completed' | 'discarded'
// start/end_trigger: 'manual' | 'auto_obd' | 'auto_gps' | 'auto_bt'
// ---------------------------------------------------------------------------

export const trips = pgTable("trips", {
  id: uuid("id").primaryKey().defaultRandom(),
  orgId: uuid("org_id")
    .notNull()
    .references(() => organizations.id, { onDelete: "cascade" }),
  vehicleId: uuid("vehicle_id").references(() => vehicles.id, { onDelete: "set null" }),
  driverUserId: uuid("driver_user_id").references(() => users.id, { onDelete: "set null" }),
  status: text("status").notNull().default("in_progress"),
  startTrigger: text("start_trigger").notNull().default("manual"),
  endTrigger: text("end_trigger"),
  startedAt: timestamp("started_at", { withTimezone: true }).defaultNow().notNull(),
  endedAt: timestamp("ended_at", { withTimezone: true }),
  startOdometer: integer("start_odometer"),
  endOdometer: integer("end_odometer"),
  distanceKm: numeric("distance_km", { precision: 8, scale: 3 }),
  notes: text("notes"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

// ---------------------------------------------------------------------------
// Audit log — append-only, org_id nullable for global/system events
// ---------------------------------------------------------------------------

export const auditLog = pgTable("audit_log", {
  id: uuid("id").primaryKey().defaultRandom(),
  orgId: uuid("org_id").references(() => organizations.id, { onDelete: "set null" }),
  actorUserId: uuid("actor_user_id").references(() => users.id, { onDelete: "set null" }),
  action: text("action").notNull(),
  targetType: text("target_type"),
  targetId: uuid("target_id"),
  metadata: jsonb("metadata"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});
