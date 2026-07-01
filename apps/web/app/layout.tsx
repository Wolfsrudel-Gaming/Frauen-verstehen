import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import { getCurrentUser } from "./lib/auth";
import OrgSwitcher from "./components/OrgSwitcher";

const geistSans = Geist({ variable: "--font-geist-sans", subsets: ["latin"] });
const geistMono = Geist_Mono({ variable: "--font-geist-mono", subsets: ["latin"] });

export const metadata: Metadata = {
  title: "Driver Analytics",
  description: "Fleet & driver analytics platform",
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  // getCurrentUser() throws if not authenticated; proxy.ts redirects before we get here.
  // On the /login page getCurrentUser will fail, but that route is unauthenticated.
  let currentUser;
  try {
    currentUser = await getCurrentUser();
  } catch {
    currentUser = null;
  }

  return (
    <html lang="de" className={`${geistSans.variable} ${geistMono.variable}`}>
      <body style={{ margin: 0, minHeight: "100vh", display: "flex", flexDirection: "column" }}>
        {currentUser && <OrgSwitcher currentUser={currentUser} />}
        <div style={{ flex: 1 }}>{children}</div>
      </body>
    </html>
  );
}
