"use server";

import { revalidatePath } from "next/cache";
import { backendFetch } from "../lib/auth";

export async function createVehicleAction(formData: FormData) {
  const body: Record<string, unknown> = {
    make: formData.get("make") as string,
    model: formData.get("model") as string,
  };

  const year = formData.get("year") as string;
  if (year) body.year = parseInt(year, 10);

  const licensePlate = formData.get("licensePlate") as string;
  if (licensePlate) body.licensePlate = licensePlate;

  const category = formData.get("category") as string;
  if (category) body.category = category;

  const protocolSupport = formData.get("protocolSupport") as string;
  if (protocolSupport) body.protocolSupport = protocolSupport;

  const notes = formData.get("notes") as string;
  if (notes) body.notes = notes;

  await backendFetch("/vehicles", {
    method: "POST",
    body: JSON.stringify(body),
  });

  revalidatePath("/vehicles");
}

export async function deactivateVehicleAction(vehicleId: string) {
  await backendFetch(`/vehicles/${vehicleId}`, { method: "DELETE" });
  revalidatePath("/vehicles");
}
