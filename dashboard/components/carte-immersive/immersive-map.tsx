"use client";

import "maplibre-gl/dist/maplibre-gl.css";
import maplibregl from "maplibre-gl";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  CATEGORIES,
  CITY_CENTER,
  PLACES,
  ROUTE_DELTAS,
  SHOP_DEFS,
  SHOP_DELTAS,
  VEHICLE_DEFS,
  buildMenu,
  fmt,
  type ShopDef,
  type VehicleDef,
} from "@/lib/carte-immersive/data";
import { pathLen, pointAt, type LatLng } from "@/lib/carte-immersive/geo";
import type { MapVehicle } from "@/lib/carte-immersive/vehicles";
import { useImmersiveFleet } from "@/hooks/use-immersive-fleet";
import {
  addExtrudedBuildings,
  applyDarkReskin,
  ensureRouteLayer,
  ensureTransitTracesLayer,
  hideGenericPois,
  registerMissingImageFallback,
  setTransitTracesFilter,
} from "./map-style";
import type { RealLineTrace } from "@/lib/carte-immersive/real-lines";
import { createDestElement, createShopElement, createUserElement } from "./map-markers";
import { TopBar } from "./top-bar";
import { QuickActionsPanel } from "./quick-actions-panel";
import { FiltersPanel, type FilterKey } from "./filters-panel";
import { GeoPrompt } from "./geo-prompt";
import { RoutePanel, type RouteMode, type RouteStep } from "./route-panel";
import { FocusPanel, type RideItem, type ShopResultItem, type SortMode } from "./focus-panel";
import { DetailPanel, type SelectedDetail } from "./detail-panel";
import { MerchantSheet, type MenuChip, type CartLine } from "./merchant-sheet";
import { Vehicle3DLayer } from "./vehicle-3d-layer";

type SelectedKind = "vehicle" | "shop" | null;
type FocusMode = "ride" | "shop" | null;
type GeoSuggestion = { name: string; meta: string; icon: string; dist: string; latLng: LatLng };

const GEOLOCATION_CONSENT_KEY = "aule:geolocation-consent";

function createLocateControl(onLocate: () => void): maplibregl.IControl {
  let container: HTMLDivElement | null = null;
  let button: HTMLButtonElement | null = null;

  return {
    onAdd() {
      container = document.createElement("div");
      container.className = "maplibregl-ctrl maplibregl-ctrl-group";

      button = document.createElement("button");
      button.type = "button";
      button.className = "maplibregl-ctrl-geolocate";
      button.title = "Recentrer sur ma position";
      button.setAttribute("aria-label", "Recentrer la carte sur ma position");

      const icon = document.createElement("span");
      icon.className = "maplibregl-ctrl-icon";
      icon.setAttribute("aria-hidden", "true");
      button.appendChild(icon);
      button.addEventListener("click", onLocate);
      container.appendChild(button);

      return container;
    },
    onRemove() {
      button?.removeEventListener("click", onLocate);
      container?.remove();
      button = null;
      container = null;
    },
  };
}

/** Utilise le tracé GTFS réel du véhicule s'il est disponible, sinon le trajet fictif de démo. */
function pathCoords(v: VehicleDef, realPaths: Record<string, LatLng[]>): LatLng[] {
  const real = realPaths[v.id];
  if (real && real.length >= 2) return real;
  return ROUTE_DELTAS[v.path].map((d) => [CITY_CENTER[0] + d[0], CITY_CENTER[1] + d[1]]);
}

type ImmersiveMapProps = {
  realPaths?: Record<string, LatLng[]>;
  realLineTraces?: RealLineTrace[];
};

export function ImmersiveMap({ realPaths = {}, realLineTraces = [] }: ImmersiveMapProps) {
  const mapContainerRef = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const readyRef = useRef(false);
  const rafRef = useRef(0);
  const vehicleLayerRef = useRef<Vehicle3DLayer | null>(null);
  const shopMarkersRef = useRef<Record<string, maplibregl.Marker>>({});
  const userMarkerRef = useRef<maplibregl.Marker | null>(null);
  const destMarkerRef = useRef<maplibregl.Marker | null>(null);
  const previewAnglesRef = useRef<Map<string, number>>(new Map());
  const shopSearchCenterRef = useRef<maplibregl.LngLat | null>(null);
  const orderTimeoutRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const orbitingRef = useRef(false);
  const userPositionRef = useRef<LatLng | null>(null);
  const geoWatchIdRef = useRef<number | null>(null);
  const locateActionRef = useRef<() => void>(() => {});
  const realPathsRef = useRef(realPaths);
  const { vehicles: liveVehicles, mode: fleetMode, stale: fleetStale } = useImmersiveFleet();

  const [filters, setFilters] = useState<Record<FilterKey, boolean>>({
    bus: true,
    tram: true,
    vtc: true,
    taxi: true,
    shop: true,
  });
  const [selectedKind, setSelectedKind] = useState<SelectedKind>(null);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [routeActive, setRouteActive] = useState(false);
  const [geoGranted, setGeoGranted] = useState(false);
  const [geoPromptVisible, setGeoPromptVisible] = useState(false);
  const [geoDeniedNoticeVisible, setGeoDeniedNoticeVisible] = useState(false);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [destName, setDestName] = useState("");
  const [routeMode, setRouteMode] = useState<RouteMode>("foot");
  const [routeLoading, setRouteLoading] = useState(false);
  const [routeError, setRouteError] = useState<string | null>(null);
  const [routeInfo, setRouteInfo] = useState<{ distanceM: number; durationMin: number; steps: RouteStep[] } | null>(
    null,
  );
  const activeRouteRef = useRef<{ origin: LatLng; dest: LatLng; destName: string } | null>(null);
  const [geoResults, setGeoResults] = useState<GeoSuggestion[]>([]);
  const [originQuery, setOriginQuery] = useState("");
  const [showOriginSuggestions, setShowOriginSuggestions] = useState(false);
  const [originGeoResults, setOriginGeoResults] = useState<GeoSuggestion[]>([]);
  const [originOverride, setOriginOverride] = useState<GeoSuggestion | null>(null);
  const [quickCollapsed, setQuickCollapsed] = useState(false);
  const [showRouteInputs, setShowRouteInputs] = useState(false);
  const [focusMode, setFocusMode] = useState<FocusMode>(null);
  const [shopQuery, setShopQuery] = useState("");
  const [activeCats, setActiveCats] = useState<Record<string, boolean>>({});
  const [sortMode, setSortMode] = useState<SortMode>("distance");
  const [showSearchArea, setShowSearchArea] = useState(false);
  const [view3D, setView3D] = useState(true);
  const [orbiting, setOrbiting] = useState(false);
  const [merchantId, setMerchantId] = useState<string | null>(null);
  const [menuCat, setMenuCat] = useState("all");
  const [cart, setCart] = useState<Record<string, number>>({});
  const [cartOpen, setCartOpen] = useState(false);
  const [orderPlaced, setOrderPlaced] = useState(false);
  const [mapError, setMapError] = useState<string | null>(null);

  const displayVehicles = useMemo<MapVehicle[]>(() => {
    const previewVehicles = VEHICLE_DEFS.map((vehicle) => {
      const start = pointAt(pathCoords(vehicle, realPaths), 0);
      return {
        id: vehicle.id,
        type: vehicle.type,
        mode: "preview" as const,
        lat: start.lat,
        lng: start.lng,
        heading: 0,
        speedMps: null,
        recordedAt: null,
        routeId: vehicle.line,
        destination: vehicle.dest,
        preview: vehicle,
      };
    });
    const ridePreviews = previewVehicles.filter(
      (vehicle) => vehicle.type === "vtc" || vehicle.type === "taxi",
    );
    if (liveVehicles.length > 0) return [...liveVehicles, ...ridePreviews];
    return previewVehicles;
  }, [liveVehicles, realPaths]);

  const displayVehiclesRef = useRef(displayVehicles);
  const previewIdsRef = useRef(new Set<string>());
  displayVehiclesRef.current = displayVehicles;
  previewIdsRef.current = new Set(
    displayVehicles.filter((vehicle) => vehicle.mode === "preview").map((vehicle) => vehicle.id),
  );

  // ===== Sélection & focus =====
  const select = useCallback((kind: "vehicle" | "shop", id: string) => {
    setSelectedKind(kind);
    setSelectedId(id);
    setRouteActive(false);
  }, []);

  const hoverShop = useCallback((id: string) => {
    const marker = shopMarkersRef.current[id];
    const inner = marker?.getElement().firstElementChild as HTMLElement | undefined;
    if (inner) {
      inner.style.transition = "transform .2s ease, box-shadow .2s ease";
      inner.style.transform = "scale(1.35)";
      inner.style.boxShadow = "0 0 0 8px rgba(51,191,163,0.35), 0 6px 14px rgba(0,0,0,0.35)";
    }
  }, []);

  const unhoverShop = useCallback((id: string) => {
    const marker = shopMarkersRef.current[id];
    const inner = marker?.getElement().firstElementChild as HTMLElement | undefined;
    if (inner) {
      inner.style.transform = "scale(1)";
      inner.style.boxShadow = "0 6px 14px rgba(0,0,0,0.35)";
    }
  }, []);

  const openMerchant = useCallback((id: string) => {
    setMerchantId(id);
    setMenuCat("all");
    setCart({});
    setCartOpen(false);
    setOrderPlaced(false);
    setSelectedKind(null);
    setSelectedId(null);
  }, []);

  // Toujours à jour : les marqueurs (créés une seule fois) appellent ces callbacks
  // via cette ref pour éviter les fermetures obsolètes (stale closures).
  const apiRef = useRef({ select, hoverShop, unhoverShop });
  useEffect(() => {
    apiRef.current = { select, hoverShop, unhoverShop };
  }, [select, hoverShop, unhoverShop]);

  // ===== Construction des marqueurs (appelée une fois, après le chargement du style) =====
  const buildMarkers = useCallback(() => {
    const map = mapRef.current;
    if (!map) return;

    for (const s of SHOP_DEFS) {
      const delta = SHOP_DELTAS[s.id];
      const el = createShopElement(s.emoji, () => apiRef.current.select("shop", s.id));
      const marker = new maplibregl.Marker({ element: el, anchor: "bottom" })
        .setLngLat([CITY_CENTER[1] + delta[1], CITY_CENTER[0] + delta[0]])
        .addTo(map);
      shopMarkersRef.current[s.id] = marker;
    }

    const userEl = createUserElement();
    const initialUserPosition = userPositionRef.current ?? CITY_CENTER;
    userMarkerRef.current = new maplibregl.Marker({ element: userEl, anchor: "center" })
      .setLngLat([initialUserPosition[1], initialUserPosition[0]])
      .addTo(map);
  }, []);

  // ===== Boucle d'animation des véhicules =====
  const tick = useCallback(function animateVehicles() {
    rafRef.current = requestAnimationFrame(animateVehicles);
    const map = mapRef.current;
    if (!map || !readyRef.current) return;
    const now = performance.now() / 1000;

    for (const v of VEHICLE_DEFS) {
      if (!previewIdsRef.current.has(v.id)) continue;

      const pts = pathCoords(v, realPathsRef.current);
      const total = pathLen(pts);
      const cycle = 2 * total;
      let d = (((now * v.speed * 0.02 + v.phase) % cycle) + cycle) % cycle;
      let reverse = false;
      if (d > total) {
        d = cycle - d;
        reverse = true;
      }
      const p = pointAt(pts, d);
      const dir = reverse ? -1 : 1;
      const eps = Math.max(0.00035, total * 0.03);
      const ahead = pointAt(pts, Math.max(0, Math.min(total, d + dir * eps)));
      const behind = pointAt(pts, Math.max(0, Math.min(total, d - dir * eps)));
      const east = (ahead.lng - behind.lng) * Math.cos((p.lat * Math.PI) / 180);
      const north = ahead.lat - behind.lat;
      let heading = (Math.atan2(east, north) * 180) / Math.PI;
      const previous = previewAnglesRef.current.get(v.id);
      if (previous != null) {
        const delta = ((heading - previous + 540) % 360) - 180;
        heading = previous + delta * 0.25;
      }
      previewAnglesRef.current.set(v.id, heading);
      vehicleLayerRef.current?.setPreviewPose(v.id, p.lat, p.lng, heading);
    }
  }, []);

  // ===== Initialisation de la carte (une seule fois) =====
  useEffect(() => {
    if (!mapContainerRef.current || mapRef.current) return;

    let map: maplibregl.Map;
    try {
      map = new maplibregl.Map({
        container: mapContainerRef.current,
        style: "https://tiles.openfreemap.org/styles/liberty",
        center: [CITY_CENTER[1], CITY_CENTER[0]],
        zoom: 14,
        pitch: 55,
        bearing: -18,
        canvasContextAttributes: { antialias: true, preserveDrawingBuffer: false },
        attributionControl: { compact: true },
      });
    } catch (err) {
      console.error("[ImmersiveMap] Échec de création du contexte WebGL", err);
      setMapError(
        "La carte 3D n'a pas pu s'initialiser sur cet appareil (WebGL indisponible).",
      );
      return;
    }
    mapRef.current = map;
    map.on("error", (e) => console.error("[ImmersiveMap] Erreur MapLibre", e.error));
    registerMissingImageFallback(map);
    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "bottom-right");
    map.addControl(createLocateControl(() => locateActionRef.current()), "bottom-right");
    map.dragRotate.enable();
    requestAnimationFrame(() => map.resize());
    const resizeTimer = setTimeout(() => map.resize(), 300);

    const handleViewportResize = () => map.resize();
    const resizeObserver = new ResizeObserver(handleViewportResize);
    resizeObserver.observe(mapContainerRef.current);
    window.addEventListener("orientationchange", handleViewportResize);
    window.visualViewport?.addEventListener("resize", handleViewportResize);

    map.on("load", () => {
      try {
        map.setSky({
          "sky-color": "#0a1614",
          "horizon-color": "#12241f",
          "fog-color": "#0a1210",
          "sky-horizon-blend": 0.5,
          "horizon-fog-blend": 0.6,
          "fog-ground-blend": 0.6,
        });
      } catch {
        // certains navigateurs/versions du style ne supportent pas le ciel custom
      }

      applyDarkReskin(map);
      addExtrudedBuildings(map);
      hideGenericPois(map);
      ensureRouteLayer(map);
      ensureTransitTracesLayer(
        map,
        realLineTraces.map((t) => ({
          id: t.id,
          type: t.type,
          color: t.color,
          coords: t.coords.map(([lat, lng]) => [lng, lat] as [number, number]),
        })),
      );
      const firstLabelLayer = map
        .getStyle()
        .layers.find(
          (layer) =>
            layer.type === "symbol" &&
            "layout" in layer &&
            layer.layout &&
            "text-field" in layer.layout,
        )?.id;
      const vehicleLayer = new Vehicle3DLayer({
        onSelect: (id) => apiRef.current.select("vehicle", id),
      });
      vehicleLayerRef.current = vehicleLayer;
      vehicleLayer.setVehicles(displayVehiclesRef.current);
      map.addLayer(vehicleLayer, firstLabelLayer);
      buildMarkers();
      readyRef.current = true;

      map.on("moveend", () => {
        if (focusModeRef.current !== "shop" || !shopSearchCenterRef.current) return;
        const c1 = shopSearchCenterRef.current;
        const c2 = map.getCenter();
        const d = Math.hypot(c1.lat - c2.lat, c1.lng - c2.lng);
        if (d > 0.003 && !showSearchAreaRef.current) setShowSearchArea(true);
      });

      const knownPosition = userPositionRef.current;
      const introCenter = knownPosition ?? CITY_CENTER;
      map.flyTo({
        center: [introCenter[1], introCenter[0]],
        zoom: 15.6,
        pitch: 58,
        bearing: -18,
        duration: 2400,
      });
      rafRef.current = requestAnimationFrame(tick);
    });

    return () => {
      clearTimeout(resizeTimer);
      resizeObserver.disconnect();
      window.removeEventListener("orientationchange", handleViewportResize);
      window.visualViewport?.removeEventListener("resize", handleViewportResize);
      cancelAnimationFrame(rafRef.current);
      map.remove();
      mapRef.current = null;
      vehicleLayerRef.current = null;
      readyRef.current = false;
    };
    // La carte n'est montée qu'une fois ; les mises à jour passent par les refs et actions ci-dessous.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Refs "toujours à jour" pour les callbacks de la carte (moveend) qui ne doivent pas être recréés.
  const focusModeRef = useRef<FocusMode>(null);
  const showSearchAreaRef = useRef(false);
  useEffect(() => {
    focusModeRef.current = focusMode;
    showSearchAreaRef.current = showSearchArea;
  }, [focusMode, showSearchArea]);

  useEffect(() => {
    vehicleLayerRef.current?.setVehicles(displayVehicles);
  }, [displayVehicles]);

  useEffect(() => {
    vehicleLayerRef.current?.setSelected(selectedKind === "vehicle" ? selectedId : null);
  }, [selectedKind, selectedId]);

  useEffect(() => {
    vehicleLayerRef.current?.setFocus(focusMode);
  }, [focusMode]);

  useEffect(() => {
    const layer = vehicleLayerRef.current;
    if (!layer) return;
    layer.setView3D(view3D);
    layer.setFilter("bus", filters.bus);
    layer.setFilter("tram", filters.tram);
    layer.setFilter("vtc", filters.vtc);
    layer.setFilter("taxi", filters.taxi);
  }, [view3D, filters]);

  useEffect(() => () => clearTimeout(orderTimeoutRef.current), []);

  // ===== Vue 3D / 2D =====
  const toggleView = () => {
    const next = !view3D;
    setView3D(next);
    vehicleLayerRef.current?.setView3D(next);
    const map = mapRef.current;
    if (!map) return;
    if (next) {
      const pos = userPositionRef.current;
      map.easeTo({
        pitch: 58,
        bearing: -16,
        duration: 900,
        zoom: Math.max(map.getZoom(), 16.5),
        ...(geoGranted && pos ? { center: [pos[1], pos[0]] as [number, number] } : {}),
      });
    } else {
      map.easeTo({ pitch: 0, bearing: 0, duration: 900 });
    }
  };

  // ===== Vue 360° =====
  const toggleOrbit = () => {
    const map = mapRef.current;
    if (orbitingRef.current) {
      orbitingRef.current = false;
      setOrbiting(false);
      return;
    }
    if (!map) return;
    orbitingRef.current = true;
    setOrbiting(true);
    if (view3D && map.getPitch() < 30) map.easeTo({ pitch: 58, duration: 500 });
    const start = map.getBearing();
    const t0 = performance.now();
    const dur = 7000;
    const step = (t: number) => {
      if (!orbitingRef.current || !mapRef.current) return;
      const k = Math.min(1, (t - t0) / dur);
      const eased = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
      mapRef.current.setBearing(start + 360 * eased);
      if (k < 1) requestAnimationFrame(step);
      else {
        orbitingRef.current = false;
        setOrbiting(false);
      }
    };
    requestAnimationFrame(step);
  };

  // ===== Géolocalisation (réelle, via l'API navigateur) =====
  const flyToPosition = (center: LatLng, pitchOverride?: number, bearingOverride?: number, duration = 1800) => {
    const map = mapRef.current;
    if (!map) return;
    map.flyTo({
      center: [center[1], center[0]],
      zoom: 17.3,
      pitch: pitchOverride ?? (view3D ? 60 : 0),
      bearing: bearingOverride ?? (view3D ? -14 : 0),
      duration,
    });
  };

  const placeUserMarker = (position: LatLng) => {
    userPositionRef.current = position;
    userMarkerRef.current?.setLngLat([position[1], position[0]]);
  };

  const locateUser = useCallback((onFound: (position: LatLng) => void, onError: () => void) => {
    if (!("geolocation" in navigator)) {
      onError();
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => onFound([pos.coords.latitude, pos.coords.longitude]),
      () => onError(),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 10000 },
    );
  }, []);

  const startWatchingPosition = useCallback(() => {
    if (!("geolocation" in navigator) || geoWatchIdRef.current != null) return;
    geoWatchIdRef.current = navigator.geolocation.watchPosition(
      (pos) => placeUserMarker([pos.coords.latitude, pos.coords.longitude]),
      () => {},
      { enableHighAccuracy: true, maximumAge: 10000 },
    );
  }, []);

  const onGeoAllow = () => {
    setGeoPromptVisible(false);
    locateUser(
      (position) => {
        localStorage.setItem(GEOLOCATION_CONSENT_KEY, "granted");
        setGeoGranted(true);
        setGeoDeniedNoticeVisible(false);
        placeUserMarker(position);
        flyToPosition(position);
        startWatchingPosition();
      },
      () => {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoGranted(false);
        setGeoDeniedNoticeVisible(true);
      },
    );
  };
  const onGeoDeny = () => {
    setGeoGranted(false);
    setGeoPromptVisible(false);
    setGeoDeniedNoticeVisible(true);
  };
  const onLocateClick = () => {
    setGeoDeniedNoticeVisible(false);
    locateUser(
      (position) => {
        localStorage.setItem(GEOLOCATION_CONSENT_KEY, "granted");
        setGeoGranted(true);
        placeUserMarker(position);
        flyToPosition(position);
        startWatchingPosition();
      },
      () => {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoGranted(false);
        setGeoDeniedNoticeVisible(true);
      },
    );
  };
  locateActionRef.current = onLocateClick;

  useEffect(() => {
    let cancelled = false;

    const restoreGeolocationConsent = async () => {
      const consentWasGranted = localStorage.getItem(GEOLOCATION_CONSENT_KEY) === "granted";
      let permissionState: PermissionState | null = null;

      if ("permissions" in navigator) {
        try {
          const permission = await navigator.permissions.query({ name: "geolocation" });
          permissionState = permission.state;
        } catch {
          // Certains navigateurs ne prennent pas en charge la requête de permission géolocalisation.
        }
      }

      if (cancelled) return;

      if (permissionState === "denied") {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoDeniedNoticeVisible(true);
        return;
      }

      if (permissionState === "prompt") {
        localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
        setGeoPromptVisible(true);
        return;
      }

      if (permissionState !== "granted" && !consentWasGranted) {
        setGeoPromptVisible(true);
        return;
      }

      locateUser(
        (position) => {
          if (cancelled) return;
          localStorage.setItem(GEOLOCATION_CONSENT_KEY, "granted");
          setGeoGranted(true);
          setGeoDeniedNoticeVisible(false);
          placeUserMarker(position);
          flyToPosition(position, undefined, undefined, 0);
          startWatchingPosition();
        },
        () => {
          if (cancelled) return;
          localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
          setGeoGranted(false);
          setGeoDeniedNoticeVisible(true);
        },
      );
    };

    void restoreGeolocationConsent();

    return () => {
      cancelled = true;
      if (geoWatchIdRef.current != null) navigator.geolocation.clearWatch(geoWatchIdRef.current);
    };
    // La restauration ne doit s'exécuter qu'une fois au chargement de la page.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // ===== Recherche =====
  async function geocodeQuery(q: string): Promise<GeoSuggestion[]> {
    try {
      const res = await fetch(`/api/geocode?q=${encodeURIComponent(q)}`);
      if (!res.ok) return [];
      const data = (await res.json()) as { results?: Array<{ label: string; lat: number; lng: number }> };
      return (data.results ?? []).slice(0, 5).map((r) => {
        const [name, ...rest] = r.label.split(",");
        return {
          name: name.trim(),
          meta: rest.slice(0, 2).join(",").trim(),
          icon: "📍",
          dist: "",
          latLng: [r.lat, r.lng] as LatLng,
        };
      });
    } catch {
      return [];
    }
  }

  useEffect(() => {
    const q = searchQuery.trim();
    if (q.length < 3) {
      setGeoResults([]);
      return;
    }
    const handle = setTimeout(() => void geocodeQuery(q).then(setGeoResults), 350);
    return () => clearTimeout(handle);
  }, [searchQuery]);

  useEffect(() => {
    const q = originQuery.trim();
    if (q.length < 3) {
      setOriginGeoResults([]);
      return;
    }
    const handle = setTimeout(() => void geocodeQuery(q).then(setOriginGeoResults), 350);
    return () => clearTimeout(handle);
  }, [originQuery]);

  const placesAsSuggestions = (q: string): GeoSuggestion[] => {
    const asGeoSuggestion = (p: (typeof PLACES)[number]): GeoSuggestion => ({
      name: p.name,
      meta: p.meta,
      icon: p.icon,
      dist: p.dist,
      latLng: [CITY_CENTER[0] + p.delta[0], CITY_CENTER[1] + p.delta[1]],
    });
    if (!q) return PLACES.slice(0, 5).map(asGeoSuggestion);
    return PLACES.filter((p) => (p.name + " " + p.meta).toLowerCase().includes(q)).map(asGeoSuggestion);
  };

  const filteredPlaces = (): GeoSuggestion[] => {
    const q = searchQuery.trim().toLowerCase();
    return [...placesAsSuggestions(q), ...geoResults].slice(0, 6);
  };

  const filteredOriginPlaces = (): GeoSuggestion[] => {
    const q = originQuery.trim().toLowerCase();
    return [...placesAsSuggestions(q), ...originGeoResults].slice(0, 6);
  };

  const computeRoute = async (mode: RouteMode, origin: LatLng, dest: LatLng, name: string) => {
    const map = mapRef.current;
    if (!map) return;

    activeRouteRef.current = { origin, dest, destName: name };
    setRouteActive(true);
    setRouteLoading(true);
    setRouteError(null);
    setRouteInfo(null);

    try {
      const apiMode = mode === "transit" ? "transit" : mode;
      const url = `/api/route?mode=${apiMode}&from=${origin[1]},${origin[0]}&to=${dest[1]},${dest[0]}`;
      const res = await fetch(url, { cache: "no-store" });
      const data = (await res.json()) as {
        coordinates?: [number, number][];
        distance?: number;
        duration?: number;
        steps?: RouteStep[];
        error?: string;
      };
      if (!res.ok || !data.coordinates) {
        throw new Error(data.error ?? "Itinéraire indisponible");
      }

      const src = map.getSource("immersive-map-route") as maplibregl.GeoJSONSource | undefined;
      src?.setData({
        type: "Feature",
        properties: {},
        geometry: { type: "LineString", coordinates: data.coordinates },
      });

      destMarkerRef.current?.remove();
      destMarkerRef.current = new maplibregl.Marker({ element: createDestElement(), anchor: "bottom" })
        .setLngLat([dest[1], dest[0]])
        .addTo(map);

      const bounds = new maplibregl.LngLatBounds([origin[1], origin[0]], [origin[1], origin[0]]);
      bounds.extend([dest[1], dest[0]]);
      map.fitBounds(bounds, {
        padding: { top: 140, bottom: 120, left: 380, right: 120 },
        pitch: view3D ? 50 : 0,
        duration: 1600,
        maxZoom: 16.5,
      });

      const durationMin = Math.max(1, Math.round((data.duration ?? 0) / 60));
      const distanceM = Math.round(data.distance ?? 0);
      const distanceLabel = distanceM >= 1000 ? `${(distanceM / 1000).toFixed(1)} km` : `${distanceM} m`;
      const steps =
        data.steps ??
        ([
          {
            icon: mode === "car" ? "🚗" : "🚶",
            label: mode === "car" ? `En voiture jusqu'à ${name}` : `Marche à pied jusqu'à ${name}`,
            detail: distanceLabel,
            duration: `${durationMin} min`,
          },
        ] as RouteStep[]);

      setRouteInfo({ distanceM, durationMin, steps });
    } catch (err) {
      setRouteError(err instanceof Error ? err.message : "Itinéraire indisponible");
    } finally {
      setRouteLoading(false);
    }
  };

  const onSearchSubmit = async (destArg?: LatLng, nameArg?: string) => {
    const first = filteredPlaces()[0];
    let dest = destArg ?? first?.latLng;
    let name = nameArg ?? first?.name ?? "";

    const rawQuery = searchQuery.trim();
    if (!dest && rawQuery.length >= 3) {
      const geocoded = (await geocodeQuery(rawQuery))[0];
      if (geocoded) {
        dest = geocoded.latLng;
        name = geocoded.name;
      }
    }
    if (!dest) return;

    const origin = originOverride?.latLng ?? userPositionRef.current;
    if (!origin) {
      setRouteActive(true);
      setRouteError("Autorisez la géolocalisation ou saisissez une adresse de départ.");
      setGeoPromptVisible(true);
      return;
    }

    setSelectedKind(null);
    setSelectedId(null);
    setShowSuggestions(false);
    setDestName(name);

    await computeRoute(routeMode, origin, dest, name);
  };

  const changeRouteMode = (mode: RouteMode) => {
    setRouteMode(mode);
    const active = activeRouteRef.current;
    if (active) void computeRoute(mode, active.origin, active.dest, active.destName);
  };

  const pickPlace = (p: GeoSuggestion) => {
    setSearchQuery(p.name);
    setDestName(p.name);
    setShowSuggestions(false);
    setTimeout(() => onSearchSubmit(p.latLng, p.name), 0);
  };

  const pickOriginPlace = (p: GeoSuggestion) => {
    setOriginQuery(p.name);
    setOriginOverride(p);
    setShowOriginSuggestions(false);
  };

  const resetOriginToGps = () => {
    setOriginOverride(null);
    setOriginQuery("");
    setShowOriginSuggestions(false);
  };

  const closeRoute = () => {
    setRouteActive(false);
    setRouteError(null);
    setRouteInfo(null);
    setShowRouteInputs(false);
    activeRouteRef.current = null;
    const map = mapRef.current;
    const src = map?.getSource("immersive-map-route") as maplibregl.GeoJSONSource | undefined;
    src?.setData({ type: "FeatureCollection", features: [] });
    destMarkerRef.current?.remove();
    destMarkerRef.current = null;
  };

  // ===== Filtres & actions rapides =====
  const setVehicleTypeDisplay = (type: FilterKey, show: boolean) => {
    if (type === "shop") {
      for (const id in shopMarkersRef.current) shopMarkersRef.current[id].getElement().style.display = show ? "" : "none";
      return;
    }
    vehicleLayerRef.current?.setFilter(type, show);
    if (type === "bus" || type === "tram") {
      const nextFilters = { ...filters, [type]: show };
      const map = mapRef.current;
      if (map) {
        setTransitTracesFilter(
          map,
          (["bus", "tram"] as const).filter((t) => nextFilters[t]),
        );
      }
    }
  };

  const toggleFilter = (key: FilterKey) => {
    const next = !filters[key];
    setFilters((f) => ({ ...f, [key]: next }));
    setVehicleTypeDisplay(key, next);
  };

  const ensureVisible = (keys: FilterKey[]) => {
    setFilters((f) => {
      const upd = { ...f };
      for (const k of keys) upd[k] = true;
      return upd;
    });
    for (const k of keys) setVehicleTypeDisplay(k, true);
  };

  const applyFocus = (mode: FocusMode) => {
    vehicleLayerRef.current?.setFocus(mode);
    const setOp = (marker: maplibregl.Marker | undefined, on: boolean) => {
      if (!marker) return;
      const el = marker.getElement();
      el.style.transition = "opacity .45s ease";
      el.style.opacity = on ? "1" : "0.22";
    };
    for (const id in shopMarkersRef.current) {
      let on = true;
      if (mode === "ride") on = false;
      setOp(shopMarkersRef.current[id], on);
    }
  };

  const flyGentle = () => {
    const map = mapRef.current;
    if (!map) return;
    map.flyTo({
      center: map.getCenter(),
      zoom: Math.max(map.getZoom(), 16.6),
      pitch: view3D ? 58 : 0,
      duration: 1100,
    });
  };

  const clearFocus = () => {
    setFocusMode(null);
    setShowRouteInputs(false);
    applyFocus(null);
  };

  const qaRoute = () => {
    setFocusMode(null);
    setShowSuggestions(true);
    setShowRouteInputs(true);
    setSelectedKind(null);
    setSelectedId(null);
    applyFocus(null);
  };
  const qaRide = () => {
    ensureVisible(["vtc", "taxi"]);
    setFocusMode("ride");
    setSelectedKind(null);
    setSelectedId(null);
    setRouteActive(false);
    setShowSuggestions(false);
    setShowRouteInputs(true);
    setQuickCollapsed(true);
    applyFocus("ride");
    flyGentle();
  };
  const qaShop = () => {
    ensureVisible(["shop"]);
    setFocusMode("shop");
    setSelectedKind(null);
    setSelectedId(null);
    setRouteActive(false);
    setShowSuggestions(false);
    setShowRouteInputs(false);
    setShowSearchArea(false);
    setQuickCollapsed(true);
    applyFocus("shop");
    flyGentle();
    if (mapRef.current) shopSearchCenterRef.current = mapRef.current.getCenter();
  };

  const searchThisArea = () => {
    setShowSearchArea(false);
    if (mapRef.current) shopSearchCenterRef.current = mapRef.current.getCenter();
  };

  // ===== Commerçants : recherche / tri =====
  const computeShopResults = (): ShopDef[] => {
    const q = shopQuery.trim().toLowerCase();
    const cats = Object.keys(activeCats).filter((k) => activeCats[k]);
    let list = SHOP_DEFS.filter((s) => {
      if (cats.length && !cats.includes(s.catKey)) return false;
      if (q && !(s.name + " " + s.cat).toLowerCase().includes(q)) return false;
      return true;
    });
    list = [...list].sort((a, b) => {
      if (sortMode === "rating") return Number(b.rating) - Number(a.rating);
      if (sortMode === "delivery") return (parseInt(a.delivery) || 999) - (parseInt(b.delivery) || 999);
      if (sortMode === "price") return a.price.length - b.price.length;
      if (sortMode === "popularity") return b.popularity - a.popularity;
      if (sortMode === "open") return (b.open ? 1 : 0) - (a.open ? 1 : 0);
      return a.distM - b.distM;
    });
    return list;
  };

  // ===== Panier / commerçant =====
  const addItem = (id: string) => setCart((c) => ({ ...c, [id]: (c[id] || 0) + 1 }));
  const decItem = (id: string) =>
    setCart((c) => {
      const q = (c[id] || 0) - 1;
      const next = { ...c };
      if (q <= 0) delete next[id];
      else next[id] = q;
      return next;
    });
  const toggleCart = () => setCartOpen((o) => !o);
  const closeMerchant = () => {
    clearTimeout(orderTimeoutRef.current);
    setMerchantId(null);
    setOrderPlaced(false);
  };
  const placeOrder = () => {
    if (!Object.keys(cart).length) return;
    setOrderPlaced(true);
    clearTimeout(orderTimeoutRef.current);
    orderTimeoutRef.current = setTimeout(() => {
      setOrderPlaced(false);
      setMerchantId(null);
      setCart({});
      setCartOpen(false);
    }, 2600);
  };

  const closeSelection = () => {
    setSelectedKind(null);
    setSelectedId(null);
  };

  // ===== Dérivés pour le rendu =====
  const detail: SelectedDetail | null = useMemo(() => {
    if (!selectedKind || !selectedId) return null;
    if (selectedKind === "vehicle") {
      const mapVehicle = displayVehicles.find((vehicle) => vehicle.id === selectedId);
      if (mapVehicle?.mode === "live") {
        const ageSeconds = mapVehicle.recordedAt
          ? Math.max(
              0,
              Math.round((Date.now() - new Date(mapVehicle.recordedAt).getTime()) / 1000),
            )
          : null;
        return {
          emoji: mapVehicle.type === "tram" ? "🚋" : "🚌",
          title: mapVehicle.routeId ? `Ligne ${mapVehicle.routeId}` : "Véhicule en circulation",
          subtitle: `${mapVehicle.type === "tram" ? "Tramway" : "Bus"} · Position en direct${
            fleetStale ? " (signal ancien)" : ""
          }`,
          facts: [
            { k: "Destination", v: mapVehicle.destination || "Non renseignée" },
            {
              k: "Vitesse",
              v:
                mapVehicle.speedMps == null
                  ? "Non disponible"
                  : `${Math.round(mapVehicle.speedMps * 3.6)} km/h`,
            },
            {
              k: "Actualisation",
              v: ageSeconds == null ? "À l’instant" : `Il y a ${ageSeconds} s`,
            },
            { k: "Source", v: "Flotte Aule anonymisée" },
          ],
          actionLabel: mapVehicle.type === "tram" ? "Suivre ce tram" : "Suivre ce bus",
          action: () => {},
        };
      }

      const v = mapVehicle?.preview ?? VEHICLE_DEFS.find((x) => x.id === selectedId);
      if (!v) return null;
      if (v.type === "bus" || v.type === "tram") {
        const facts = [
          { k: "Destination", v: v.dest ?? "" },
          { k: "Prochain arrêt", v: v.nextStop ?? "" },
          { k: "Arrivée", v: v.eta },
          { k: "Statut", v: v.status ?? "" },
        ];
        if (v.occ) facts.push({ k: "Occupation", v: v.occ });
        return {
          emoji: v.type === "bus" ? "🚌" : "🚋",
          title: v.line ?? "",
          subtitle: `Aperçu · ${v.type === "bus" ? "Bus en circulation" : "Tramway en circulation"}`,
          facts,
          actionLabel: v.type === "bus" ? "Suivre ce bus" : "Suivre ce tram",
          action: () => {},
        };
      }
      if (v.type === "vtc") {
        return {
          emoji: "🚖",
          title: v.driver ?? "",
          subtitle: "Aperçu · VTC disponible",
          facts: [
            { k: "Arrivée estimée", v: v.eta },
            { k: "Distance", v: v.dist ?? "" },
            { k: "Note", v: "★ " + v.rating },
            { k: "Tarif estimé", v: v.price ?? "" },
          ],
          actionLabel: "Réserver ce VTC",
          action: () => {},
        };
      }
      if (v.type === "taxi") {
        return {
          emoji: "🚕",
          title: "Taxi disponible",
          subtitle: `Aperçu · ${v.station ?? ""}`,
          facts: [
            { k: "Arrivée", v: v.eta },
            { k: "Station la plus proche", v: v.station ?? "" },
            { k: "Distance", v: v.dist ?? "" },
            { k: "Paiement", v: "CB / espèces" },
          ],
          actionLabel: "Commander ce taxi",
          action: () => {},
        };
      }
    }
    if (selectedKind === "shop") {
      const s = SHOP_DEFS.find((x) => x.id === selectedId);
      if (!s) return null;
      return {
        emoji: s.emoji,
        title: s.name,
        subtitle: s.cat,
        facts: [
          { k: "Distance", v: s.dist },
          { k: "À pied", v: s.walk },
          { k: "Horaires", v: s.hours },
          { k: "Note", v: "★ " + s.rating },
        ],
        actionLabel: "Commander ici",
        action: () => openMerchant(s.id),
      };
    }
    return null;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedKind, selectedId, displayVehicles, fleetStale]);

  const focusVisible = !!focusMode && !detail;

  const rideItems: RideItem[] = useMemo(
    () =>
      VEHICLE_DEFS.filter((v) => v.type === "vtc" || v.type === "taxi").map((v) => ({
        id: v.id,
        emoji: v.type === "vtc" ? "🚖" : "🚕",
        title: v.type === "vtc" ? (v.driver ?? "") : "Taxi disponible",
        meta: `Arrivée ${v.eta} · ${v.dist}`,
        btn: v.type === "vtc" ? "Réserver" : "Commander",
        onClick: () => select("vehicle", v.id),
      })),
    [select],
  );

  const shopResults: ShopResultItem[] = useMemo(
    () =>
      computeShopResults().map((s) => ({
        id: s.id,
        emoji: s.emoji,
        title: s.name,
        cat: s.cat,
        dist: s.dist,
        walk: s.walk,
        delivery: s.delivery,
        rating: s.rating,
        price: s.price,
        openLabel: s.open ? "Ouvert" : "Fermé",
        openColor: s.open ? "#33BFA3" : "#FF6B5E",
        onClick: () => select("shop", s.id),
        onEnter: () => hoverShop(s.id),
        onLeave: () => unhoverShop(s.id),
      })),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [shopQuery, activeCats, sortMode, select, hoverShop, unhoverShop],
  );

  const merchantShop = merchantId ? SHOP_DEFS.find((s) => s.id === merchantId) : null;

  const merchantData = useMemo(() => {
    if (!merchantShop) return null;
    const fullMenu = buildMenu(merchantShop);
    const menuChips: MenuChip[] = [{ key: "all", label: "Tout" }]
      .concat(fullMenu.map((s) => ({ key: s.name, label: s.name })))
      .map((c) => ({ key: c.key, label: c.label, active: menuCat === c.key }));
    const menuSections = fullMenu.filter((s) => menuCat === "all" || s.name === menuCat);

    const flat: Record<string, { name: string; price: number }> = {};
    fullMenu.forEach((s) => s.items.forEach((it) => (flat[it.id] = { name: it.name, price: it.price })));
    let cartCount = 0;
    let cartTotal = 0;
    const cartLines: CartLine[] = [];
    for (const id in cart) {
      const it = flat[id];
      if (!it) continue;
      const q = cart[id];
      cartCount += q;
      cartTotal += q * it.price;
      cartLines.push({ id, name: it.name, qty: q, lineTotal: fmt(q * it.price) });
    }

    return {
      merchant: {
        emoji: merchantShop.emoji,
        name: merchantShop.name,
        cat: merchantShop.cat,
        open: merchantShop.open,
        openLabel: merchantShop.open ? "Ouvert" : "Fermé",
        facts: [
          { icon: "★", v: merchantShop.rating },
          { icon: "📍", v: merchantShop.dist },
          { icon: "🚶", v: merchantShop.walk + " à pied" },
          { icon: "🚴", v: merchantShop.delivery !== "—" ? merchantShop.delivery : "Retrait" },
          { icon: "🕒", v: merchantShop.hours },
        ],
      },
      menuChips,
      menuSections,
      cartLines,
      cartCount,
      cartTotalLabel: fmt(cartTotal),
    };
  }, [merchantShop, menuCat, cart]);

  const arrivalStr = routeInfo
    ? (() => {
        const arrival = new Date(Date.now() + routeInfo.durationMin * 60000);
        return `${arrival.getHours().toString().padStart(2, "0")}:${arrival.getMinutes().toString().padStart(2, "0")}`;
      })()
    : "";
  const routeSteps: RouteStep[] = routeInfo?.steps ?? [];

  return (
    <div className="immersive-map-root">
      <div className="immersive-map-canvas">
        <div ref={mapContainerRef} className="h-full w-full" />
        {mapError && (
          <div className="flex h-full w-full items-center justify-center px-8 text-center text-sm text-white/70">
            {mapError}
          </div>
        )}
      </div>
      <div className="immersive-map-vignette" />
      <div className="immersive-map-vignette-top" />
      <div
        className={`immersive-map-live-status immersive-map-live-status--${fleetMode}${
          fleetStale ? " immersive-map-live-status--stale" : ""
        }`}
        aria-live="polite"
      >
        <span className="immersive-map-live-status-dot" />
        {fleetMode === "live"
          ? fleetStale
            ? "Temps réel · signal en attente"
            : `${liveVehicles.length} véhicule${liveVehicles.length > 1 ? "s" : ""} en direct`
          : "Mode aperçu"}
      </div>

      <TopBar
        view3D={view3D}
        onToggleView={toggleView}
        orbiting={orbiting}
        onToggleOrbit={toggleOrbit}
        showInputs={showRouteInputs}
        searchQuery={searchQuery}
        onSearchChange={(v) => {
          setSearchQuery(v);
          setShowSuggestions(true);
        }}
        onSearchKeyDown={(e) => {
          if (e.key === "Enter") {
            const list = filteredPlaces();
            if (list.length) pickPlace(list[0]);
            else onSearchSubmit();
          } else if (e.key === "Escape") {
            setShowSuggestions(false);
          }
        }}
        onSearchFocus={() => setShowSuggestions(true)}
        onSearchBlur={() => setTimeout(() => setShowSuggestions(false), 120)}
        onSearchSubmit={() => onSearchSubmit()}
        onLocateClick={onLocateClick}
        onCloseInputs={() => {
          closeRoute();
          clearFocus();
          setShowSuggestions(false);
          setShowOriginSuggestions(false);
        }}
        showSuggestions={showSuggestions}
        suggestions={filteredPlaces().map((p) => ({ ...p, onPick: () => pickPlace(p) }))}
        originQuery={originQuery}
        onOriginChange={(v) => {
          setOriginQuery(v);
          setShowOriginSuggestions(true);
          if (originOverride) setOriginOverride(null);
        }}
        onOriginKeyDown={(e) => {
          if (e.key === "Enter") {
            const list = filteredOriginPlaces();
            if (list.length) {
              pickOriginPlace(list[0]);
            } else {
              const q = originQuery.trim();
              if (q.length >= 3) void geocodeQuery(q).then((r) => r[0] && pickOriginPlace(r[0]));
            }
          } else if (e.key === "Escape") {
            setShowOriginSuggestions(false);
          }
        }}
        onOriginFocus={() => setShowOriginSuggestions(true)}
        onOriginBlur={() => setTimeout(() => setShowOriginSuggestions(false), 120)}
        onOriginClear={resetOriginToGps}
        originIsCustom={originOverride != null || originQuery.length > 0}
        showOriginSuggestions={showOriginSuggestions}
        originSuggestions={filteredOriginPlaces().map((p) => ({ ...p, onPick: () => pickOriginPlace(p) }))}
      />

      <QuickActionsPanel
        visible={geoGranted && !showRouteInputs}
        collapsed={quickCollapsed}
        onToggleCollapse={() => setQuickCollapsed((c) => !c)}
        onRoute={qaRoute}
        onRide={qaRide}
        onShop={qaShop}
      />

      <GeoPrompt
        promptVisible={geoPromptVisible}
        deniedNoticeVisible={geoDeniedNoticeVisible}
        city="Nantes"
        onAllow={onGeoAllow}
        onDeny={onGeoDeny}
      />

      <FiltersPanel filters={filters} onToggle={toggleFilter} />

      {routeActive && (
        <RoutePanel
          destName={destName}
          duration={routeInfo?.durationMin ?? 0}
          arrival={arrivalStr}
          steps={routeSteps}
          loading={routeLoading}
          error={routeError}
          mode={routeMode}
          onModeChange={changeRouteMode}
          onClose={closeRoute}
        />
      )}

      {focusVisible && (
        <FocusPanel
          mode={focusMode as "ride" | "shop"}
          title={focusMode === "ride" ? "VTC & taxis à proximité" : "Commerçants à proximité"}
          onClose={clearFocus}
          rideItems={rideItems}
          shopQuery={shopQuery}
          onShopQueryChange={setShopQuery}
          categories={CATEGORIES}
          activeCats={activeCats}
          onToggleCat={(key) => setActiveCats((c) => ({ ...c, [key]: !c[key] }))}
          sortMode={sortMode}
          onSortChange={setSortMode}
          showSearchArea={showSearchArea && focusMode === "shop"}
          onSearchThisArea={searchThisArea}
          shopResults={shopResults}
        />
      )}

      {detail && <DetailPanel selected={detail} onClose={closeSelection} />}

      {merchantShop && merchantData && (
        <MerchantSheet
          merchant={merchantData.merchant}
          menuChips={merchantData.menuChips}
          onPickMenuChip={setMenuCat}
          menuSections={merchantData.menuSections}
          cart={cart}
          onAddItem={addItem}
          onDecItem={decItem}
          fmt={fmt}
          cartLines={merchantData.cartLines}
          cartCount={merchantData.cartCount}
          cartTotalLabel={merchantData.cartTotalLabel}
          cartExpanded={cartOpen && merchantData.cartCount > 0}
          onToggleCart={toggleCart}
          onClose={closeMerchant}
          onOrder={placeOrder}
          orderConfirmVisible={orderPlaced}
        />
      )}
    </div>
  );
}
