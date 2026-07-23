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

function normalizeTransitLabel(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function destinationMatches(actual: string | null | undefined, expected: string): boolean {
  const normalizedActual = normalizeTransitLabel(actual ?? "");
  const aliases = expected
    .split(/[/|]/)
    .map(normalizeTransitLabel)
    .filter((value) => value.length >= 3);
  if (!normalizedActual) return false;
  return aliases.some(
    (alias) => normalizedActual.includes(alias) || alias.includes(normalizedActual),
  );
}

function vehicleDistanceMeters(
  vehicle: MapVehicle,
  target: { lat: number; lng: number },
): number {
  const radians = Math.PI / 180;
  const latitudeDelta = (target.lat - vehicle.lat) * radians;
  const longitudeDelta = (target.lng - vehicle.lng) * radians;
  const a =
    Math.sin(latitudeDelta / 2) ** 2
    + Math.cos(vehicle.lat * radians)
      * Math.cos(target.lat * radians)
      * Math.sin(longitudeDelta / 2) ** 2;
  return 6_371_000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function selectLiveVehicleForSchedule(
  vehicles: MapVehicle[],
  selection: {
    line: string;
    routeId: string;
    direction: string;
    estimatedPosition: { lat: number; lng: number };
  },
  maxDistanceMeters = 5_000,
): MapVehicle | null {
  const expectedRoutes = new Set(
    [selection.line, selection.routeId].map(normalizeTransitLabel).filter(Boolean),
  );
  const onRoute = vehicles.filter(
    (vehicle) =>
      vehicle.mode === "live"
      && expectedRoutes.has(normalizeTransitLabel(vehicle.routeId ?? "")),
  );
  const matchingDirection = onRoute.filter((vehicle) =>
    destinationMatches(vehicle.destination, selection.direction),
  );
  // Ne jamais substituer un véhicule de l'autre sens lorsque le terminus
  // attendu est connu. Sans correspondance fiable, le suivi GTFS théorique de
  // la course exacte est préférable à une position temps réel erronée.
  if (selection.direction.trim() && matchingDirection.length === 0) return null;
  const candidates = matchingDirection.length > 0 ? matchingDirection : onRoute;
  const closest = candidates
    .map((vehicle) => ({
      vehicle,
      distance: vehicleDistanceMeters(vehicle, selection.estimatedPosition),
    }))
    .sort((a, b) => a.distance - b.distance)[0];
  return closest && closest.distance <= maxDistanceMeters ? closest.vehicle : null;
}
