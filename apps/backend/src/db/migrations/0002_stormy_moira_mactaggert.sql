CREATE TABLE IF NOT EXISTS "trips" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"org_id" uuid NOT NULL,
	"vehicle_id" uuid,
	"driver_user_id" uuid,
	"status" text DEFAULT 'in_progress' NOT NULL,
	"start_trigger" text DEFAULT 'manual' NOT NULL,
	"end_trigger" text,
	"started_at" timestamp with time zone DEFAULT now() NOT NULL,
	"ended_at" timestamp with time zone,
	"start_odometer" integer,
	"end_odometer" integer,
	"distance_km" numeric(8, 3),
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "vehicle_assignments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"vehicle_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"org_id" uuid NOT NULL,
	"assigned_at" timestamp with time zone DEFAULT now() NOT NULL,
	"unassigned_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "vehicles" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"org_id" uuid NOT NULL,
	"make" text NOT NULL,
	"model" text NOT NULL,
	"year" integer,
	"license_plate" text,
	"vin" text,
	"category" text DEFAULT 'car' NOT NULL,
	"protocol_support" text DEFAULT 'obd2' NOT NULL,
	"purchase_price" numeric(10, 2),
	"purchase_date" date,
	"odometer_at_purchase" integer,
	"notes" text,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trips" ADD CONSTRAINT "trips_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trips" ADD CONSTRAINT "trips_vehicle_id_vehicles_id_fk" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trips" ADD CONSTRAINT "trips_driver_user_id_users_id_fk" FOREIGN KEY ("driver_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "vehicle_assignments" ADD CONSTRAINT "vehicle_assignments_vehicle_id_vehicles_id_fk" FOREIGN KEY ("vehicle_id") REFERENCES "public"."vehicles"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "vehicle_assignments" ADD CONSTRAINT "vehicle_assignments_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "vehicle_assignments" ADD CONSTRAINT "vehicle_assignments_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "vehicles" ADD CONSTRAINT "vehicles_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;

-- RLS: vehicles
ALTER TABLE "vehicles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "vehicles" FORCE ROW LEVEL SECURITY;
CREATE POLICY "vehicles_org_isolation" ON "vehicles"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );

-- RLS: vehicle_assignments
ALTER TABLE "vehicle_assignments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "vehicle_assignments" FORCE ROW LEVEL SECURITY;
CREATE POLICY "vehicle_assignments_org_isolation" ON "vehicle_assignments"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );

-- RLS: trips
ALTER TABLE "trips" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "trips" FORCE ROW LEVEL SECURITY;
CREATE POLICY "trips_org_isolation" ON "trips"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );
