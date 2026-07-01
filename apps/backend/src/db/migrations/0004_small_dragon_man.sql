CREATE TABLE IF NOT EXISTS "dtc_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"vehicle_id" uuid,
	"trip_id" uuid,
	"org_id" uuid NOT NULL,
	"code" text NOT NULL,
	"description" text,
	"severity" text DEFAULT 'warning' NOT NULL,
	"detected_at" timestamp with time zone DEFAULT now() NOT NULL,
	"cleared_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "obd_readings" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"session_id" uuid,
	"org_id" uuid NOT NULL,
	"recorded_at" timestamp with time zone NOT NULL,
	"rpm_x4" integer,
	"speed_kmh" integer,
	"coolant_temp_c" integer,
	"throttle_pos" numeric(5, 2),
	"fuel_level_pct" numeric(5, 2),
	"intake_air_temp_c" integer,
	"maf_gps" numeric(7, 2),
	"raw_pids" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "obd_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"org_id" uuid NOT NULL,
	"adapter_name" text,
	"adapter_mac" text,
	"elm_protocol" text,
	"connected_at" timestamp with time zone DEFAULT now() NOT NULL,
	"disconnected_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "dtc_events" ADD CONSTRAINT "dtc_events_vehicle_id_vehicles_id_fk" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "dtc_events" ADD CONSTRAINT "dtc_events_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "dtc_events" ADD CONSTRAINT "dtc_events_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "obd_readings" ADD CONSTRAINT "obd_readings_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "obd_readings" ADD CONSTRAINT "obd_readings_session_id_obd_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."obd_sessions"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "obd_readings" ADD CONSTRAINT "obd_readings_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "obd_sessions" ADD CONSTRAINT "obd_sessions_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "obd_sessions" ADD CONSTRAINT "obd_sessions_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;

-- Index for fast per-trip OBD reading queries
CREATE INDEX IF NOT EXISTS "obd_readings_trip_id_recorded_at_idx"
  ON "obd_readings" ("trip_id", "recorded_at");

-- RLS: obd_sessions
ALTER TABLE "obd_sessions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "obd_sessions" FORCE ROW LEVEL SECURITY;
CREATE POLICY "obd_sessions_org_isolation" ON "obd_sessions"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );

-- RLS: obd_readings
ALTER TABLE "obd_readings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "obd_readings" FORCE ROW LEVEL SECURITY;
CREATE POLICY "obd_readings_org_isolation" ON "obd_readings"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );

-- RLS: dtc_events
ALTER TABLE "dtc_events" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "dtc_events" FORCE ROW LEVEL SECURITY;
CREATE POLICY "dtc_events_org_isolation" ON "dtc_events"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );
