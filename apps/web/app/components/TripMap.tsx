"use client";

import { useEffect, useRef } from "react";

export type LatLon = { lat: number; lon: number; isEstimated?: boolean };

type Props = {
  points: LatLon[];
  height?: number;
};

export default function TripMap({ points, height = 400 }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<unknown>(null);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;
    if (points.length === 0) return;

    // Dynamically import Leaflet to avoid SSR issues
    void (async () => {
      const L = (await import("leaflet")).default;

      // Fix default marker icon paths broken by webpack
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      delete (L.Icon.Default.prototype as any)._getIconUrl;
      L.Icon.Default.mergeOptions({
        iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
        iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
        shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
      });

      // Import CSS
      if (!document.getElementById("leaflet-css")) {
        const link = document.createElement("link");
        link.id = "leaflet-css";
        link.rel = "stylesheet";
        link.href = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css";
        document.head.appendChild(link);
      }

      const map = L.map(containerRef.current!);
      mapRef.current = map;

      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        maxZoom: 19,
      }).addTo(map);

      const latlngs = points.map((p) => [p.lat, p.lon] as [number, number]);

      // Draw the full track
      const realPoints = points.filter((p) => !p.isEstimated);
      const estPoints = points.filter((p) => p.isEstimated);

      if (realPoints.length > 1) {
        L.polyline(
          realPoints.map((p) => [p.lat, p.lon]),
          { color: "#0070f3", weight: 4, opacity: 0.85 },
        ).addTo(map);
      }
      if (estPoints.length > 1) {
        L.polyline(
          estPoints.map((p) => [p.lat, p.lon]),
          { color: "#f59e0b", weight: 3, opacity: 0.7, dashArray: "6 4" },
        ).addTo(map);
      }

      // Start and end markers
      L.circleMarker(latlngs[0], { radius: 8, color: "#16a34a", fillColor: "#16a34a", fillOpacity: 1 })
        .bindPopup("Start")
        .addTo(map);
      if (latlngs.length > 1) {
        L.circleMarker(latlngs[latlngs.length - 1], {
          radius: 8,
          color: "#dc2626",
          fillColor: "#dc2626",
          fillOpacity: 1,
        })
          .bindPopup("End")
          .addTo(map);
      }

      map.fitBounds(L.latLngBounds(latlngs), { padding: [24, 24] });
    })();

    return () => {
      if (mapRef.current) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (mapRef.current as any).remove();
        mapRef.current = null;
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (points.length === 0) {
    return (
      <div
        style={{
          height,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          background: "#f3f4f6",
          borderRadius: 8,
          color: "#6b7280",
          fontSize: 14,
        }}
      >
        No GPS points recorded for this trip.
      </div>
    );
  }

  return <div ref={containerRef} style={{ height, borderRadius: 8, overflow: "hidden" }} />;
}
