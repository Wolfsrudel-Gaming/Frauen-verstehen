import { backendFetch } from "../../lib/auth";
import TripMap, { type LatLon } from "../../components/TripMap";
import Link from "next/link";

type Props = { params: Promise<{ id: string }> };

type Trip = {
  id: string;
  status: string;
  startedAt: string;
  endedAt: string | null;
  distanceKm: string | null;
  startOdometer: number | null;
  endOdometer: number | null;
  vehicleId: string | null;
  notes: string | null;
  startTrigger: string;
  endTrigger: string | null;
};

type Point = {
  lat: string;
  lon: string;
  speedKmh: string | null;
  altitudeM: string | null;
  accuracyM: string | null;
  isEstimated: boolean;
  recordedAt: string;
};

function formatDate(iso: string) {
  return new Date(iso).toLocaleString("de-DE", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

function duration(start: string, end: string | null) {
  if (!end) return "in progress";
  const ms = new Date(end).getTime() - new Date(start).getTime();
  const mins = Math.round(ms / 60000);
  if (mins < 60) return `${mins} min`;
  const h = Math.floor(mins / 60);
  return `${h}h ${mins % 60}min`;
}

const statBox: React.CSSProperties = {
  border: "1px solid #e5e7eb",
  borderRadius: 8,
  padding: "0.75rem 1rem",
  flex: 1,
  minWidth: 120,
};

export default async function TripDetailPage({ params }: Props) {
  const { id } = await params;

  const [tripRes, pointsRes] = await Promise.all([
    backendFetch(`/trips/${id}`),
    backendFetch(`/trips/${id}/points`),
  ]);

  if (!tripRes.ok) {
    return (
      <main style={{ fontFamily: "sans-serif", padding: "2rem" }}>
        <Link href="/trips" style={{ color: "#0070f3" }}>← Trips</Link>
        <p style={{ color: "red", marginTop: "1rem" }}>Trip not found.</p>
      </main>
    );
  }

  const trip: Trip = await tripRes.json();
  const rawPoints: Point[] = pointsRes.ok ? await pointsRes.json() : [];

  const mapPoints: LatLon[] = rawPoints.map((p) => ({
    lat: Number(p.lat),
    lon: Number(p.lon),
    isEstimated: p.isEstimated,
  }));

  const maxSpeed = rawPoints.length
    ? Math.max(...rawPoints.filter((p) => p.speedKmh).map((p) => Number(p.speedKmh)))
    : null;

  const avgSpeed =
    rawPoints.filter((p) => p.speedKmh).length
      ? rawPoints.filter((p) => p.speedKmh).reduce((s, p) => s + Number(p.speedKmh), 0) /
        rawPoints.filter((p) => p.speedKmh).length
      : null;

  const statusColor: Record<string, string> = {
    in_progress: "#f59e0b",
    completed: "#16a34a",
    discarded: "#6b7280",
  };

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem", maxWidth: 900 }}>
      <div style={{ marginBottom: "1rem" }}>
        <Link href="/trips" style={{ color: "#0070f3", textDecoration: "none", fontSize: 14 }}>
          ← Back to Trips
        </Link>
      </div>

      <h1 style={{ marginBottom: "0.25rem" }}>Trip Detail</h1>
      <p style={{ color: "#555", marginTop: 0, marginBottom: "1.5rem" }}>
        {formatDate(trip.startedAt)}
        <span
          style={{
            marginLeft: 12,
            padding: "2px 8px",
            borderRadius: 4,
            fontSize: 12,
            fontWeight: 600,
            background: statusColor[trip.status] ?? "#6b7280",
            color: "#fff",
          }}
        >
          {trip.status.replace("_", " ")}
        </span>
      </p>

      {/* Map */}
      <div style={{ marginBottom: "1.5rem" }}>
        <TripMap points={mapPoints} height={420} />
        {mapPoints.some((p) => p.isEstimated) && (
          <p style={{ fontSize: 12, color: "#888", marginTop: 6 }}>
            <span style={{ display: "inline-block", width: 20, borderTop: "2px dashed #f59e0b", verticalAlign: "middle", marginRight: 4 }} />
            Dashed sections are dead-reckoned estimates (GPS signal gap).
          </p>
        )}
      </div>

      {/* Stats */}
      <div style={{ display: "flex", flexWrap: "wrap", gap: "0.75rem", marginBottom: "1.5rem" }}>
        <div style={statBox}>
          <div style={{ fontSize: 12, color: "#888" }}>Duration</div>
          <div style={{ fontWeight: 700, fontSize: 20 }}>{duration(trip.startedAt, trip.endedAt)}</div>
        </div>
        <div style={statBox}>
          <div style={{ fontSize: 12, color: "#888" }}>Distance</div>
          <div style={{ fontWeight: 700, fontSize: 20 }}>
            {trip.distanceKm ? `${parseFloat(trip.distanceKm).toFixed(2)} km` : "—"}
          </div>
        </div>
        <div style={statBox}>
          <div style={{ fontSize: 12, color: "#888" }}>GPS Points</div>
          <div style={{ fontWeight: 700, fontSize: 20 }}>{rawPoints.length}</div>
        </div>
        {maxSpeed != null && (
          <div style={statBox}>
            <div style={{ fontSize: 12, color: "#888" }}>Max Speed</div>
            <div style={{ fontWeight: 700, fontSize: 20 }}>{maxSpeed.toFixed(0)} km/h</div>
          </div>
        )}
        {avgSpeed != null && (
          <div style={statBox}>
            <div style={{ fontSize: 12, color: "#888" }}>Avg Speed</div>
            <div style={{ fontWeight: 700, fontSize: 20 }}>{avgSpeed.toFixed(0)} km/h</div>
          </div>
        )}
        {trip.startOdometer != null && (
          <div style={statBox}>
            <div style={{ fontSize: 12, color: "#888" }}>Odometer</div>
            <div style={{ fontWeight: 700, fontSize: 20 }}>
              {trip.startOdometer}
              {trip.endOdometer ? ` → ${trip.endOdometer}` : ""} km
            </div>
          </div>
        )}
      </div>

      {trip.notes && (
        <div style={{ border: "1px solid #e5e7eb", borderRadius: 8, padding: "0.75rem 1rem", marginBottom: "1.5rem" }}>
          <span style={{ fontWeight: 600 }}>Notes:</span> {trip.notes}
        </div>
      )}
    </main>
  );
}
