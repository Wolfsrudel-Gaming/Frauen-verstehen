import { getCurrentUser } from "./lib/auth";

const BACKEND_URL = process.env.BACKEND_URL ?? "http://localhost:3001";

async function getBackendHealth() {
  try {
    const res = await fetch(`${BACKEND_URL}/health`, { cache: "no-store" });
    if (!res.ok) return { status: "error", db: "unknown" };
    return (await res.json()) as { status: string; db: string };
  } catch {
    return { status: "unreachable", db: "unreachable" };
  }
}

export default async function Home() {
  const [health, currentUser] = await Promise.all([
    getBackendHealth(),
    getCurrentUser(),
  ]);

  const activeOrg = currentUser.orgs.find((o) => o.orgId === currentUser.activeOrgId);

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem" }}>
      <h1>Driver Analytics Dashboard</h1>

      <section style={{ marginBottom: "2rem" }}>
        <h2 style={{ fontSize: 16, color: "#555", marginBottom: "0.5rem" }}>Active Organization</h2>
        <p style={{ fontSize: 24, fontWeight: 700, margin: 0 }}>{activeOrg?.orgName ?? "—"}</p>
        <p style={{ color: "#888", margin: "0.25rem 0 0" }}>
          Role: <strong>{currentUser.activeRole}</strong>
          {currentUser.user.isGlobalAdmin && " · Global Admin"}
        </p>
      </section>

      <section style={{ marginBottom: "2rem" }}>
        <h2 style={{ fontSize: 16, color: "#555", marginBottom: "0.5rem" }}>System Status</h2>
        <p>Backend: <strong>{health.status}</strong></p>
        <p>Database: <strong>{health.db}</strong></p>
      </section>

      <section style={{ marginBottom: "2rem" }}>
        <h2 style={{ fontSize: 16, color: "#555", marginBottom: "0.75rem" }}>Navigation</h2>
        <div style={{ display: "flex", gap: "0.75rem" }}>
          {(
            [
              { href: "/vehicles", label: "Vehicles" },
              { href: "/trips", label: "Trips" },
            ] as const
          ).map(({ href, label }) => (
            <a
              key={href}
              href={href}
              style={{
                padding: "0.5rem 1.1rem",
                background: "#0070f3",
                color: "#fff",
                borderRadius: 6,
                textDecoration: "none",
                fontWeight: 600,
                fontSize: 15,
              }}
            >
              {label}
            </a>
          ))}
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 16, color: "#555", marginBottom: "0.5rem" }}>Your Organizations</h2>
        <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
          {currentUser.orgs.map((org) => (
            <li
              key={org.orgId}
              style={{
                padding: "0.5rem 0.75rem",
                marginBottom: "0.4rem",
                border: `1px solid ${org.orgId === currentUser.activeOrgId ? "#0070f3" : "#e5e7eb"}`,
                borderRadius: 6,
                color: org.orgId === currentUser.activeOrgId ? "#0070f3" : "inherit",
              }}
            >
              {org.orgName} — {org.role}
              {org.orgId === currentUser.activeOrgId && " ✓"}
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
