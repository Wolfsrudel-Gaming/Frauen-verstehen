"use client";

import type { CurrentUser } from "../lib/auth";
import { switchOrgAction } from "../actions/switchOrg";
import { logoutAction } from "../actions/logout";

type Props = { currentUser: CurrentUser };

export default function OrgSwitcher({ currentUser }: Props) {
  const { user, activeOrgId, orgs } = currentUser;
  const activeOrg = orgs.find((o) => o.orgId === activeOrgId);

  return (
    <header
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "space-between",
        padding: "0.6rem 1.5rem",
        borderBottom: "1px solid #e5e7eb",
        background: "#fff",
        fontFamily: "sans-serif",
        fontSize: 14,
      }}
    >
      <span style={{ fontWeight: 700, color: "#0070f3" }}>Driver Analytics</span>

      <div style={{ display: "flex", alignItems: "center", gap: "1rem" }}>
        {orgs.length > 1 ? (
          <form action={switchOrgAction} style={{ display: "flex", alignItems: "center", gap: "0.4rem" }}>
            <label htmlFor="orgId" style={{ color: "#555" }}>Org:</label>
            <select
              id="orgId"
              name="orgId"
              defaultValue={activeOrgId}
              onChange={(e) => (e.target.form as HTMLFormElement).requestSubmit()}
              style={{ border: "1px solid #ccc", borderRadius: 4, padding: "0.25rem 0.4rem" }}
            >
              {orgs.map((o) => (
                <option key={o.orgId} value={o.orgId}>
                  {o.orgName}
                </option>
              ))}
            </select>
          </form>
        ) : (
          <span style={{ color: "#555" }}>
            {activeOrg?.orgName ?? "—"}
          </span>
        )}

        <span style={{ color: "#888" }}>
          {user.username}
          {currentUser.activeRole === "admin" && (
            <span style={{ marginLeft: 4, fontSize: 11, background: "#fef3c7", color: "#92400e", padding: "1px 5px", borderRadius: 3 }}>
              admin
            </span>
          )}
        </span>

        <form action={logoutAction}>
          <button
            type="submit"
            style={{
              background: "none",
              border: "1px solid #ccc",
              borderRadius: 4,
              padding: "0.2rem 0.6rem",
              cursor: "pointer",
              color: "#555",
            }}
          >
            Sign out
          </button>
        </form>
      </div>
    </header>
  );
}
