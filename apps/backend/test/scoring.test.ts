import { describe, it, expect } from "vitest";
import {
  computeTripScore,
  type GpsSample,
  type ObdSample,
} from "../src/modules/scoring/engine.js";

// Builds a GPS sample series: one point per second with the given speeds
function gpsSeries(speedsKmh: number[]): GpsSample[] {
  const t0 = new Date("2026-01-01T10:00:00Z").getTime();
  return speedsKmh.map((s, i) => ({ speedKmh: s, recordedAt: new Date(t0 + i * 1000) }));
}

function obdSeries(rpms: number[], coolant = 90): ObdSample[] {
  const t0 = new Date("2026-01-01T10:00:00Z").getTime();
  return rpms.map((rpm, i) => ({
    rpmX4: rpm * 4,
    coolantTempC: coolant,
    recordedAt: new Date(t0 + i * 2000),
  }));
}

describe("computeTripScore", () => {
  it("returns null with too little data", () => {
    expect(computeTripScore(gpsSeries([10, 20]), [], 5)).toBeNull();
    expect(computeTripScore(gpsSeries([10, 20, 30, 40, 50, 60]), [], 0.1)).toBeNull();
  });

  it("gives a perfect score for smooth constant driving", () => {
    const smooth = gpsSeries(Array.from({ length: 60 }, () => 50));
    const result = computeTripScore(smooth, [], 10);
    expect(result).not.toBeNull();
    expect(result!.totalScore).toBe(100);
    expect(result!.sourceType).toBe("gps");
  });

  it("penalises harsh braking", () => {
    // 50 → 15 km/h in 1s ≈ -9.7 m/s² — very harsh
    const speeds = [...Array.from({ length: 30 }, () => 50), 15, 15, 15, 15, 15];
    const result = computeTripScore(gpsSeries(speeds), [], 1);
    expect(result).not.toBeNull();
    expect(result!.breakdown.metrics.harshBrakeCount).toBeGreaterThanOrEqual(1);
    expect(result!.totalScore).toBeLessThan(100);
  });

  it("penalises harsh acceleration", () => {
    // 10 → 45 km/h in 1s ≈ +9.7 m/s²
    const speeds = [10, 10, 10, 45, 45, 45, 45, 45, 45, 45];
    const result = computeTripScore(gpsSeries(speeds), [], 1);
    expect(result!.breakdown.metrics.harshAccelCount).toBeGreaterThanOrEqual(1);
    expect(result!.breakdown.penalties.harshAccel).toBeGreaterThan(0);
  });

  it("caps individual penalties so one metric cannot zero the score alone", () => {
    // Alternating hard accel/brake — lots of harsh events on a short trip
    const speeds = Array.from({ length: 60 }, (_, i) => (i % 2 === 0 ? 10 : 50));
    const result = computeTripScore(gpsSeries(speeds), [], 0.5);
    expect(result!.breakdown.penalties.harshAccel).toBeLessThanOrEqual(40);
    expect(result!.breakdown.penalties.harshBrake).toBeLessThanOrEqual(40);
    expect(result!.totalScore).toBeGreaterThanOrEqual(0);
  });

  it("penalises sustained over-revving via OBD", () => {
    const smooth = gpsSeries(Array.from({ length: 60 }, () => 50));
    const highRpm = obdSeries(Array.from({ length: 30 }, () => 5500));
    const result = computeTripScore(smooth, highRpm, 10);
    expect(result!.breakdown.metrics.overRevFraction).toBe(1);
    expect(result!.breakdown.penalties.overRev).toBe(10); // capped
    expect(result!.sourceType).toBe("combined");
  });

  it("applies the overheat penalty once", () => {
    const smooth = gpsSeries(Array.from({ length: 60 }, () => 50));
    const hot = obdSeries(Array.from({ length: 30 }, () => 2000), 112);
    const result = computeTripScore(smooth, hot, 10);
    expect(result!.breakdown.penalties.overheat).toBe(10);
    expect(result!.breakdown.metrics.maxCoolantC).toBe(112);
  });

  it("boosts confidence with more data and OBD presence", () => {
    const few = computeTripScore(gpsSeries(Array.from({ length: 10 }, () => 50)), [], 5);
    const many = computeTripScore(gpsSeries(Array.from({ length: 100 }, () => 50)), [], 5);
    const withObd = computeTripScore(
      gpsSeries(Array.from({ length: 100 }, () => 50)),
      obdSeries(Array.from({ length: 30 }, () => 2000)),
      5,
    );
    expect(few!.confidenceWeight).toBe(0.6);
    expect(many!.confidenceWeight).toBe(0.8);
    expect(withObd!.confidenceWeight).toBe(1.0);
  });

  it("ignores GPS gaps that are too long for acceleration inference", () => {
    const t0 = new Date("2026-01-01T10:00:00Z").getTime();
    // Huge speed jump but 60s apart — must not count as harsh accel
    const gps: GpsSample[] = [
      { speedKmh: 10, recordedAt: new Date(t0) },
      { speedKmh: 10, recordedAt: new Date(t0 + 1000) },
      { speedKmh: 10, recordedAt: new Date(t0 + 2000) },
      { speedKmh: 100, recordedAt: new Date(t0 + 62000) },
      { speedKmh: 100, recordedAt: new Date(t0 + 63000) },
      { speedKmh: 100, recordedAt: new Date(t0 + 64000) },
    ];
    const result = computeTripScore(gps, [], 5);
    expect(result!.breakdown.metrics.harshAccelCount).toBe(0);
  });
});
