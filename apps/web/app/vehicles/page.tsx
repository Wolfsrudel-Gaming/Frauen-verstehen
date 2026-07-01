import { backendFetch } from "../lib/auth";
import { createVehicleAction, deactivateVehicleAction } from "./actions";

type Vehicle = {
  id: string;
  make: string;
  model: string;
  year: number | null;
  licensePlate: string | null;
  vin: string | null;
  category: string;
  protocolSupport: string;
  isActive: boolean;
  notes: string | null;
};

const CATEGORIES = ["car", "motorcycle", "bicycle", "ebike", "oldtimer", "truck", "van", "other"];
const PROTOCOLS = ["obd2", "gps_only", "none"];

const cardStyle: React.CSSProperties = {
  border: "1px solid #e5e7eb",
  borderRadius: 8,
  padding: "1rem",
  marginBottom: "0.75rem",
  display: "flex",
  justifyContent: "space-between",
  alignItems: "flex-start",
};

const badgeStyle = (color: string): React.CSSProperties => ({
  display: "inline-block",
  padding: "2px 8px",
  borderRadius: 4,
  fontSize: 12,
  fontWeight: 600,
  background: color,
  color: "#fff",
  marginRight: 4,
});

function protocolColor(p: string) {
  if (p === "obd2") return "#0070f3";
  if (p === "gps_only") return "#16a34a";
  return "#6b7280";
}

function categoryLabel(c: string) {
  return c.charAt(0).toUpperCase() + c.slice(1).replace("_", "-");
}

export default async function VehiclesPage() {
  const res = await backendFetch("/vehicles");
  const vehicles: Vehicle[] = res.ok ? await res.json() : [];

  return (
    <main style={{ fontFamily: "sans-serif", padding: "2rem", maxWidth: 800 }}>
      <h1 style={{ marginBottom: "1.5rem" }}>Vehicles</h1>

      {vehicles.length === 0 ? (
        <p style={{ color: "#888", marginBottom: "2rem" }}>No vehicles yet. Add one below.</p>
      ) : (
        <section style={{ marginBottom: "2rem" }}>
          {vehicles.map((v) => (
            <div key={v.id} style={{ ...cardStyle, opacity: v.isActive ? 1 : 0.5 }}>
              <div>
                <strong style={{ fontSize: 18 }}>
                  {v.make} {v.model}
                  {v.year ? ` (${v.year})` : ""}
                </strong>
                <div style={{ marginTop: 4 }}>
                  <span style={badgeStyle(protocolColor(v.protocolSupport))}>{v.protocolSupport}</span>
                  <span style={badgeStyle("#6b7280")}>{categoryLabel(v.category)}</span>
                  {!v.isActive && <span style={badgeStyle("#dc2626")}>inactive</span>}
                </div>
                {v.licensePlate && (
                  <div style={{ color: "#555", marginTop: 4, fontSize: 14 }}>
                    Plate: {v.licensePlate}
                  </div>
                )}
                {v.notes && <div style={{ color: "#888", fontSize: 13, marginTop: 4 }}>{v.notes}</div>}
              </div>
              {v.isActive && (
                <form
                  action={async () => {
                    "use server";
                    await deactivateVehicleAction(v.id);
                  }}
                >
                  <button
                    type="submit"
                    style={{ padding: "4px 10px", cursor: "pointer", border: "1px solid #dc2626", color: "#dc2626", background: "none", borderRadius: 4, fontSize: 13 }}
                  >
                    Deactivate
                  </button>
                </form>
              )}
            </div>
          ))}
        </section>
      )}

      <section style={{ border: "1px solid #e5e7eb", borderRadius: 8, padding: "1.5rem" }}>
        <h2 style={{ margin: "0 0 1rem", fontSize: 18 }}>Add Vehicle</h2>
        <form action={createVehicleAction} style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem" }}>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>Make *</span>
              <input name="make" required style={inputStyle} placeholder="e.g. BMW" />
            </label>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>Model *</span>
              <input name="model" required style={inputStyle} placeholder="e.g. 320d" />
            </label>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>Year</span>
              <input name="year" type="number" min={1900} max={2100} style={inputStyle} placeholder="2023" />
            </label>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>License Plate</span>
              <input name="licensePlate" style={inputStyle} placeholder="AB-CD 123" />
            </label>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>Category</span>
              <select name="category" defaultValue="car" style={inputStyle}>
                {CATEGORIES.map((c) => (
                  <option key={c} value={c}>{categoryLabel(c)}</option>
                ))}
              </select>
            </label>
            <label>
              <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>OBD Support</span>
              <select name="protocolSupport" defaultValue="obd2" style={inputStyle}>
                {PROTOCOLS.map((p) => (
                  <option key={p} value={p}>{p}</option>
                ))}
              </select>
            </label>
          </div>
          <label>
            <span style={{ display: "block", fontWeight: 600, marginBottom: 4 }}>Notes</span>
            <textarea name="notes" rows={2} style={{ ...inputStyle, resize: "vertical" }} />
          </label>
          <button type="submit" style={submitStyle}>Add Vehicle</button>
        </form>
      </section>
    </main>
  );
}

const inputStyle: React.CSSProperties = {
  width: "100%",
  padding: "0.5rem",
  boxSizing: "border-box",
  border: "1px solid #d1d5db",
  borderRadius: 4,
  fontSize: 14,
};

const submitStyle: React.CSSProperties = {
  alignSelf: "flex-start",
  padding: "0.6rem 1.4rem",
  background: "#0070f3",
  color: "#fff",
  border: "none",
  borderRadius: 4,
  fontWeight: 600,
  cursor: "pointer",
  fontSize: 15,
};
