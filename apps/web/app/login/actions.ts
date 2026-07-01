"use server";

import { redirect } from "next/navigation";
import { backendLogin, setToken } from "../lib/auth";

export async function loginAction(formData: FormData) {
  const username = formData.get("username") as string;
  const password = formData.get("password") as string;
  const totpToken = (formData.get("totpToken") as string) || undefined;

  let errorMessage: string | null = null;
  try {
    const result = await backendLogin({ username, password, totpToken });
    await setToken(result.token);
  } catch (err) {
    errorMessage = err instanceof Error ? err.message : "Login failed";
  }

  // redirect() must be called outside try/catch — it throws internally.
  if (errorMessage) {
    redirect(`/login?error=${encodeURIComponent(errorMessage)}`);
  }
  redirect("/");
}
