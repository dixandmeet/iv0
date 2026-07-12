"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { LandingMapView } from "./landing-map-view";
import type { Vehicle3DLayer } from "@/components/carte-immersive/vehicle-3d-layer";
import { pathLen, pointAt, type LatLng } from "@/lib/carte-immersive/geo";
import type { MapVehicle } from "@/lib/carte-immersive/vehicles";
import {
  boundsFromCoordinates,
  NANTES_BUS_ROUTE,
  NANTES_CENTER,
  NANTES_TRAM_ROUTE,
  NANTES_WALK_ROUTE,
  sliceLineRoute,
  type MapBounds,
} from "@/lib/landing-map-style";
import styles from "./scrolly-landing.module.css";
import type { HeroWeather } from "./use-hero-weather";

function routeToPath(route: GeoJSON.Feature<GeoJSON.LineString>): LatLng[] {
  return route.geometry.coordinates.map(([lng, lat]) => [lat, lng]);
}

function animatePreviewAlongPath(
  layer: Vehicle3DLayer,
  id: string,
  path: LatLng[],
  now: number,
  speed: number,
  phase: number,
  angles: Map<string, number>,
) {
  const total = pathLen(path);
  if (total === 0) return;

  const cycle = 2 * total;
  let distance = (((now * speed + phase) % cycle) + cycle) % cycle;
  let reverse = false;
  if (distance > total) {
    distance = cycle - distance;
    reverse = true;
  }

  const point = pointAt(path, distance);
  const direction = reverse ? -1 : 1;
  const epsilon = Math.max(0.00035, total * 0.03);
  const ahead = pointAt(path, Math.max(0, Math.min(total, distance + direction * epsilon)));
  const behind = pointAt(path, Math.max(0, Math.min(total, distance - direction * epsilon)));
  const east = (ahead.lng - behind.lng) * Math.cos((point.lat * Math.PI) / 180);
  const north = ahead.lat - behind.lat;
  let heading = (Math.atan2(east, north) * 180) / Math.PI;
  const previous = angles.get(id);
  if (previous != null) {
    const delta = ((heading - previous + 540) % 360) - 180;
    heading = previous + delta * 0.25;
  }
  angles.set(id, heading);
  layer.setPreviewPose(id, point.lat, point.lng, heading);
}

type UserLocation = { lng: number; lat: number };

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
      zoom={15.2}
      bearing={-22}
      pitch={58}
      interactive={false}
      eager
      threeD
      routes={routes}
      vehicles={vehicles}
      showUserLocation={{ lng: -1.5674, lat: 47.2052 }}
      className={className}
      ariaLabel="Carte de Nantes avec itinéraire tramway et véhicules en temps réel"
    />
  );
}

export function EnvironmentSectionMap({ className }: { className?: string }) {
  const vehicleLayerRef = useRef<Vehicle3DLayer | null>(null);
  const previewAnglesRef = useRef(new Map<string, number>());
  const rafRef = useRef(0);
  const [vehicleLayerReady, setVehicleLayerReady] = useState(false);

  const commerceLine1 = useMemo<GeoJSON.Feature<GeoJSON.LineString>>(
    () => ({
      type: "Feature",
      properties: { name: "Tram 1 · Commerce" },
      geometry: {
        type: "LineString",
        coordinates: [
          [-1.5638, 47.2119],
          [-1.5609, 47.2131],
          [-1.5582, 47.2137],
          [-1.5557, 47.214],
          [-1.5533, 47.2144],
          [-1.5508, 47.215],
        ],
      },
    }),
    [],
  );

  const commerceLines23 = useMemo<GeoJSON.Feature<GeoJSON.LineString>>(
    () => ({
      type: "Feature",
      properties: { name: "Trams 2 et 3 · Commerce" },
      geometry: {
        type: "LineString",
        coordinates: [
          [-1.5582, 47.2201],
          [-1.5574, 47.2179],
          [-1.5565, 47.2159],
          [-1.5558, 47.2143],
          [-1.5551, 47.2128],
          [-1.5545, 47.2107],
        ],
      },
    }),
    [],
  );

  const commerceLine3 = useMemo<GeoJSON.Feature<GeoJSON.LineString>>(
    () => ({
      ...commerceLines23,
      properties: { name: "Tram 3 · Commerce" },
      geometry: {
        ...commerceLines23.geometry,
        coordinates: commerceLines23.geometry.coordinates.map(([lng, lat]) => [
          lng + 0.00012,
          lat - 0.00002,
        ]),
      },
    }),
    [commerceLines23],
  );

  const line1Path = useMemo(() => routeToPath(commerceLine1), [commerceLine1]);
  const lines23Path = useMemo(() => routeToPath(commerceLines23), [commerceLines23]);

  const routes = useMemo(
    () => [
      {
        id: "section-commerce-line-1",
        data: commerceLine1,
        color: "#36D6B5",
        width: 4.5,
      },
      {
        id: "section-commerce-line-2",
        data: commerceLines23,
        color: "#FF6B7D",
        width: 4,
      },
      {
        id: "section-commerce-line-3",
        data: commerceLine3,
        color: "#6C9CFF",
        width: 4,
      },
    ],
    [commerceLine1, commerceLine3, commerceLines23],
  );

  const zones = useMemo(
    () => [
      {
        id: "section-commerce-zone",
        color: "#8DEEDD",
        fillOpacity: 0.12,
        data: {
          type: "Feature" as const,
          properties: { name: "Pôle d'échanges Commerce" },
          geometry: {
            type: "Polygon" as const,
            coordinates: [[
              [-1.5588, 47.2158],
              [-1.5568, 47.2165],
              [-1.5538, 47.2152],
              [-1.5536, 47.2125],
              [-1.5562, 47.2118],
              [-1.559, 47.2131],
              [-1.5588, 47.2158],
            ]],
          },
        },
      },
    ],
    [],
  );

  const modelVehicles = useMemo<MapVehicle[]>(
    () => [
      {
        id: "section-tram-1",
        type: "tram",
        mode: "preview",
        lng: -1.5609,
        lat: 47.2131,
        heading: 90,
        speedMps: 8,
        recordedAt: new Date().toISOString(),
        routeId: "1",
        destination: "Beaujoire",
      },
      {
        id: "section-tram-2",
        type: "tram",
        mode: "preview",
        lng: -1.5574,
        lat: 47.2179,
        heading: 165,
        speedMps: 8,
        recordedAt: new Date().toISOString(),
        routeId: "2",
        destination: "Gare de Pont-Rousseau",
      },
    ],
    [],
  );

  const markers = useMemo(
    () => [
      {
        id: "commerce-line-1-stop",
        lng: -1.5553,
        lat: 47.21385,
        label: "Commerce · Ligne 1",
        status: "pilot" as const,
        badge: "L1",
        accent: "#36D6B5",
        offset: [62, 22] as [number, number],
        variant: "stop" as const,
      },
      {
        id: "commerce-lines-2-3-stop",
        lng: -1.55615,
        lat: 47.21455,
        label: "Commerce · Lignes 2 & 3",
        status: "pilot" as const,
        badge: "L2 · L3",
        accent: "#FF7184",
        offset: [-68, -28] as [number, number],
        variant: "stop" as const,
      },
    ],
    [],
  );

  const handleVehicleLayerReady = useCallback((layer: Vehicle3DLayer) => {
    vehicleLayerRef.current = layer;
    setVehicleLayerReady(true);
  }, []);

  useEffect(() => {
    if (!vehicleLayerReady || !vehicleLayerRef.current) return;

    const layer = vehicleLayerRef.current;
    const tick = () => {
      const now = performance.now() / 1000;
      animatePreviewAlongPath(
        layer,
        "section-tram-1",
        line1Path,
        now,
        0.00064,
        0,
        previewAnglesRef.current,
      );
      animatePreviewAlongPath(
        layer,
        "section-tram-2",
        lines23Path,
        now,
        0.00058,
        0.0445,
        previewAnglesRef.current,
      );
      rafRef.current = requestAnimationFrame(tick);
    };

    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [vehicleLayerReady, line1Path, lines23Path]);

  return (
    <div data-par="1.3" className={styles.environmentMapPanel}>
      <LandingMapView
        center={[-1.5557, 47.2141]}
        zoom={15.9}
        bearing={-14}
        pitch={48}
        interactive={false}
        eager
        threeD
        scrollZoom={false}
        routes={routes}
        zones={zones}
        modelVehicles={modelVehicles}
        markers={markers}
        onVehicleLayerReady={handleVehicleLayerReady}
        className={className ?? styles.environmentMapCanvas}
        ariaLabel="Carte 3D du pôle d'échanges Commerce au centre-ville de Nantes, avec les arrêts des lignes 1, 2 et 3"
      />
      <div className={styles.environmentMapVeil} aria-hidden="true" />
      <div className={styles.environmentMapDeparture}>
        <span className={styles.environmentMapDepartureIcon} aria-hidden="true">
          <i />
        </span>
        <span className={styles.environmentMapDepartureCopy}>
          <small>Pôle d&apos;échanges</small>
          <strong>Commerce · Nantes Centre</strong>
        </span>
        <span className={styles.environmentMapDepartureStatus}>3 lignes</span>
      </div>
      <div className={styles.environmentMapLegend}>
        <span className={styles.environmentMapLegendLabel}>Réseau</span>
        <span className={styles.environmentMapLegendItem}>
          <i className={styles.environmentMapLine1} aria-hidden="true">1</i>
          Est ↔ Ouest
        </span>
        <span className={styles.environmentMapLegendItem}>
          <i className={styles.environmentMapLine2} aria-hidden="true">2</i>
          <i className={styles.environmentMapLine3} aria-hidden="true">3</i>
          Nord ↔ Sud
        </span>
      </div>
    </div>
  );
}

export function HeroInteractiveMap({
  className,
  focusLocation,
  userLocation,
  weather,
}: {
  className?: string;
  focusLocation?: UserLocation;
  userLocation?: UserLocation;
  weather?: HeroWeather;
}) {
  const routes = useMemo(
    () => [
      {
        id: "hero-tram-route",
        data: NANTES_TRAM_ROUTE,
        color: "#33BFA3",
        width: 7,
      },
      {
        id: "hero-bus-route",
        data: NANTES_BUS_ROUTE,
        color: "#7C93F0",
        width: 5,
      },
      {
        id: "hero-walk-route",
        data: NANTES_WALK_ROUTE,
        color: "#D7DEE8",
        width: 3,
        dashed: true,
        glow: false,
      },
    ],
    [],
  );

  const modelVehicles = useMemo<MapVehicle[]>(
    () => [
      {
        id: "hero-tram-live",
        type: "tram",
        mode: "preview",
        lng: -1.5498,
        lat: 47.2243,
        heading: 36,
        speedMps: 8,
        recordedAt: new Date().toISOString(),
        routeId: "T3",
        destination: "Hôtel de Ville",
      },
      {
        id: "hero-bus-live",
        type: "bus",
        mode: "preview",
        lng: -1.5358,
        lat: 47.2466,
        heading: 28,
        speedMps: 6,
        recordedAt: new Date().toISOString(),
        routeId: "C4",
        destination: "Gare Nord",
      },
      {
        id: "hero-taxi-live",
        type: "taxi",
        mode: "preview",
        lng: -1.5581,
        lat: 47.2159,
        heading: 52,
        speedMps: 7,
        recordedAt: new Date().toISOString(),
        destination: "Commerce",
      },
    ],
    [],
  );

  const markers = useMemo(
    () => [
      {
        id: "commerce",
        lng: -1.5608,
        lat: 47.2134,
        label: "Commerce",
        status: "pilot" as const,
        badge: "Quai",
      },
      {
        id: "gare",
        lng: -1.5378,
        lat: 47.2438,
        label: "Gare Nord",
        status: "pilot" as const,
      },
      {
        id: "delivery",
        lng: -1.5522,
        lat: 47.2216,
        label: "Commande prête",
        status: "coming" as const,
      },
    ],
    [],
  );

  const activeCenter = focusLocation ?? userLocation;

  return (
    <LandingMapView
      center={activeCenter ? [activeCenter.lng, activeCenter.lat] : [-1.5505, 47.2258]}
      zoom={activeCenter ? 17.2 : 16.8}
      bearing={-24}
      pitch={62}
      interactive
      eager
      threeD
      scrollZoom={false}
      showControls
      routes={routes}
      modelVehicles={modelVehicles}
      markers={markers}
      showUserLocation={userLocation}
      className={className}
      ariaLabel="Carte 3D interactive de Nantes avec véhicules, itinéraires et services Aule"
      atmosphere={weather ? { period: weather.period, condition: weather.condition } : undefined}
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
    bearing: -18,
    pitch: 56,
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
    bearing: -18,
    pitch: 56,
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
    bearing: -16,
    pitch: 56,
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
    bearing: -14,
    pitch: 56,
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
    bearing: -18,
    pitch: 56,
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

  return (
    <LandingMapView
      center={NANTES_CENTER}
      zoom={14}
      bearing={config.bearing}
      pitch={config.pitch}
      bounds={config.bounds}
      fitPadding={config.fitPadding}
      interactive={false}
      eager
      threeD
      routes={config.routes}
      vehicles={config.vehicles}
      showUserLocation={config.showUserLocation}
      className={className}
      ariaLabel={`Aperçu carte — ${variant}`}
    />
  );
}

export { NANTES_CENTER };
