import { loginAction } from "./actions";

type Props = { searchParams: Promise<{ error?: string }> };

export default async function LoginPage({ searchParams }: Props) {
  const { error } = await searchParams;

  return (
    <main style={{ fontFamily: "sans-serif", maxWidth: 400, margin: "4rem auto", padding: "0 1rem" }}>
      <h1 style={{ marginBottom: "1.5rem" }}>Driver Analytics — Sign In</h1>

      {error && (
        <p style={{ color: "red", background: "#ffeef0", padding: "0.5rem 0.75rem", borderRadius: 4, marginBottom: "1rem" }}>
          {error}
        </p>
      )}

      <form action={loginAction} style={{ display: "flex", flexDirection: "column", gap: "0.75rem" }}>
        <label>
          <span style={{ display: "block", marginBottom: 4, fontWeight: 600 }}>Username</span>
          <input
            name="username"
            required
            autoComplete="username"
            style={{ width: "100%", padding: "0.5rem", boxSizing: "border-box", border: "1px solid #ccc", borderRadius: 4 }}
          />
        </label>

        <label>
          <span style={{ display: "block", marginBottom: 4, fontWeight: 600 }}>Password</span>
          <input
            name="password"
            type="password"
            required
            autoComplete="current-password"
            style={{ width: "100%", padding: "0.5rem", boxSizing: "border-box", border: "1px solid #ccc", borderRadius: 4 }}
          />
        </label>

        <label>
          <span style={{ display: "block", marginBottom: 4, fontWeight: 600 }}>
            2FA Code <span style={{ fontWeight: 400, color: "#888" }}>(admins only)</span>
          </span>
          <input
            name="totpToken"
            inputMode="numeric"
            pattern="[0-9]{6}"
            maxLength={6}
            placeholder="6-digit code"
            style={{ width: "100%", padding: "0.5rem", boxSizing: "border-box", border: "1px solid #ccc", borderRadius: 4 }}
          />
        </label>

        <button
          type="submit"
          style={{
            marginTop: "0.5rem",
            padding: "0.6rem 1.2rem",
            background: "#0070f3",
            color: "#fff",
            border: "none",
            borderRadius: 4,
            fontWeight: 600,
            cursor: "pointer",
          }}
        >
          Sign in
        </button>
      </form>
    </main>
  );
}
