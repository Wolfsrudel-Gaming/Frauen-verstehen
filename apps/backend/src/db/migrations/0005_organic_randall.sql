CREATE TABLE IF NOT EXISTS "score_definitions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"org_id" uuid NOT NULL,
	"name" text DEFAULT 'default' NOT NULL,
	"weights" jsonb NOT NULL,
	"thresholds" jsonb NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE IF NOT EXISTS "trip_scores" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trip_id" uuid NOT NULL,
	"org_id" uuid NOT NULL,
	"driver_user_id" uuid,
	"total_score" numeric NOT NULL,
	"breakdown" jsonb NOT NULL,
	"confidence_weight" numeric NOT NULL,
	"source_type" text DEFAULT 'gps' NOT NULL,
	"computed_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "trip_scores_trip_id_unique" UNIQUE("trip_id")
);
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "score_definitions" ADD CONSTRAINT "score_definitions_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trip_scores" ADD CONSTRAINT "trip_scores_trip_id_trips_id_fk" FOREIGN KEY ("trip_id") REFERENCES "public"."trips"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trip_scores" ADD CONSTRAINT "trip_scores_org_id_organizations_id_fk" FOREIGN KEY ("org_id") REFERENCES "public"."organizations"("id") ON DELETE cascade ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;
--> statement-breakpoint
DO $$ BEGIN
 ALTER TABLE "trip_scores" ADD CONSTRAINT "trip_scores_driver_user_id_users_id_fk" FOREIGN KEY ("driver_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;
EXCEPTION
 WHEN duplicate_object THEN null;
END $$;

-- RLS: score_definitions
ALTER TABLE "score_definitions" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "score_definitions" FORCE ROW LEVEL SECURITY;
CREATE POLICY "score_definitions_org_isolation" ON "score_definitions"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );

-- RLS: trip_scores
ALTER TABLE "trip_scores" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "trip_scores" FORCE ROW LEVEL SECURITY;
CREATE POLICY "trip_scores_org_isolation" ON "trip_scores"
  USING (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  )
  WITH CHECK (
    current_setting('app.bypass_rls', TRUE) = 'on'
    OR org_id = current_setting('app.current_org_id', TRUE)::uuid
  );

-- Leaderboard queries filter by org + time range
CREATE INDEX "trip_scores_org_computed_idx" ON "trip_scores" ("org_id", "computed_at");
