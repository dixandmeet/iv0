import { NextResponse } from "next/server";
import { loadGtfsShapesForLine } from "@/lib/gtfs-shape-loader";
import { routeAlongShapes } from "@/lib/shape-route";
import { computeTransitRoute } from "@/lib/carte-immersive/transit-route";
import { computeTimetableTransitRoute } from "@/lib/carte-immersive/timetable-route";
import { createAdminClient } from "@/lib/supabase/admin";
import type { EditorTransportMode } from "@/lib/line-editor-types";

const OSRM_DRIVING_BASE =
  process.env.OSRM_DRIVING_URL?.replace(/\/$/, "") ??
  "https://router.project-osrm.org/route/v1/driving";
// Le serveur de démonstration OSRM principal utilise le graphe automobile quel
// que soit le nom de profil dans l'URL. Ce serveur OSM distinct est réellement
// construit avec le profil piéton (chemins, traversées et passerelles inclus).
const OSRM_WALKING_BASE =
  process.env.OSRM_WALKING_URL?.replace(/\/$/, "") ??
  "https://routing.openstreetmap.de/routed-foot/route/v1/driving";
// On garde une vitesse homogène avec le moteur horaire au lieu de dépendre des
// vitesses configurées sur les différents serveurs OSRM.
const WALK_SPEED_MPS = 1.35;
// Les passages Naolib évoluent chaque minute : un cache court garde les
// recalculs instantanés sans figer une correspondance devenue obsolète.
const ROUTE_CACHE_TTL_MS = 60 * 1000;
const PREVIEW_CACHE_TTL_MS = 5 * 60 * 1000;
const WALK_CACHE_TTL_MS = 10 * 60 * 1000;
const MAX_ROUTE_CACHE_ENTRIES = 200;
const MAX_OSRM_WAYPOINTS = 24;

type OsrmSegment = {
  coordinates: [number, number][];
  distance: number;
  duration: number;
};
type CacheEntry<T> = { expiresAt: number; promise: Promise<T> };
type TransitSkeleton = {
  id: string;
  route_ids: string[];
  summary: string;
  transfers: number;
  provisional: true;
};
type TransitSkeletonResult = {
  suggestions: TransitSkeleton[];
  engine: "skeleton";
};
type TransitRouteCacheValue =
  Awaited<ReturnType<typeof computeTransitRoute>> | TransitSkeletonResult;

const transitRouteCache = new Map<string, CacheEntry<TransitRouteCacheValue>>();
const walkingSegmentCache = new Map<string, CacheEntry<OsrmSegment>>();

function cached<T>(
  cache: Map<string, CacheEntry<T>>,
  key: string,
  ttlMs: number,
  loader: () => Promise<T>,
): { hit: boolean; promise: Promise<T> } {
  const now = Date.now();
  const existing = cache.get(key);
  if (existing && existing.expiresAt > now)
    return { hit: true, promise: existing.promise };
  if (existing) cache.delete(key);

  if (cache.size >= MAX_ROUTE_CACHE_ENTRIES) {
    const oldestKey = cache.keys().next().value as string | undefined;
    if (oldestKey) cache.delete(oldestKey);
  }

  const promise = loader().catch((error) => {
    cache.delete(key);
    throw error;
  });
  cache.set(key, { expiresAt: now + ttlMs, promise });
  return { hit: false, promise };
}

function coordKey(point: [number, number]): string {
  return `${point[0].toFixed(5)},${point[1].toFixed(5)}`;
}

// Deux recherches effectuées à quelques mètres d'écart doivent partager le
// même calcul lourd. Les segments OSRM conservent, eux, leur clé plus précise.
function routeCoordKey(point: [number, number]): string {
  return `${point[0].toFixed(4)},${point[1].toFixed(4)}`;
}

function successResponse(
  data: unknown,
  startedAt: number,
  cacheStatus = "miss",
  phaseTimings?: Map<string, number>,
) {
  const serverTiming = [
    `route;dur=${Date.now() - startedAt}`,
    ...[...(phaseTimings ?? [])].map(
      ([name, duration]) => `${name};dur=${duration}`,
    ),
  ].join(", ");
  return NextResponse.json(data, {
    headers: {
      "Cache-Control": "private, max-age=15, stale-while-revalidate=45",
      "Server-Timing": serverTiming,
      "X-Route-Cache": cacheStatus,
    },
  });
}

function parseCoord(raw: string | null): [number, number] | null {
  if (!raw) return null;
  const [lng, lat] = raw.split(",").map((v) => Number(v.trim()));
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return [lng, lat];
}

function parseMode(
  raw: string | null,
): EditorTransportMode | "foot" | "car" | "transit" {
  if (
    raw === "tram" ||
    raw === "boat" ||
    raw === "shuttle" ||
    raw === "foot" ||
    raw === "car" ||
    raw === "transit"
  ) {
    return raw;
  }
  return "bus";
}

function parseBoolean(raw: string | null, fallback: boolean): boolean {
  if (raw == null) return fallback;
  return raw === "1" || raw === "true";
}

function parseClampedInteger(
  raw: string | null,
  fallback: number,
  min: number,
  max: number,
): number {
  const value = raw == null ? Number.NaN : Number(raw);
  return Number.isInteger(value)
    ? Math.min(max, Math.max(min, value))
    : fallback;
}

function parseDepartureAt(raw: string | null): Date | undefined {
  if (!raw) return undefined;
  const date = new Date(raw);
  return Number.isNaN(date.getTime()) ? undefined : date;
}

async function fetchOsrmSegment(
  profile: "driving" | "foot",
  from: [number, number],
  to: [number, number],
): Promise<OsrmSegment> {
  return fetchOsrmPolyline(profile, [from, to]);
}

function sampleWaypoints(coordinates: [number, number][]): [number, number][] {
  const unique = coordinates.filter(
    (coordinate, index) =>
      index === 0 || coordKey(coordinate) !== coordKey(coordinates[index - 1]),
  );
  if (unique.length <= MAX_OSRM_WAYPOINTS) return unique;

  return Array.from({ length: MAX_OSRM_WAYPOINTS }, (_, index) => {
    const sourceIndex = Math.round(
      (index * (unique.length - 1)) / (MAX_OSRM_WAYPOINTS - 1),
    );
    return unique[sourceIndex];
  });
}

async function fetchOsrmPolyline(
  profile: "driving" | "foot",
  coordinates: [number, number][],
): Promise<OsrmSegment> {
  const waypoints = sampleWaypoints(coordinates);
  if (waypoints.length < 2)
    throw new Error("Tracé insuffisant pour le routage");

  const key = `${profile}:${waypoints.map(coordKey).join(";")}`;
  return cached(walkingSegmentCache, key, WALK_CACHE_TTL_MS, async () => {
    const baseUrl = profile === "foot" ? OSRM_WALKING_BASE : OSRM_DRIVING_BASE;
    const coordinatePath = waypoints
      .map(([lng, lat]) => `${lng},${lat}`)
      .join(";");
    const url = `${baseUrl}/${coordinatePath}?overview=full&geometries=geojson&continue_straight=true`;
    let res: Response;
    try {
      res = await fetch(url, { signal: AbortSignal.timeout(3500) });
    } catch {
      throw new Error("Service de routage indisponible");
    }
    if (!res.ok) {
      throw new Error("Service de routage indisponible");
    }

    const data = (await res.json()) as {
      code?: string;
      routes?: Array<{
        geometry?: { coordinates?: [number, number][] };
        distance?: number;
        duration?: number;
      }>;
    };

    const routeResult = data.routes?.[0];
    const coordinates = routeResult?.geometry?.coordinates;
    if (data.code !== "Ok" || !coordinates?.length) {
      throw new Error("Aucun itinéraire trouvé entre ces deux points");
    }

    const distance = routeResult?.distance ?? 0;
    return {
      coordinates,
      distance,
      duration:
        profile === "foot"
          ? distance / WALK_SPEED_MPS
          : (routeResult?.duration ?? 0),
    };
  }).promise;
}

async function fetchTramSegment(
  from: [number, number],
  to: [number, number],
  lineId: string | undefined,
): Promise<[number, number][]> {
  const shapes = await loadGtfsShapesForLine(lineId);
  const segment = routeAlongShapes(shapes, from, to);

  if (!segment || segment.length < 2) {
    throw new Error(
      "Aucun tracé tramway GTFS trouvé près de ces points — vérifiez le positionnement des arrêts",
    );
  }

  return segment;
}

export async function GET(request: Request) {
  const startedAt = Date.now();
  const { searchParams } = new URL(request.url);
  const from = parseCoord(searchParams.get("from"));
  const to = parseCoord(searchParams.get("to"));
  const mode = parseMode(searchParams.get("mode"));
  const lineId = searchParams.get("lineId")?.trim() || undefined;

  if (!from || !to) {
    return NextResponse.json(
      { error: "Coordonnées de départ ou d'arrivée invalides" },
      { status: 400 },
    );
  }

  try {
    if (mode === "tram") {
      const coordinates = await fetchTramSegment(from, to, lineId);
      return successResponse({ coordinates }, startedAt);
    }

    if (mode === "transit") {
      const algorithmVersion = searchParams.get("v")?.trim() || "default";
      const preview = parseBoolean(searchParams.get("preview"), false);
      const wheelchair = parseBoolean(searchParams.get("accessible"), false);
      const avoidDisruptions = parseBoolean(
        searchParams.get("avoidDisruptions"),
        true,
      );
      const maxTransfers = parseClampedInteger(
        searchParams.get("maxTransfers"),
        2,
        0,
        2,
      );
      const departureAt = parseDepartureAt(searchParams.get("departureAt"));
      const departureKey = departureAt
        ? departureAt.toISOString().slice(0, 19)
        : "now";
      const cacheKey = [
        algorithmVersion,
        preview ? "preview" : "complete",
        routeCoordKey(from),
        routeCoordKey(to),
        departureKey,
        wheelchair ? "accessible" : "standard",
        avoidDisruptions ? "avoid-alerts" : "allow-alerts",
        `t${maxTransfers}`,
      ].join(":");
      const phaseTimings = new Map<string, number>();
      const cachedRoute = cached(
        transitRouteCache,
        cacheKey,
        preview ? PREVIEW_CACHE_TTL_MS : ROUTE_CACHE_TTL_MS,
        async () => {
          if (preview) {
            const supabase = createAdminClient();
            if (!supabase)
              throw new Error("Aperçu des itinéraires indisponible");
            const previewStartedAt = Date.now();
            const { data, error } = await supabase.rpc(
              "plan_transit_route_skeletons",
              {
                p_from_lng: from[0],
                p_from_lat: from[1],
                p_to_lng: to[0],
                p_to_lat: to[1],
                p_departure_at:
                  departureAt?.toISOString() ?? new Date().toISOString(),
                p_max_transfers: maxTransfers,
                p_limit: 10,
              },
            );
            phaseTimings.set("skeletons", Date.now() - previewStartedAt);
            if (error)
              throw new Error(
                `Aperçu des itinéraires impossible: ${error.message}`,
              );
            return {
              suggestions: Array.isArray(data)
                ? (data as TransitSkeleton[])
                : [],
              engine: "skeleton" as const,
            };
          }
          const timetable = await computeTimetableTransitRoute(
            from,
            to,
            {
              departureAt,
              maxTransfers,
              wheelchair,
              avoidDisruptions,
              limit: 4,
              fetchWalkSegment: (a, b) => fetchOsrmSegment("foot", a, b),
              fetchTransitSegment: (coordinates, mode) =>
                mode === "bus"
                  ? fetchOsrmPolyline("driving", coordinates).then(
                      (segment) => segment.coordinates,
                    )
                  : Promise.resolve(coordinates),
            },
            (name, duration) => phaseTimings.set(name, duration),
          );
          if (timetable) return timetable;
          const heuristic = await computeTransitRoute(
            from,
            to,
            (a, b) => fetchOsrmSegment("foot", a, b),
            (name, duration) => phaseTimings.set(name, duration),
          );
          return { ...heuristic, engine: "heuristic" as const };
        },
      );
      const result = await cachedRoute.promise;
      return successResponse(
        result,
        startedAt,
        cachedRoute.hit ? "hit" : "miss",
        phaseTimings,
      );
    }

    const segment = await fetchOsrmSegment(
      mode === "foot" ? "foot" : "driving",
      from,
      to,
    );
    return successResponse(segment, startedAt);
  } catch (err) {
    const message =
      err instanceof Error
        ? err.message
        : "Erreur lors du calcul de l'itinéraire";
    const status = message.includes("indisponible") ? 502 : 404;
    return NextResponse.json(
      { error: message },
      {
        status,
        headers: {
          "Cache-Control": "no-store",
          "Server-Timing": `route;dur=${Date.now() - startedAt}`,
        },
      },
    );
  }
}
