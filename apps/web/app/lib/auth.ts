import { cookies } from "next/headers";

const BACKEND_URL = process.env.BACKEND_URL ?? "http://localhost:3001";
const COOKIE_NAME = "da_token";
const COOKIE_MAX_AGE = 60 * 60 * 24 * 7; // 7 days

export type TokenPayload = {
  sub: string;
  orgId: string;
  role: string;
  isGlobalAdmin: boolean;
};

export type Org = {
  orgId: string;
  orgName: string;
  orgSlug: string;
  role: string;
  displayName: string | null;
};

export type CurrentUser = {
  user: { id: string; username: string; email: string | null; totpEnabled: boolean; isGlobalAdmin: boolean };
  activeOrgId: string;
  activeRole: string;
  orgs: Org[];
};

/** Read the raw JWT from the httpOnly cookie (server-side only). */
export async function getToken(): Promise<string | undefined> {
  const store = await cookies();
  return store.get(COOKIE_NAME)?.value;
}

/** Set the auth cookie in a Server Action or Route Handler. */
export async function setToken(token: string) {
  const store = await cookies();
  store.set(COOKIE_NAME, token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: COOKIE_MAX_AGE,
  });
}

/** Delete the auth cookie. */
export async function clearToken() {
  const store = await cookies();
  store.delete(COOKIE_NAME);
}

/** Fetch the current user from the backend (throws if not authenticated). */
export async function getCurrentUser(): Promise<CurrentUser> {
  const token = await getToken();
  if (!token) throw new Error("Not authenticated");

  const res = await fetch(`${BACKEND_URL}/auth/me`, {
    headers: { Authorization: `Bearer ${token}` },
    cache: "no-store",
  });
  if (!res.ok) throw new Error("Not authenticated");
  return res.json() as Promise<CurrentUser>;
}

/** Authenticated fetch to the backend — uses the current token from the cookie. */
export async function backendFetch(path: string, init?: RequestInit): Promise<Response> {
  const token = await getToken();
  return fetch(`${BACKEND_URL}${path}`, {
    ...init,
    headers: {
      ...(init?.headers ?? {}),
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    cache: "no-store",
  });
}

/** Login against the backend, stores token, returns org list. */
export async function backendLogin(body: {
  username: string;
  password: string;
  totpToken?: string;
  orgId?: string;
}): Promise<{ token: string; orgId: string; role: string; orgs: { orgId: string; role: string }[] }> {
  const res = await fetch(`${BACKEND_URL}/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
    cache: "no-store",
  });
  if (!res.ok) {
    const err = (await res.json()) as { error: string };
    throw new Error(err.error ?? "Login failed");
  }
  return res.json();
}

/** Switch active org — backend issues a new JWT. */
export async function backendSwitchOrg(orgId: string) {
  const token = await getToken();
  const res = await fetch(`${BACKEND_URL}/auth/switch-org`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({ orgId }),
    cache: "no-store",
  });
  if (!res.ok) {
    const err = (await res.json()) as { error: string };
    throw new Error(err.error ?? "Switch failed");
  }
  return res.json() as Promise<{ token: string; orgId: string; role: string }>;
}
