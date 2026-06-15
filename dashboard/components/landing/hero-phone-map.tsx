"use client";

import { useMemo } from "react";
import { LandingMapView } from "./landing-map-view";
import {
  boundsFromCoordinates,
  NANTES_BUS_ROUTE,
  NANTES_CENTER,
  NANTES_TRAM_ROUTE,
  NANTES_WALK_ROUTE,
  sliceLineRoute,
  type MapBounds,
} from "@/lib/landing-map-style";

export function HeroPhoneMap({ className }: { className?: string }) {
  const routes = useMemo(
    () => [
      {
        id: "tram-route",
        data: NANTES_TRAM_ROUTE,
        color: "#1B66F5",
        width: 6,
      },
      {
        id: "walk-route",
        data: NANTES_WALK_ROUTE,
        color: "#94A3B8",
        width: 3,
        dashed: true,
        glow: false,
      },
    ],
    [],
  );

  const vehicles = useMemo(
    () => [
      {
        id: "tram-1",
        lng: -1.5486,
        lat: 47.2258,
        color: "#22C55E",
        label: "Tram 1",
        pulse: true,
      },
      {
        id: "bus-c4",
        lng: -1.5358,
        lat: 47.2466,
        color: "#8B5CF6",
        label: "Bus C4",
        pulse: true,
      },
    ],
    [],
  );

  return (
    <LandingMapView
      center={[-1.552, 47.222]}
      zoom={14}
      bearing={-12}
      pitch={28}
      interactive={false}
      eager
      routes={routes}
      vehicles={vehicles}
      showUserLocation={{ lng: -1.5674, lat: 47.2052 }}
      className={className}
      ariaLabel="Carte de Nantes avec itinéraire tramway et véhicules en temps réel"
    />
  );
}

type ScreenMapVariant =
  | "guidage"
  | "notifications"
  | "suivi"
  | "descente"
  | "correspondance";

const TRAM_TO_COMMERCE = sliceLineRoute(NANTES_TRAM_ROUTE, 0, 7);
const TRAM_MID = sliceLineRoute(NANTES_TRAM_ROUTE, 4, 13);
const TRAM_TO_GARE_NORD = sliceLineRoute(NANTES_TRAM_ROUTE, 10);

const SCREEN_MAP_CONFIGS: Record<
  ScreenMapVariant,
  {
    bearing: number;
    pitch: number;
    bounds: MapBounds;
    fitPadding: number;
    routes: Array<{
      id: string;
      data: GeoJSON.Feature<GeoJSON.LineString>;
      color: string;
      width?: number;
      dashed?: boolean;
      glow?: boolean;
    }>;
    vehicles: Array<{
      id: string;
      lng: number;
      lat: number;
      color: string;
      label: string;
      pulse?: boolean;
    }>;
    showUserLocation?: { lng: number; lat: number };
  }
> = {
  guidage: {
    bearing: -12,
    pitch: 0,
    bounds: boundsFromCoordinates([
      ...NANTES_WALK_ROUTE.geometry.coordinates,
      ...TRAM_TO_COMMERCE.geometry.coordinates,
      [-1.5674, 47.2052],
    ] as Array<[number, number]>),
    fitPadding: 36,
    routes: [
      {
        id: "walk-route",
        data: NANTES_WALK_ROUTE,
        color: "#94A3B8",
        width: 4,
        dashed: true,
        glow: false,
      },
      {
        id: "tram-route",
        data: TRAM_TO_COMMERCE,
        color: "#1B66F5",
        width: 6,
      },
    ],
    vehicles: [],
    showUserLocation: { lng: -1.5674, lat: 47.2052 },
  },
  notifications: {
    bearing: -8,
    pitch: 0,
    bounds: boundsFromCoordinates([
      ...TRAM_TO_COMMERCE.geometry.coordinates,
      [-1.5608, 47.2134],
      [-1.557, 47.2169],
    ] as Array<[number, number]>),
    fitPadding: 40,
    routes: [
      {
        id: "tram-route",
        data: TRAM_TO_COMMERCE,
        color: "#22C55E",
        width: 6,
      },
    ],
    vehicles: [
      {
        id: "tram-approaching",
        lng: -1.557,
        lat: 47.2169,
        color: "#22C55E",
        label: "Tram 1",
        pulse: true,
      },
    ],
    showUserLocation: { lng: -1.5608, lat: 47.2134 },
  },
  suivi: {
    bearing: -6,
    pitch: 0,
    bounds: boundsFromCoordinates([
      ...TRAM_MID.geometry.coordinates,
      [-1.5498, 47.2243],
    ] as Array<[number, number]>),
    fitPadding: 36,
    routes: [
      {
        id: "tram-route",
        data: TRAM_MID,
        color: "#1B66F5",
        width: 6,
      },
    ],
    vehicles: [
      {
        id: "tram-live",
        lng: -1.5498,
        lat: 47.2243,
        color: "#F59E0B",
        label: "Tram 1",
        pulse: true,
      },
    ],
  },
  descente: {
    bearing: -4,
    pitch: 0,
    bounds: boundsFromCoordinates([
      ...TRAM_TO_GARE_NORD.geometry.coordinates,
      [-1.5378, 47.2438],
    ] as Array<[number, number]>),
    fitPadding: 40,
    routes: [
      {
        id: "tram-route",
        data: TRAM_TO_GARE_NORD,
        color: "#EF4444",
        width: 6,
      },
    ],
    vehicles: [
      {
        id: "tram-stop",
        lng: -1.5378,
        lat: 47.2438,
        color: "#EF4444",
        label: "Gare Nord",
        pulse: true,
      },
    ],
  },
  correspondance: {
    bearing: -10,
    pitch: 0,
    bounds: boundsFromCoordinates([
      ...sliceLineRoute(NANTES_TRAM_ROUTE, 14).geometry.coordinates,
      ...NANTES_BUS_ROUTE.geometry.coordinates,
      [-1.5378, 47.2438],
      [-1.5338, 47.2494],
    ] as Array<[number, number]>),
    fitPadding: 36,
    routes: [
      {
        id: "tram-route",
        data: sliceLineRoute(NANTES_TRAM_ROUTE, 12, 18),
        color: "#1B66F5",
        width: 5,
      },
      {
        id: "bus-route",
        data: NANTES_BUS_ROUTE,
        color: "#8B5CF6",
        width: 5,
      },
    ],
    vehicles: [
      {
        id: "bus-transfer",
        lng: -1.5338,
        lat: 47.2494,
        color: "#8B5CF6",
        label: "Bus C4",
        pulse: true,
      },
    ],
    showUserLocation: { lng: -1.5378, lat: 47.2438 },
  },
};

export function ScreenMap({
  variant = "guidage",
  className,
}: {
  variant?: string;
  className?: string;
}) {
  const config =
    SCREEN_MAP_CONFIGS[variant as ScreenMapVariant] ??
    SCREEN_MAP_CONFIGS.guidage;

  const routes = useMemo(() => config.routes, [variant]);
  const vehicles = useMemo(() => config.vehicles, [variant]);
  const bounds = useMemo(() => config.bounds, [variant]);

  return (
    <LandingMapView
      center={NANTES_CENTER}
      zoom={14}
      bearing={config.bearing}
      pitch={config.pitch}
      bounds={bounds}
      fitPadding={config.fitPadding}
      interactive={false}
      eager
      routes={routes}
      vehicles={vehicles}
      showUserLocation={config.showUserLocation}
      className={className}
      ariaLabel={`Aperçu carte — ${variant}`}
    />
  );
}

export { NANTES_CENTER };
