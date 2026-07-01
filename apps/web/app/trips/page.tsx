import { backendFetch } from "../lib/auth";
import { startTripAction, endTripAction, discardTripAction } from "./actions";

type Trip = {
  id: string;
  status: string;
  startTrigger: string;
  startedAt: string;
  endedAt: string | null;
  distanceKm: string | null;
  startOdometer: number | null;
  endOdometer: number | null;
  vehicleId: string | null;
  notes: string | null;
};

type Vehicle = { id: string; make: string; model: string; isActive: boolean };

const statusColor: Record<string, string> = {
  in_progress: "#f59e0b",
  completed: "#16a34a",
  discarded: "#6b7280",
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

const inputStyle: React.CSSProperties = {
  width: "100%",
  padding: "0.45rem",
  boxSizing: "border-box",
  border: "1px solid #d1d5db",
  borderRadius: 4,
  fontSize: 14,
};

export default async function TripsPage() {
  const [tripsRes, vehiclesRes] = await Promise.all([
    backendFetch("/trips"),
    backendFetch("/vehicles"),
  ]);
  const trips: Trip[] = tripsRes.ok ? await tripsRes.json() : [];
  const vehicles: Vehicle[] = vehiclesRes.ok ? await vehiclesRes.json() : [];
  const activeVehicles = vehicles.filter((v) => v.isActive);

  const hasActiveTrip = trips.some((t) => t.status === "in_progress");

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem", maxWidth: 800 }}>
      <h1 style={{ marginBottom: "1.5rem" }}>Trips</h1>

      {!hasActiveTrip && (
        <section style={{ border: "1px solid #e5e7eb", borderRadius: 8, padding: "1.5rem", marginBottom: "2rem" }}>
          <h2 style={{ margin: "0 0 1rem", fontSize: 18 }}>Start New Trip</h2>
          <form action={startTripAction} style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>Vehicle</span>
              <select name="vehicleId" style={inputStyle}>
                <option value="">— no vehicle —</option>
                {activeVehicles.map((v) => (
                  <option key={v.id} value={v.id}>{v.make} {v.model}</option>
                ))}
              </select>
            </label>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>Start Odometer (km)</span>
              <input name="startOdometer" type="number" min={0} style={inputStyle} placeholder="optional" />
            </label>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>Notes</span>
              <input name="notes" style={inputStyle} placeholder="optional" />
            </label>
            <button
              type="submit"
              style={{ alignSelf: "flex-start", padding: "0.6rem 1.4rem", background: "#16a34a", color: "#fff", border: "none", borderRadius: 4, fontWeight: 600, cursor: "pointer", fontSize: 15 }}
            >
              Start Trip
            </button>
          </form>
        </section>
      )}

      {trips.length === 0 ? (
        <p style={{ color: "#888" }}>No trips recorded yet.</p>
      ) : (
        <section>
          {trips.map((t) => (
            <div
              key={t.id}
              style={{ border: `1px solid ${t.status === "in_progress" ? "#f59e0b" : "#e5e7eb"}`, borderRadius: 8, padding: "1rem", marginBottom: "0.75rem" }}
            >
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                <div>
                  <span
                    style={{ display: "inline-block", padding: "2px 8px", borderRadius: 4, fontSize: 12, fontWeight: 600, background: statusColor[t.status] ?? "#6b7280", color: "#fff", marginBottom: 6 }}
                  >
                    {t.status.replace("_", " ")}
                  </span>
                  <div style={{ fontWeight: 600, fontSize: 16 }}>
                    {formatDate(t.startedAt)}
                  </div>
                  <div style={{ color: "#555", fontSize: 14, marginTop: 2 }}>
                    Duration: {duration(t.startedAt, t.endedAt)}
                    {t.distanceKm && ` · ${parseFloat(t.distanceKm).toFixed(1)} km`}
                    {t.startOdometer && t.endOdometer && ` · Odo: ${t.startOdometer}→${t.endOdometer} km`}
                  </div>
                  {t.notes && <div style={{ color: "#888", fontSize: 13, marginTop: 4 }}>{t.notes}</div>}
                </div>

                {t.status === "in_progress" && (
                  <div style={{ display: "flex", gap: "0.5rem", flexShrink: 0 }}>
                    <form
                      action={async (fd: FormData) => {
                        "use server";
                        await endTripAction(t.id, fd);
                      }}
                      style={{ display: "flex", gap: "0.5rem", alignItems: "flex-end" }}
                    >
                      <label style={{ fontSize: 13 }}>
                        End odo
                        <input name="endOdometer" type="number" min={0} style={{ ...inputStyle, width: 90, marginTop: 2 }} placeholder="km" />
                      </label>
                      <button
                        type="submit"
                        style={{ padding: "0.5rem 0.9rem", background: "#0070f3", color: "#fff", border: "none", borderRadius: 4, fontWeight: 600, cursor: "pointer", fontSize: 13 }}
                      >
                        End Trip
                      </button>
                    </form>
                    <form
                      action={async () => {
                        "use server";
                        await discardTripAction(t.id);
                      }}
                    >
                      <button
                        type="submit"
                        style={{ padding: "0.5rem 0.8rem", background: "none", color: "#dc2626", border: "1px solid #dc2626", borderRadius: 4, cursor: "pointer", fontSize: 13, marginTop: 22 }}
                      >
                        Discard
                      </button>
                    </form>
                  </div>
                )}
              </div>
            </div>
          ))}
        </section>
      )}
    </main>
  );
}
