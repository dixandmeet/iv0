"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { LandingMapView } from "./landing-map-view";
import type { Vehicle3DLayer } from "@/components/carte-immersive/vehicle-3d-layer";
import { pathLen, pointAt, type LatLng } from "@/lib/carte-immersive/geo";
import type { MapVehicle } from "@/lib/carte-immersive/vehicles";
import {
  BABINIERE_STOP,
  boundsFromCoordinates,
  NANTES_BUS_ROUTE,
  NANTES_CENTER,
  NANTES_LIGNE00_ROUTE,
  NANTES_TRAM_ROUTE,
  NANTES_WALK_ROUTE,
  sliceLineRoute,
  type MapBounds,
} from "@/lib/landing-map-style";
import styles from "./scrolly-landing.module.css";

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

  const linePath = useMemo(() => routeToPath(NANTES_LIGNE00_ROUTE), []);

  const routes = useMemo(
    () => [
      {
        id: "section-ligne00-route",
        data: NANTES_LIGNE00_ROUTE,
        color: "#33BFA3",
        width: 6,
      },
    ],
    [],
  );

  const modelVehicles = useMemo<MapVehicle[]>(
    () => [
      {
        id: "section-bus",
        type: "bus",
        mode: "preview",
        lng: BABINIERE_STOP[0],
        lat: BABINIERE_STOP[1],
        heading: 90,
        speedMps: 6,
        recordedAt: new Date().toISOString(),
        routeId: "00",
        destination: "Ranzay",
      },
      {
        id: "section-tram",
        type: "tram",
        mode: "preview",
        lng: BABINIERE_STOP[0],
        lat: BABINIERE_STOP[1],
        heading: 90,
        speedMps: 8,
        recordedAt: new Date().toISOString(),
        routeId: "00",
        destination: "Babinière",
      },
    ],
    [],
  );

  const markers = useMemo(
    () => [
      {
        id: "relais-babiniere",
        lng: -1.5462,
        lat: 47.2596,
        label: "Relais P+R Babinière",
        status: "pilot" as const,
        badge: "Café",
      },
      {
        id: "cafe-erdre",
        lng: -1.5388,
        lat: 47.2566,
        label: "Café de l'Erdre",
        status: "pilot" as const,
      },
      {
        id: "superette-ranzay",
        lng: -1.5303,
        lat: 47.254,
        label: "Supérette Ranzay",
        status: "pilot" as const,
        badge: "Ouvert",
      },
      {
        id: "boulangerie-haluchere",
        lng: -1.5229,
        lat: 47.2493,
        label: "Boulangerie Haluchère",
        status: "coming" as const,
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
        "section-bus",
        linePath,
        now,
        0.00064,
        0,
        previewAnglesRef.current,
      );
      animatePreviewAlongPath(
        layer,
        "section-tram",
        linePath,
        now,
        0.00058,
        0.0445,
        previewAnglesRef.current,
      );
      rafRef.current = requestAnimationFrame(tick);
    };

    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [vehicleLayerReady, linePath]);

  return (
    <div data-par="1.3" className={styles.environmentMapPanel}>
      <LandingMapView
        center={[-1.5338, 47.2582]}
        zoom={14.6}
        bearing={-24}
        pitch={60}
        interactive={false}
        eager
        threeD
        scrollZoom={false}
        routes={routes}
        modelVehicles={modelVehicles}
        markers={markers}
        onVehicleLayerReady={handleVehicleLayerReady}
        className={className ?? styles.environmentMapCanvas}
        ariaLabel="Carte 3D de la ligne 00 Babinière ↔ Ranzay, avec véhicules en circulation et commerces à proximité"
      />
      <div className={styles.environmentMapVeil} aria-hidden="true" />
      <div className={styles.environmentMapDeparture}>Ligne 00 · Babinière → Ranzay</div>
      <div className={styles.environmentMapLegend}>
        <span className={styles.environmentMapLegendItem}>
          <i className={styles.environmentMapLegendDotTram} aria-hidden="true" />
          Ligne 00
        </span>
        <span className={styles.environmentMapLegendItem}>
          <i className={styles.environmentMapLegendDotBus} aria-hidden="true" />
          Véhicules
        </span>
        <span className={styles.environmentMapLegendItem}>
          <i className={styles.environmentMapLegendDotShop} aria-hidden="true" />
          Commerces
        </span>
      </div>
    </div>
  );
}

export function HeroInteractiveMap({
  className,
  focusLocation,
  userLocation,
}: {
  className?: string;
  focusLocation?: UserLocation;
  userLocation?: UserLocation;
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
