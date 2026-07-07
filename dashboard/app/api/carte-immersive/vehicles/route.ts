import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import {
  isTransitVehicleType,
  normalizeHeading,
  type ImmersiveFleetResponse,
  type MapVehicle,
} from "@/lib/carte-immersive/vehicles";

type PublicFleetRow = {
  public_id?: unknown;
  vehicle_type?: unknown;
  route_id?: unknown;
  destination?: unknown;
  latitude?: unknown;
  longitude?: unknown;
  speed?: unknown;
  heading?: unknown;
  recorded_at?: unknown;
};

function finiteNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

function toVehicle(row: PublicFleetRow): MapVehicle | null {
  if (typeof row.public_id !== "string" || !isTransitVehicleType(row.vehicle_type)) {
    return null;
  }

  const lat = finiteNumber(row.latitude);
  const lng = finiteNumber(row.longitude);
  if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return null;
  }

  const speed = finiteNumber(row.speed);
  const heading = finiteNumber(row.heading);
  return {
    id: `live-${row.public_id}`,
    type: row.vehicle_type,
    mode: "live",
    lat,
    lng,
    heading: normalizeHeading(heading ?? 0),
    speedMps: speed != null && speed >= 0 ? speed : null,
    recordedAt: typeof row.recorded_at === "string" ? row.recorded_at : null,
    routeId: typeof row.route_id === "string" ? row.route_id : "",
    destination: typeof row.destination === "string" ? row.destination : null,
  };
}

export async function GET() {
  try {
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("immersive_fleet_positions", {
      p_max_age_seconds: 120,
    });

    if (error) {
      return NextResponse.json(
        { error: "live_fleet_unavailable" },
        { status: 503, headers: { "Cache-Control": "no-store" } },
      );
    }

    const vehicles = ((data ?? []) as PublicFleetRow[])
      .map(toVehicle)
      .filter((vehicle): vehicle is MapVehicle => vehicle !== null);
    const payload: ImmersiveFleetResponse = {
      vehicles,
      generatedAt: new Date().toISOString(),
    };

    return NextResponse.json(payload, {
      headers: { "Cache-Control": "no-store, max-age=0" },
    });
  } catch {
    return NextResponse.json(
      { error: "live_fleet_unavailable" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
}
