import Link from "next/link";
import { backendFetch } from "../lib/auth";

type Entry = {
  rank: number;
  driverUserId: string | null;
  username: string;
  score: number | null;
  tripCount: number;
  avgConfidence: number | null;
};

type Props = {
  searchParams: Promise<{ range?: string; source?: string; category?: string }>;
};

const ranges = [
  { value: "week", label: "7 Tage" },
  { value: "month", label: "30 Tage" },
  { value: "all", label: "Gesamt" },
];

const sources = [
  { value: "all", label: "Alle Quellen" },
  { value: "combined", label: "OBD + GPS" },
  { value: "gps", label: "Nur GPS" },
  { value: "obd", label: "Nur OBD" },
];

function scoreColor(score: number | null): string {
  if (score == null) return "#9ca3af";
  if (score >= 80) return "#16a34a";
  if (score >= 60) return "#d97706";
  return "#dc2626";
}

export default async function LeaderboardPage({ searchParams }: Props) {
  const { range = "month", source = "all", category } = await searchParams;

  const params = new URLSearchParams({ range, source });
  if (category) params.set("category", category);

  const res = await backendFetch(`/leaderboard?${params.toString()}`);
  const entries: Entry[] = res.ok ? await res.json() : [];

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem", maxWidth: 800, margin: "0 auto" }}>
      <Link href="/" style={{ color: "#0070f3" }}>← Home</Link>
      <h1 style={{ fontSize: 24, margin: "1rem 0" }}>Fahrer-Leaderboard</h1>

      {/* Filters */}
      <div style={{ display: "flex", gap: "0.5rem", flexWrap: "wrap", marginBottom: "1.5rem" }}>
        {ranges.map((r) => (
          <Link
            key={r.value}
            href={`/leaderboard?range=${r.value}&source=${source}`}
            style={{
              padding: "0.35rem 0.9rem",
              borderRadius: 999,
              fontSize: 13,
              textDecoration: "none",
              border: "1px solid #e5e7eb",
              background: range === r.value ? "#0070f3" : "#fff",
              color: range === r.value ? "#fff" : "#374151",
            }}
          >
            {r.label}
          </Link>
        ))}
        <span style={{ width: 12 }} />
        {sources.map((s) => (
          <Link
            key={s.value}
            href={`/leaderboard?range=${range}&source=${s.value}`}
            style={{
              padding: "0.35rem 0.9rem",
              borderRadius: 999,
              fontSize: 13,
              textDecoration: "none",
              border: "1px solid #e5e7eb",
              background: source === s.value ? "#111827" : "#fff",
              color: source === s.value ? "#fff" : "#374151",
            }}
          >
            {s.label}
          </Link>
        ))}
      </div>

      {entries.length === 0 ? (
        <p style={{ color: "#6b7280" }}>
          Noch keine bewerteten Fahrten in diesem Zeitraum. Scores entstehen automatisch beim
          Beenden einer Fahrt mit ausreichend GPS-Daten.
        </p>
      ) : (
        <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 14 }}>
          <thead>
            <tr style={{ background: "#f9fafb", textAlign: "left" }}>
              {["#", "Fahrer", "Score", "Fahrten", "Konfidenz"].map((h) => (
                <th key={h} style={{ padding: "8px 12px", borderBottom: "2px solid #e5e7eb" }}>
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {entries.map((e) => (
              <tr key={e.driverUserId ?? e.rank} style={{ borderBottom: "1px solid #f3f4f6" }}>
                <td style={{ padding: "10px 12px", fontWeight: 700 }}>
                  {e.rank === 1 ? "🥇" : e.rank === 2 ? "🥈" : e.rank === 3 ? "🥉" : e.rank}
                </td>
                <td style={{ padding: "10px 12px", fontWeight: 600 }}>{e.username}</td>
                <td style={{ padding: "10px 12px" }}>
                  <span
                    style={{
                      display: "inline-block",
                      minWidth: 48,
                      textAlign: "center",
                      padding: "2px 10px",
                      borderRadius: 999,
                      fontWeight: 700,
                      color: "#fff",
                      background: scoreColor(e.score),
                    }}
                  >
                    {e.score ?? "—"}
                  </span>
                </td>
                <td style={{ padding: "10px 12px" }}>{e.tripCount}</td>
                <td style={{ padding: "10px 12px", color: "#6b7280" }}>
                  {e.avgConfidence != null ? `${Math.round(e.avgConfidence * 100)} %` : "—"}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <p style={{ marginTop: "1.5rem", fontSize: 12, color: "#9ca3af" }}>
        Der Score ist der konfidenzgewichtete Durchschnitt aller Fahrt-Scores. Fahrten ohne OBD-Daten
        oder mit wenigen GPS-Punkten zählen mit geringerem Gewicht.
      </p>
    </main>
  );
}
