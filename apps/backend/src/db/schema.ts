import { pgTable, uuid, text, timestamp } from "drizzle-orm/pg-core";

/**
 * M0 placeholder schema — proves the migration pipeline works end-to-end.
 * Real tenancy/trip/vehicle tables (per the plan's data model) land in M1+.
 */
export const organizations = pgTable("organizations", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: text("name").notNull(),
  slug: text("slug").notNull().unique(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});
