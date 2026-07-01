CREATE TABLE IF NOT EXISTS "trip_points" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"segment_id" uuid,
	"org_id" uuid NOT NULL,
	"lat" numeric(10, 7) NOT NULL,
	"lon" numeric(10, 7) NOT NULL,
	"altitude_m" numeric(7, 2),
	"accuracy_m" numeric(7, 2),
	"speed_kmh" numeric(6, 2),
	"heading_deg" numeric(5, 2),
	"is_estimated" boolean DEFAULT false NOT NULL,
	"recorded_at" timestamp with time zone NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "trip_segments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"org_id" uuid NOT NULL,
	"source_type" text DEFAULT 'smartphone_gps' NOT NULL,
	"is_estimated" boolean DEFAULT false NOT NULL,
	"started_at" timestamp with time zone NOT NULL,
	"ended_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trip_points" ADD CONSTRAINT "trip_points_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trip_points" ADD CONSTRAINT "trip_points_segment_id_trip_segments_id_fk" FOREIGN KEY ("segment_id") REFERENCES "public"."trip_segments"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trip_points" ADD CONSTRAINT "trip_points_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trip_segments" ADD CONSTRAINT "trip_segments_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trip_segments" ADD CONSTRAINT "trip_segments_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;

-- Index for fast per-trip point queries (ordered by time)
CREATE INDEX IF NOT EXISTS "trip_points_trip_id_recorded_at_idx"
  ON "trip_points" ("trip_id", "recorded_at");

-- RLS: trip_segments
ALTER TABLE "trip_segments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "trip_segments" FORCE ROW LEVEL SECURITY;
CREATE POLICY "trip_segments_org_isolation" ON "trip_segments"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );

-- RLS: trip_points
ALTER TABLE "trip_points" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "trip_points" FORCE ROW LEVEL SECURITY;
CREATE POLICY "trip_points_org_isolation" ON "trip_points"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );
