"use server";

import { revalidatePath } from "next/cache";
import { backendFetch } from "../lib/auth";

export async function startTripAction(formData: FormData) {
  const body: Record<string, unknown> = { startTrigger: "manual" };

  const vehicleId = formData.get("vehicleId") as string;
  if (vehicleId) body.vehicleId = vehicleId;

  const startOdometer = formData.get("startOdometer") as string;
  if (startOdometer) body.startOdometer = parseInt(startOdometer, 10);

  const notes = formData.get("notes") as string;
  if (notes) body.notes = notes;

  await backendFetch("/trips/start", {
    method: "POST",
    body: JSON.stringify(body),
  });

  revalidatePath("/trips");
}

export async function endTripAction(tripId: string, formData: FormData) {
  const body: Record<string, unknown> = { endTrigger: "manual" };

  const endOdometer = formData.get("endOdometer") as string;
  if (endOdometer) body.endOdometer = parseInt(endOdometer, 10);

  await backendFetch(`/trips/${tripId}/end`, {
    method: "POST",
    body: JSON.stringify(body),
  });

  revalidatePath("/trips");
}

export async function discardTripAction(tripId: string) {
  await backendFetch(`/trips/${tripId}/discard`, { method: "POST" });
  revalidatePath("/trips");
}
