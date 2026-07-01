"use server";

import { revalidatePath } from "next/cache";
import { backendSwitchOrg, setToken } from "../lib/auth";

export async function switchOrgAction(formData: FormData) {
  const orgId = formData.get("orgId") as string;
  const result = await backendSwitchOrg(orgId);
  await setToken(result.token);
  revalidatePath("/");
}
