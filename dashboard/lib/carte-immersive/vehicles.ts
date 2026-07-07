import type { VehicleDef, VehicleType } from "./data";

export type VehicleFeedMode = "live" | "preview";

export type MapVehicle = {
  id: string;
  type: VehicleType;
  mode: VehicleFeedMode;
  lat: number;
  lng: number;
  heading: number;
  speedMps: number | null;
  recordedAt: string | null;
  routeId?: string;
  destination?: string | null;
  preview?: VehicleDef;
};

export type ImmersiveFleetResponse = {
  vehicles: MapVehicle[];
  generatedAt: string;
};

export function isTransitVehicleType(value: unknown): value is "bus" | "tram" {
  return value === "bus" || value === "tram";
}

export function normalizeHeading(value: number): number {
  return ((value % 360) + 360) % 360;
}

export function shortestHeadingDelta(from: number, to: number): number {
  return ((to - from + 540) % 360) - 180;
}
