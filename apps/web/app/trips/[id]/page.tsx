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

// Postgres numeric columns come back as strings from Drizzle
type ObdReadingRaw = {
  recordedAt: string;
  rpmX4: number | null;
  speedKmh: number | null;
  coolantTempC: number | null;
  throttlePos: string | null;
  fuelLevelPct: string | null;
  intakeAirTempC: number | null;
  mafGps: string | null;
};

type ObdReading = Omit<ObdReadingRaw, "throttlePos" | "fuelLevelPct" | "mafGps"> & {
  throttlePos: number | null;
  fuelLevelPct: number | null;
  mafGps: number | null;
};

type DtcEvent = {
  code: string;
  severity: string | null;
  detectedAt: string;
  clearedAt: string | null;
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

  const [tripRes, pointsRes, obdRes, dtcRes] = await Promise.all([
    backendFetch(`/trips/${id}`),
    backendFetch(`/trips/${id}/points`),
    backendFetch(`/trips/${id}/obd/readings`),
    backendFetch(`/trips/${id}/dtc`),
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
  const rawObd: ObdReadingRaw[] = obdRes.ok ? await obdRes.json() : [];
  const obdReadings: ObdReading[] = rawObd.map((r) => ({
    ...r,
    throttlePos: r.throttlePos != null ? Number(r.throttlePos) : null,
    fuelLevelPct: r.fuelLevelPct != null ? Number(r.fuelLevelPct) : null,
    mafGps: r.mafGps != null ? Number(r.mafGps) : null,
  }));
  const dtcEvents: DtcEvent[] = dtcRes.ok ? await dtcRes.json() : [];

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

  const obdMaxSpeed = obdReadings.length
    ? Math.max(...obdReadings.filter((r) => r.speedKmh != null).map((r) => r.speedKmh!))
    : null;
  const obdAvgRpm =
    obdReadings.filter((r) => r.rpmX4 != null).length
      ? obdReadings.filter((r) => r.rpmX4 != null).reduce((s, r) => s + r.rpmX4! / 4, 0) /
        obdReadings.filter((r) => r.rpmX4 != null).length
      : null;
  const lastObd = obdReadings.length ? obdReadings[obdReadings.length - 1] : null;

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

      {/* OBD summary */}
      {obdReadings.length > 0 && (
        <div style={{ marginBottom: "1.5rem" }}>
          <h2 style={{ fontSize: 18, marginBottom: "0.75rem" }}>OBD Data</h2>
          <div style={{ display: "flex", flexWrap: "wrap", gap: "0.75rem", marginBottom: "1rem" }}>
            <div style={statBox}>
              <div style={{ fontSize: 12, color: "#888" }}>Readings</div>
              <div style={{ fontWeight: 700, fontSize: 20 }}>{obdReadings.length}</div>
            </div>
            {obdAvgRpm != null && (
              <div style={statBox}>
                <div style={{ fontSize: 12, color: "#888" }}>Avg RPM</div>
                <div style={{ fontWeight: 700, fontSize: 20 }}>{obdAvgRpm.toFixed(0)}</div>
              </div>
            )}
            {obdMaxSpeed != null && (
              <div style={statBox}>
                <div style={{ fontSize: 12, color: "#888" }}>Max Speed (OBD)</div>
                <div style={{ fontWeight: 700, fontSize: 20 }}>{obdMaxSpeed} km/h</div>
              </div>
            )}
            {lastObd?.coolantTempC != null && (
              <div style={{ ...statBox, background: lastObd.coolantTempC > 100 ? "#fee2e2" : undefined }}>
                <div style={{ fontSize: 12, color: "#888" }}>Last Coolant Temp</div>
                <div style={{ fontWeight: 700, fontSize: 20 }}>{lastObd.coolantTempC}°C</div>
              </div>
            )}
            {lastObd?.fuelLevelPct != null && (
              <div style={{ ...statBox, background: lastObd.fuelLevelPct < 10 ? "#fef3c7" : undefined }}>
                <div style={{ fontSize: 12, color: "#888" }}>Last Fuel Level</div>
                <div style={{ fontWeight: 700, fontSize: 20 }}>{lastObd.fuelLevelPct.toFixed(1)}%</div>
              </div>
            )}
          </div>

          {/* OBD readings table (last 20) */}
          <details>
            <summary style={{ cursor: "pointer", fontSize: 13, color: "#555", marginBottom: "0.5rem" }}>
              Show last {Math.min(20, obdReadings.length)} readings
            </summary>
            <div style={{ overflowX: "auto" }}>
              <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
                <thead>
                  <tr style={{ background: "#f9fafb" }}>
                    {["Time", "RPM", "Speed", "Coolant", "Throttle", "Fuel", "MAF"].map((h) => (
                      <th key={h} style={{ padding: "6px 10px", textAlign: "left", borderBottom: "1px solid #e5e7eb", fontWeight: 600 }}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {obdReadings.slice(-20).map((r, i) => (
                    <tr key={i} style={{ borderBottom: "1px solid #f3f4f6" }}>
                      <td style={{ padding: "5px 10px", color: "#888" }}>
                        {new Date(r.recordedAt).toLocaleTimeString("de-DE")}
                      </td>
                      <td style={{ padding: "5px 10px" }}>{r.rpmX4 != null ? (r.rpmX4 / 4).toFixed(0) : "—"}</td>
                      <td style={{ padding: "5px 10px" }}>{r.speedKmh != null ? `${r.speedKmh} km/h` : "—"}</td>
                      <td style={{ padding: "5px 10px" }}>{r.coolantTempC != null ? `${r.coolantTempC}°C` : "—"}</td>
                      <td style={{ padding: "5px 10px" }}>{r.throttlePos != null ? `${r.throttlePos.toFixed(1)}%` : "—"}</td>
                      <td style={{ padding: "5px 10px" }}>{r.fuelLevelPct != null ? `${r.fuelLevelPct.toFixed(1)}%` : "—"}</td>
                      <td style={{ padding: "5px 10px" }}>{r.mafGps != null ? `${r.mafGps.toFixed(1)} g/s` : "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </details>
        </div>
      )}

      {/* DTC events */}
      {dtcEvents.length > 0 && (
        <div style={{ marginBottom: "1.5rem" }}>
          <h2 style={{ fontSize: 18, marginBottom: "0.75rem", color: "#dc2626" }}>
            Fault Codes ({dtcEvents.length})
          </h2>
          <div style={{ display: "flex", flexDirection: "column", gap: "0.5rem" }}>
            {dtcEvents.map((dtc, i) => (
              <div
                key={i}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "0.75rem",
                  border: "1px solid #fca5a5",
                  borderRadius: 8,
                  padding: "0.6rem 1rem",
                  background: dtc.clearedAt ? "#f9fafb" : "#fff1f2",
                }}
              >
                <span style={{ fontFamily: "monospace", fontWeight: 700, fontSize: 15 }}>{dtc.code}</span>
                {dtc.severity && (
                  <span style={{ fontSize: 11, padding: "1px 6px", borderRadius: 4, background: "#fee2e2", color: "#991b1b" }}>
                    {dtc.severity}
                  </span>
                )}
                <span style={{ fontSize: 12, color: "#888", marginLeft: "auto" }}>
                  {dtc.clearedAt ? "cleared" : `detected ${new Date(dtc.detectedAt).toLocaleString("de-DE")}`}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}
    </main>
  );
}
