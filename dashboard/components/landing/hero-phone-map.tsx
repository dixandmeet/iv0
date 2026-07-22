"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { LandingMapView } from "./landing-map-view";
import type { Vehicle3DLayer } from "@/components/carte-immersive/vehicle-3d-layer";
import { distanceMeters, type LatLng } from "@/lib/carte-immersive/geo";
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

function metricPathLength(path: LatLng[]) {
  let total = 0;
  for (let index = 1; index < path.length; index += 1) {
    total += distanceMeters(path[index - 1], path[index]);
  }
  return total;
}

function pointAlongMetricPath(path: LatLng[], distance: number) {
  let remaining = distance;
  for (let index = 1; index < path.length; index += 1) {
    const from = path[index - 1];
    const to = path[index];
    const segmentLength = distanceMeters(from, to);
    if (remaining <= segmentLength || index === path.length - 1) {
      const progress = segmentLength === 0 ? 0 : Math.min(1, remaining / segmentLength);
      return {
        lat: from[0] + (to[0] - from[0]) * progress,
        lng: from[1] + (to[1] - from[1]) * progress,
      };
    }
    remaining -= segmentLength;
  }

  const [lat, lng] = path[path.length - 1];
  return { lat, lng };
}

function animatePreviewAlongPath(
  layer: Vehicle3DLayer,
  id: string,
  path: LatLng[],
  now: number,
  speedMetersPerSecond: number,
  phaseSeconds: number,
  direction: 1 | -1,
  stopFraction: number,
  dwellSeconds: number,
  angles: Map<string, number>,
) {
  const total = metricPathLength(path);
  if (total === 0) return;

  const travelSeconds = total / speedMetersPerSecond;
  const journeyStopFraction = direction === 1 ? stopFraction : 1 - stopFraction;
  const stopAt = travelSeconds * journeyStopFraction;
  const cycleSeconds = travelSeconds + dwellSeconds;
  const cycleTime = (((now + phaseSeconds) % cycleSeconds) + cycleSeconds) % cycleSeconds;
  const journeyTime =
    cycleTime <= stopAt
      ? cycleTime
      : cycleTime <= stopAt + dwellSeconds
        ? stopAt
        : cycleTime - dwellSeconds;
  const journeyDistance = Math.min(total, journeyTime * speedMetersPerSecond);
  const distance = direction === 1 ? journeyDistance : total - journeyDistance;

  const point = pointAlongMetricPath(path, distance);
  const epsilon = Math.max(5, total * 0.012);
  const ahead = pointAlongMetricPath(
    path,
    Math.max(0, Math.min(total, distance + direction * epsilon)),
  );
  const behind = pointAlongMetricPath(
    path,
    Math.max(0, Math.min(total, distance - direction * epsilon)),
  );
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
  const panelRef = useRef<HTMLDivElement | null>(null);
  const vehicleLayerRef = useRef<Vehicle3DLayer | null>(null);
  const previewAnglesRef = useRef(new Map<string, number>());
  const animationEpochRef = useRef<number | null>(null);
  const rafRef = useRef(0);
  const [vehicleLayerReady, setVehicleLayerReady] = useState(false);
  const [animationActive, setAnimationActive] = useState(true);
  const [updatedAt, setUpdatedAt] = useState("--:--:--");

  const commerceLine1 = useMemo<GeoJSON.Feature<GeoJSON.LineString>>(
    () => ({
      type: "Feature",
      properties: { name: "Tram 1 · Commerce" },
      geometry: {
        type: "LineString",
        coordinates: [
          [-1.54755, 47.21618],
          [-1.54804, 47.21592],
          [-1.54853, 47.21567],
          [-1.5489, 47.21553],
          [-1.54927, 47.21539],
          [-1.5499, 47.21521],
          [-1.55052, 47.21504],
          [-1.55114, 47.21486],
          [-1.5518, 47.21471],
          [-1.55247, 47.21457],
          [-1.55313, 47.21443],
          [-1.55379, 47.21428],
          [-1.55445, 47.21414],
          [-1.55499, 47.21397],
          [-1.55553, 47.2138],
          [-1.55605, 47.21359],
          [-1.55657, 47.21337],
          [-1.55709, 47.21316],
          [-1.55761, 47.21294],
          [-1.558, 47.21267],
          [-1.55839, 47.2124],
          [-1.55878, 47.21212],
          [-1.55922, 47.21188],
          [-1.55965, 47.21164],
          [-1.5602, 47.21143],
          [-1.56074, 47.21121],
          [-1.56129, 47.21099],
          [-1.56184, 47.21078],
          [-1.56238, 47.21056],
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
          [-1.55591, 47.21991],
          [-1.55633, 47.21958],
          [-1.55676, 47.21926],
          [-1.55718, 47.21894],
          [-1.55737, 47.21859],
          [-1.55741, 47.21829],
          [-1.55745, 47.218],
          [-1.55735, 47.21754],
          [-1.55716, 47.2171],
          [-1.55698, 47.21667],
          [-1.55679, 47.21623],
          [-1.5566, 47.21579],
          [-1.55642, 47.21535],
          [-1.55623, 47.21491],
          [-1.55589, 47.21452],
          [-1.55555, 47.21413],
          [-1.5552, 47.21374],
          [-1.55486, 47.21335],
          [-1.55452, 47.21296],
          [-1.55417, 47.21257],
          [-1.55375, 47.2122],
          [-1.55333, 47.21183],
          [-1.55291, 47.21146],
          [-1.55249, 47.21108],
          [-1.55208, 47.21071],
          [-1.55166, 47.21034],
          [-1.55124, 47.20996],
          [-1.55082, 47.20959],
          [-1.5504, 47.20922],
        ],
      },
    }),
    [],
  );

  const commerceLine3 = useMemo<GeoJSON.Feature<GeoJSON.LineString>>(
    () => ({
      type: "Feature",
      properties: { name: "Tram 3 · Commerce" },
      geometry: {
        type: "LineString",
        coordinates: [
          [-1.56097, 47.21896],
          [-1.56051, 47.21864],
          [-1.56004, 47.21832],
          [-1.55958, 47.218],
          [-1.55911, 47.21768],
          [-1.55865, 47.21736],
          [-1.55818, 47.21704],
          [-1.55771, 47.21672],
          [-1.55725, 47.2164],
          [-1.55678, 47.21608],
          [-1.5566, 47.21569],
          [-1.55642, 47.2153],
          [-1.55623, 47.21491],
          [-1.55591, 47.21454],
          [-1.55558, 47.21417],
          [-1.55526, 47.2138],
          [-1.55493, 47.21343],
          [-1.55461, 47.21306],
          [-1.55428, 47.21269],
          [-1.55385, 47.2123],
          [-1.55343, 47.21192],
          [-1.553, 47.21154],
          [-1.55257, 47.21116],
          [-1.55214, 47.21077],
          [-1.55171, 47.21039],
          [-1.55128, 47.21001],
          [-1.55085, 47.20963],
          [-1.55042, 47.20924],
          [-1.55, 47.20886],
        ],
      },
    }),
    [],
  );

  const line1Path = useMemo(() => routeToPath(commerceLine1), [commerceLine1]);
  const lines23Path = useMemo(() => routeToPath(commerceLines23), [commerceLines23]);
  const line3Path = useMemo(() => routeToPath(commerceLine3), [commerceLine3]);

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
        id: "section-tram-1-east",
        type: "tram",
        mode: "preview",
        lng: -1.55605,
        lat: 47.21359,
        heading: 90,
        speedMps: 8,
        recordedAt: new Date().toISOString(),
        routeId: "1",
        destination: "Beaujoire",
      },
      {
        id: "section-tram-1-west",
        type: "tram",
        mode: "preview",
        lng: -1.55313,
        lat: 47.21443,
        heading: 270,
        speedMps: 8,
        recordedAt: new Date().toISOString(),
        routeId: "1",
        destination: "François Mitterrand",
      },
      {
        id: "section-tram-2-south",
        type: "tram",
        mode: "preview",
        lng: -1.55716,
        lat: 47.2171,
        heading: 165,
        speedMps: 8,
        recordedAt: new Date().toISOString(),
        routeId: "2",
        destination: "Gare de Pont-Rousseau",
      },
      {
        id: "section-tram-3-north",
        type: "tram",
        mode: "preview",
        lng: -1.55257,
        lat: 47.21116,
        heading: 345,
        speedMps: 8,
        recordedAt: new Date().toISOString(),
        routeId: "3",
        destination: "Marcel Paul",
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
    const panel = panelRef.current;
    if (!panel) return;

    const observer = new IntersectionObserver(
      ([entry]) => setAnimationActive(entry.isIntersecting),
      { threshold: 0.12 },
    );
    observer.observe(panel);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (!animationActive) return;
    const formatter = new Intl.DateTimeFormat("fr-FR", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    });
    const refreshClock = () => setUpdatedAt(formatter.format(new Date()));
    refreshClock();
    const timer = window.setInterval(refreshClock, 1_000);
    return () => window.clearInterval(timer);
  }, [animationActive]);

  useEffect(() => {
    if (!vehicleLayerReady || !vehicleLayerRef.current || !animationActive) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const layer = vehicleLayerRef.current;
    const tick = () => {
      const frameTime = performance.now() / 1000;
      animationEpochRef.current ??= frameTime;
      const now = frameTime - animationEpochRef.current;
      animatePreviewAlongPath(
        layer,
        "section-tram-1-east",
        line1Path,
        now,
        7.5,
        20,
        -1,
        0.52,
        7,
        previewAnglesRef.current,
      );
      animatePreviewAlongPath(
        layer,
        "section-tram-1-west",
        line1Path,
        now,
        7.2,
        110,
        1,
        0.52,
        7,
        previewAnglesRef.current,
      );
      animatePreviewAlongPath(
        layer,
        "section-tram-2-south",
        lines23Path,
        now,
        6.8,
        40,
        1,
        0.54,
        8,
        previewAnglesRef.current,
      );
      animatePreviewAlongPath(
        layer,
        "section-tram-3-north",
        line3Path,
        now,
        7,
        100,
        -1,
        0.5,
        8,
        previewAnglesRef.current,
      );
      rafRef.current = requestAnimationFrame(tick);
    };

    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [animationActive, vehicleLayerReady, line1Path, line3Path, lines23Path]);

  return (
    <div ref={panelRef} data-par="1.3" className={styles.environmentMapPanel}>
      <LandingMapView
        center={[-1.55591, 47.21427]}
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
        ariaLabel="Carte 3D en direct du pôle d'échanges Commerce à Nantes, avec quatre tramways animés sur les lignes 1, 2 et 3"
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
      </div>
      <div className={styles.environmentMapRealtime} aria-hidden="true">
        <span className={styles.environmentMapRealtimeDot} />
        <span><strong>4 véhicules</strong><small>{updatedAt}</small></span>
      </div>
      <div className={styles.environmentMapArrivals} aria-hidden="true">
        <span><i className={styles.environmentMapLine1}>1</i><small>Beaujoire</small><strong>1 min</strong></span>
        <span><i className={styles.environmentMapLine2}>2</i><small>Pont-Rousseau</small><strong>2 min</strong></span>
        <span><i className={styles.environmentMapLine3}>3</i><small>Marcel Paul</small><strong>4 min</strong></span>
      </div>
      <div className={styles.environmentMapLegend}>
        <span className={styles.environmentMapLegendLabel}>Temps réel</span>
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
      ambientSimulation
      ambientDensity={0.48}
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
