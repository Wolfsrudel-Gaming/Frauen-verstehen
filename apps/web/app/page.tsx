async function getBackendHealth() {
  const url = process.env.BACKEND_URL ?? "http://localhost:3001";
  try {
    const res = await fetch(`${url}/health`, { cache: "no-store" });
    if (!res.ok) return { status: "error", db: "unknown" };
    return (await res.json()) as { status: string; db: string };
  } catch {
    return { status: "unreachable", db: "unreachable" };
  }
}

export default async function Home() {
  const health = await getBackendHealth();

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem" }}>
      <h1>Driver-Analytics Dashboard</h1>
      <p>Backend status: {health.status}</p>
      <p>Database: {health.db}</p>
    </main>
  );
}
