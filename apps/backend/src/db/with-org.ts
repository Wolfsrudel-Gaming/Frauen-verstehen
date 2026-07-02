import { sql } from "drizzle-orm";
import { db } from "./client.js";

export type Tx = Parameters<Parameters<typeof db.transaction>[0]>[0];

// Runs fn inside a transaction with the org RLS context set.
//
// Uses set_config(..., is_local => true) — transaction-scoped like SET LOCAL,
// but parameterizable. A literal `SET LOCAL x = $1` is a Postgres syntax
// error: SET statements cannot take bind parameters.
export async function withOrg<T>(
  orgId: string,
  userId: string,
  fn: (tx: Tx) => Promise<T>,
): Promise<T> {
  return db.transaction(async (tx) => {
    await tx.execute(sql`
      SELECT set_config('app.current_org_id', ${orgId}, true),
             set_config('app.current_user_id', ${userId}, true),
             set_config('app.bypass_rls', 'off', true)
    `);
    return fn(tx);
  });
}
