import { createClient } from "@/lib/supabase/server";
import { pointCoordinates } from "@/lib/geo";
import { routeAlongShapes } from "@/lib/shape-route";
import {
  fetchNaolibDepartures,
  nextDepartureWaitSeconds,
  type RealtimeStopPassage,
} from "@/lib/carte-immersive/naolib-realtime";

const MAX_SHAPES = 24;
const MAX_POINTS_PER_SHAPE = 4000;
const NEARBY_RADIUS_M = 900;
const MAX_CANDIDATE_STOPS = 10;
// Les quais d'un même pôle sont stockés comme des arrêts distincts. À Ranzay,
// le quai du tram 1 n'est que le 4e arrêt le plus proche : limiter à trois
// supprimait donc le meilleur itinéraire avant même de le comparer.
const MAX_TRANSFER_ORIGIN_STOPS = 10;
const MAX_DOWNSTREAM_STOPS = 30;
const QUERY_CONCURRENCY = 12;
const STATIC_CACHE_TTL_MS = 5 * 60 * 1000;
const MAX_STATIC_CACHE_ENTRIES = 800;

export type TransitVehicleTracking = {
  departureId: string;
  profileId: string;
  serviceDate: string;
  line: string;
  routeId: string;
  direction: string;
  vehicleType: "bus" | "tram";
};
export type TransitStep = {
  icon: string;
  label: string;
  detail: string;
  duration: string;
  tracking?: TransitVehicleTracking;
};
export type TransitRouteSegment = {
  coordinates: [number, number][];
  color: string;
  routeId?: string;
  type: "walk" | "transit";
};
export type TransitAlert = {
  id: string;
  title: string;
  message: string;
  type: string;
  severity: string;
  source: string;
};
export type TransitAlternative = {
  id: string;
  coordinates: [number, number][];
  segments?: TransitRouteSegment[];
  distance: number;
  duration: number;
  departureAt?: string;
  arrivalAt?: string;
  steps: TransitStep[];
  routeIds: string[];
  transfers: number;
  walkSeconds?: number;
  waitSeconds?: number;
  alertPenaltySeconds?: number;
  accessible: boolean;
  alerts: TransitAlert[];
  summary: string;
};
export type TransitResult = {
  coordinates: [number, number][];
  segments?: TransitRouteSegment[];
  distance: number;
  duration: number;
  departureAt?: string;
  arrivalAt?: string;
  steps: TransitStep[];
  alternatives?: TransitAlternative[];
  departures?: TransitAlternative[];
  engine?: "timetable" | "heuristic";
};

type NearbyStop = {
  stop_id: string;
  stop_code: string;
  stop_name: string;
  distance_m: number;
  geom: unknown;
};

type ServingLine = {
  route_id: string;
  route_short_name: string | null;
  route_long_name: string | null;
  route_type: number | null;
  direction_id: number | null;
  trip_id: string | null;
  stop_sequence: number | null;
  arrival_time: string | null;
  time_from_terminus_seconds: number | null;
};

type DownstreamStop = { gtfsStopId: string; stopSequence: number };
type CacheEntry<T> = { expiresAt: number; promise: Promise<T> };

const servingLinesCache = new Map<string, CacheEntry<ServingLine[]>>();
const downstreamStopsCache = new Map<string, CacheEntry<DownstreamStop[]>>();
const stopMappingCache = new Map<string, CacheEntry<Map<string, string>>>();
const mappedRouteIdsCache = new Map<string, CacheEntry<Map<string, Set<string>>>>();
const shapeIdByTripCache = new Map<string, CacheEntry<string | null>>();
const shapePointsCache = new Map<string, CacheEntry<[number, number][]>>();
const routeShapesCache = new Map<string, CacheEntry<[number, number][][]>>();

function cached<T>(
  cache: Map<string, CacheEntry<T>>,
  key: string,
  loader: () => Promise<T>,
): Promise<T> {
  const now = Date.now();
  const existing = cache.get(key);
  if (existing && existing.expiresAt > now) return existing.promise;
  if (existing) cache.delete(key);

  if (cache.size >= MAX_STATIC_CACHE_ENTRIES) {
    for (const [candidateKey, entry] of cache) {
      if (entry.expiresAt <= now || cache.size >= MAX_STATIC_CACHE_ENTRIES) {
        cache.delete(candidateKey);
      }
      if (cache.size < MAX_STATIC_CACHE_ENTRIES) break;
    }
  }

  const promise = loader().catch((error) => {
    cache.delete(key);
    throw error;
  });
  cache.set(key, { expiresAt: now + STATIC_CACHE_TTL_MS, promise });
  return promise;
}

async function mapWithConcurrency<T, R>(
  items: T[],
  limit: number,
  mapper: (item: T) => Promise<R>,
): Promise<R[]> {
  const results = new Array<R>(items.length);
  let cursor = 0;

  async function worker() {
    while (cursor < items.length) {
      const index = cursor++;
      results[index] = await mapper(items[index]);
    }
  }

  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, () => worker()),
  );
  return results;
}

function chunkItems<T>(items: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let index = 0; index < items.length; index += size) {
    chunks.push(items.slice(index, index + size));
  }
  return chunks;
}

function distanceLabel(meters: number): string {
  return meters >= 1000 ? `${(meters / 1000).toFixed(1)} km` : `${Math.round(meters)} m`;
}

function durationLabel(seconds: number): string {
  return `${Math.max(1, Math.round(seconds / 60))} min`;
}

function haversineMeters(a: [number, number], b: [number, number]): number {
  const R = 6371000;
  const toRad = (v: number) => (v * Math.PI) / 180;
  const dLat = toRad(b[1] - a[1]);
  const dLng = toRad(b[0] - a[0]);
  const lat1 = toRad(a[1]);
  const lat2 = toRad(b[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// La base GTFS ne contient qu'un horaire de référence par (arrêt, ligne), pas le programme complet
// du jour : impossible d'en déduire un "prochain passage" fiable. On estime donc l'attente via une
// fréquence moyenne par mode plutôt que d'afficher un horaire qui peut être à des heures de distance.
const AVG_WAIT_SECONDS: Record<"tram" | "bus", number> = { tram: 3 * 60, bus: 5 * 60 };
const WALKING_SPEED_MPS = 1.35;
const WALKING_DETOUR_FACTOR = 1.3;

function remainingWaitSeconds(baseWaitSeconds: number, accessDurationSeconds: number): number {
  return Math.max(0, baseWaitSeconds - accessDurationSeconds);
}

function estimatedWalkSeconds(distanceMeters: number): number {
  return (distanceMeters * WALKING_DETOUR_FACTOR) / WALKING_SPEED_MPS;
}

function estimatedRideSecondsForScore(
  line: ServingLine,
  from: [number, number],
  to: [number, number],
): number {
  const distance = haversineMeters(from, to);
  const shortName = (line.route_short_name ?? "").toUpperCase();
  const speedKmh = line.route_type === 0 ? 24 : /^[BC]\d+$/.test(shortName) ? 21 : 18;
  return Math.max(60, (distance / (speedKmh * 1000)) * 3600);
}

function estimatedFirstLegSeconds(
  line: ServingLine,
  accessDistanceMeters: number,
  from: [number, number],
  to: [number, number],
): number {
  const walk = estimatedWalkSeconds(accessDistanceMeters);
  const wait = remainingWaitSeconds(
    AVG_WAIT_SECONDS[line.route_type === 0 ? "tram" : "bus"],
    walk,
  );
  return walk + wait + estimatedRideSecondsForScore(line, from, to);
}

function estimatedSecondLegSeconds(
  line: ServingLine,
  transferWalkMeters: number,
  from: [number, number],
  to: [number, number],
): number {
  const walk = estimatedWalkSeconds(transferWalkMeters);
  // Sans horaire de correspondance confirmé, la marche ne garantit pas que le
  // véhicule suivant sera présent à l'arrivée. Conserver l'attente moyenne
  // évite les raccords artificiels à zéro minute qui sous-estimaient le trajet.
  const wait = AVG_WAIT_SECONDS[line.route_type === 0 ? "tram" : "bus"];
  return walk + wait + estimatedRideSecondsForScore(line, from, to);
}

/**
 * Estime le temps à bord entre deux points d'une même ligne. La chronologie GTFS
 * (time_from_terminus_seconds) est parfois incohérente sur ce jeu de données partiel : on ne
 * l'utilise que si elle implique une vitesse plausible (5 à 60 km/h), sinon on retombe sur une
 * estimation par distance à vol d'oiseau à 18 km/h.
 */
function estimateInVehicleSeconds(
  boardSeconds: number | null,
  alightSeconds: number | null,
  straightDistanceMeters: number,
): number {
  const speedEstimate = Math.max(60, (straightDistanceMeters / (18 * 1000)) * 3600);
  if (boardSeconds == null || alightSeconds == null) return speedEstimate;
  const delta = alightSeconds - boardSeconds;
  if (delta <= 0) return speedEstimate;
  const impliedKmh = straightDistanceMeters / 1000 / (delta / 3600);
  return impliedKmh >= 5 && impliedKmh <= 60 ? delta : speedEstimate;
}

async function fetchNearbyStops(
  supabase: Awaited<ReturnType<typeof createClient>>,
  point: [number, number],
): Promise<NearbyStop[]> {
  const { data, error } = await supabase.rpc("get_nearby_stops", {
    p_lng: point[0],
    p_lat: point[1],
    p_radius_m: NEARBY_RADIUS_M,
    p_audience: "passenger",
  });
  if (error) throw new Error(`Recherche des arrêts impossible: ${error.message}`);
  return ((data as NearbyStop[]) ?? []).slice(0, MAX_CANDIDATE_STOPS);
}

async function fetchServingLines(
  supabase: Awaited<ReturnType<typeof createClient>>,
  stopId: string,
): Promise<ServingLine[]> {
  return cached(servingLinesCache, stopId, async () => {
    const { data, error } = await supabase.rpc("get_stop_serving_lines", { p_stop_id: stopId });
    if (error) throw new Error(`Lignes de l'arrêt introuvables: ${error.message}`);
    return (data as ServingLine[]) ?? [];
  });
}

async function fetchServingLinesForStops(
  supabase: Awaited<ReturnType<typeof createClient>>,
  stopIds: string[],
): Promise<Map<string, ServingLine[]>> {
  const uniqueStopIds = [...new Set(stopIds)];
  const result = new Map<string, ServingLine[]>();
  const missing: string[] = [];
  const now = Date.now();

  await Promise.all(
    uniqueStopIds.map(async (stopId) => {
      const existing = servingLinesCache.get(stopId);
      if (existing && existing.expiresAt > now) {
        result.set(stopId, await existing.promise);
      } else {
        if (existing) servingLinesCache.delete(stopId);
        missing.push(stopId);
      }
    }),
  );
  if (!missing.length) return result;

  const mappingGroups = await mapWithConcurrency(
    chunkItems(missing, 80),
    QUERY_CONCURRENCY,
    async (ids) => {
      const { data, error } = await supabase
        .from("gtfs_stop_mapping")
        .select("stop_id, gtfs_stop_id")
        .in("stop_id", ids);
      if (error) throw new Error(`Correspondance GTFS inverse impossible: ${error.message}`);
      return data ?? [];
    },
  );
  const mappings = mappingGroups.flat();
  const uuidByGtfsId = new Map(
    mappings.map((row) => [row.gtfs_stop_id as string, row.stop_id as string]),
  );
  const gtfsStopIds = [...uuidByGtfsId.keys()];

  const stopTimeGroups = await mapWithConcurrency(
    // PostgREST limite une réponse à 1000 lignes : des groupes de 80 arrêts
    // tronquaient silencieusement certaines dessertes (notamment 75 → 86).
    chunkItems(gtfsStopIds, 20),
    QUERY_CONCURRENCY,
    async (ids) => {
      const { data, error } = await supabase
        .from("gtfs_stop_times")
        .select("stop_id, trip_id, stop_sequence, arrival_time")
        .in("stop_id", ids);
      if (error) throw new Error(`Dessertes GTFS introuvables: ${error.message}`);
      return data ?? [];
    },
  );
  const stopTimes = stopTimeGroups.flat();
  const tripIds = [...new Set(stopTimes.map((row) => row.trip_id as string))];
  const tripGroups = await mapWithConcurrency(
    chunkItems(tripIds, 80),
    QUERY_CONCURRENCY,
    async (ids) => {
      const { data, error } = await supabase
        .from("gtfs_trips")
        .select("trip_id, route_id, direction_id")
        .in("trip_id", ids);
      if (error) throw new Error(`Courses GTFS introuvables: ${error.message}`);
      return data ?? [];
    },
  );
  const trips = tripGroups.flat();
  const tripById = new Map(trips.map((trip) => [trip.trip_id as string, trip]));
  const routeIds = [...new Set(trips.map((trip) => trip.route_id as string))];
  const routeGroups = await mapWithConcurrency(
    chunkItems(routeIds, 80),
    QUERY_CONCURRENCY,
    async (ids) => {
      const { data, error } = await supabase
        .from("gtfs_routes")
        .select("route_id, route_short_name, route_long_name, route_type")
        .in("route_id", ids);
      if (error) throw new Error(`Lignes GTFS introuvables: ${error.message}`);
      return data ?? [];
    },
  );
  const routeById = new Map(
    routeGroups.flat().map((route) => [route.route_id as string, route]),
  );

  const builtLinesByStop = new Map<string, ServingLine[]>();
  for (const stopTime of stopTimes) {
    const stopUuid = uuidByGtfsId.get(stopTime.stop_id as string);
    const trip = tripById.get(stopTime.trip_id as string);
    const route = trip ? routeById.get(trip.route_id as string) : null;
    if (!stopUuid || !trip || !route) continue;
    const directionId = (trip.direction_id as number | null | undefined) ?? null;
    const candidate: ServingLine = {
      route_id: route.route_id as string,
      route_short_name: (route.route_short_name as string | null | undefined) ?? null,
      route_long_name: (route.route_long_name as string | null | undefined) ?? null,
      route_type: (route.route_type as number | null | undefined) ?? null,
      direction_id: directionId,
      trip_id: trip.trip_id as string,
      stop_sequence: stopTime.stop_sequence as number,
      arrival_time: (stopTime.arrival_time as string | null | undefined) ?? null,
      time_from_terminus_seconds: null,
    };
    const lines = builtLinesByStop.get(stopUuid) ?? [];
    if (!lines.some((line) => line.trip_id === candidate.trip_id)) lines.push(candidate);
    builtLinesByStop.set(stopUuid, lines);
  }

  for (const stopId of missing) {
    const lines = builtLinesByStop.get(stopId) ?? [];
    if (lines.length) {
      const promise = Promise.resolve(lines);
      servingLinesCache.set(stopId, { expiresAt: now + STATIC_CACHE_TTL_MS, promise });
      result.set(stopId, lines);
    }
  }

  const fallbackStopIds = missing.filter((stopId) => !result.has(stopId));
  const fallbackEntries = await mapWithConcurrency(
    fallbackStopIds,
    QUERY_CONCURRENCY,
    async (stopId) => [stopId, await fetchServingLines(supabase, stopId)] as const,
  );
  for (const [stopId, lines] of fallbackEntries) result.set(stopId, lines);
  return result;
}

async function fetchDownstreamStops(
  supabase: Awaited<ReturnType<typeof createClient>>,
  tripId: string,
  fromSeq: number,
): Promise<DownstreamStop[]> {
  return cached(downstreamStopsCache, `${tripId}:${fromSeq}`, async () => {
    const { data, error } = await supabase
      .from("gtfs_stop_times")
      .select("stop_id, stop_sequence")
      .eq("trip_id", tripId)
      .gt("stop_sequence", fromSeq)
      .order("stop_sequence")
      .limit(MAX_DOWNSTREAM_STOPS);
    if (error) throw new Error(`Arrêts suivants introuvables: ${error.message}`);
    return (data ?? []).map((r) => ({
      gtfsStopId: r.stop_id as string,
      stopSequence: r.stop_sequence as number,
    }));
  });
}

async function mapGtfsIdsToUuidStops(
  supabase: Awaited<ReturnType<typeof createClient>>,
  gtfsIds: string[],
): Promise<Map<string, string>> {
  if (!gtfsIds.length) return new Map();
  const key = [...new Set(gtfsIds)].sort().join("|");
  return cached(stopMappingCache, key, async () => {
    const { data, error } = await supabase
      .from("gtfs_stop_mapping")
      .select("stop_id, gtfs_stop_id")
      .in("gtfs_stop_id", gtfsIds);
    if (error) throw new Error(`Correspondance des arrêts impossible: ${error.message}`);
    const map = new Map<string, string>();
    for (const row of data ?? []) map.set(row.gtfs_stop_id as string, row.stop_id as string);
    return map;
  });
}

async function fetchMappedRouteIdsByStops(
  supabase: Awaited<ReturnType<typeof createClient>>,
  stopUuids: string[],
): Promise<Map<string, Set<string>>> {
  if (!stopUuids.length) return new Map();
  const key = [...new Set(stopUuids)].sort().join("|");
  return cached(mappedRouteIdsCache, key, async () => {
    const mappingGroups = await mapWithConcurrency(
      chunkItems([...new Set(stopUuids)], 80),
      QUERY_CONCURRENCY,
      async (ids) => {
        const { data, error } = await supabase
          .from("gtfs_stop_mapping")
          .select("stop_id, gtfs_stop_id")
          .in("stop_id", ids);
        if (error) throw new Error(`Correspondance GTFS inverse impossible: ${error.message}`);
        return data ?? [];
      },
    );
    const mappings = mappingGroups.flat();
    const uuidByGtfsId = new Map(
      mappings.map((row) => [row.gtfs_stop_id as string, row.stop_id as string]),
    );
    const gtfsStopIds = [...uuidByGtfsId.keys()];
    if (!gtfsStopIds.length) return new Map();

    const stopTimeGroups = await mapWithConcurrency(
      chunkItems(gtfsStopIds, 20),
      QUERY_CONCURRENCY,
      async (ids) => {
        const { data, error } = await supabase
          .from("gtfs_stop_times")
          .select("stop_id, trip_id")
          .in("stop_id", ids);
        if (error) throw new Error(`Dessertes GTFS introuvables: ${error.message}`);
        return data ?? [];
      },
    );
    const stopTimes = stopTimeGroups.flat();
    const tripIds = [...new Set(stopTimes.map((row) => row.trip_id as string))];
    if (!tripIds.length) return new Map();

    const tripGroups = await mapWithConcurrency(
      chunkItems(tripIds, 80),
      QUERY_CONCURRENCY,
      async (ids) => {
        const { data, error } = await supabase
          .from("gtfs_trips")
          .select("trip_id, route_id")
          .in("trip_id", ids);
        if (error) throw new Error(`Lignes GTFS introuvables: ${error.message}`);
        return data ?? [];
      },
    );
    const routeByTrip = new Map(
      tripGroups.flat().map((row) => [row.trip_id as string, row.route_id as string]),
    );
    const routesByStop = new Map<string, Set<string>>();
    for (const stopTime of stopTimes) {
      const stopUuid = uuidByGtfsId.get(stopTime.stop_id as string);
      const routeId = routeByTrip.get(stopTime.trip_id as string);
      if (!stopUuid || !routeId) continue;
      const routes = routesByStop.get(stopUuid) ?? new Set<string>();
      routes.add(routeId);
      routesByStop.set(stopUuid, routes);
    }
    return routesByStop;
  });
}

async function loadShapePoints(
  supabase: Awaited<ReturnType<typeof createClient>>,
  shapeId: string,
): Promise<[number, number][]> {
  return cached(shapePointsCache, shapeId, async () => {
    const { data, error } = await supabase
      .from("gtfs_shapes")
      .select("shape_pt_sequence, geom")
      .eq("shape_id", shapeId)
      .order("shape_pt_sequence")
      .limit(MAX_POINTS_PER_SHAPE);
    if (error) throw new Error(`Tracé GTFS introuvable: ${error.message}`);
    return (data ?? [])
      .map((row) => pointCoordinates(row.geom))
      .filter((coords): coords is [number, number] => coords != null);
  });
}

async function loadShapesForRoute(
  supabase: Awaited<ReturnType<typeof createClient>>,
  routeId: string,
): Promise<[number, number][][]> {
  return cached(routeShapesCache, routeId, async () => {
    const { data: trips, error } = await supabase
      .from("gtfs_trips")
      .select("shape_id")
      .eq("route_id", routeId)
      .not("shape_id", "is", null)
      .limit(MAX_SHAPES);
    if (error) throw new Error(`Tracés de la ligne introuvables: ${error.message}`);

    const shapeIds = [
      ...new Set((trips ?? []).map((trip) => trip.shape_id as string | null).filter((id): id is string => Boolean(id))),
    ];
    const shapes = await mapWithConcurrency(shapeIds, QUERY_CONCURRENCY, (shapeId) =>
      loadShapePoints(supabase, shapeId),
    );
    return shapes.filter((shape) => shape.length >= 2);
  });
}

async function loadShapesForServingLine(
  supabase: Awaited<ReturnType<typeof createClient>>,
  line: ServingLine,
): Promise<[number, number][][]> {
  if (!line.trip_id) return loadShapesForRoute(supabase, line.route_id);

  const shapeId = await cached(shapeIdByTripCache, line.trip_id, async () => {
    const { data, error } = await supabase
      .from("gtfs_trips")
      .select("shape_id")
      .eq("trip_id", line.trip_id!)
      .maybeSingle();
    if (error) throw new Error(`Trajet GTFS introuvable: ${error.message}`);
    return (data?.shape_id as string | null | undefined) ?? null;
  });

  if (!shapeId) return loadShapesForRoute(supabase, line.route_id);
  const shape = await loadShapePoints(supabase, shapeId);
  return shape.length >= 2 ? [shape] : loadShapesForRoute(supabase, line.route_id);
}

type DirectMatch = {
  originStop: NearbyStop;
  destStop: NearbyStop;
  originLine: ServingLine;
  destLine: ServingLine;
  score: number;
};

async function findDirectMatch(
  originStops: NearbyStop[],
  destStops: NearbyStop[],
  originLinesByStop: Map<string, ServingLine[]>,
  destLinesByStop: Map<string, ServingLine[]>,
): Promise<DirectMatch | null> {
  const candidates: DirectMatch[] = [];

  for (const originStop of originStops) {
    const originLines = originLinesByStop.get(originStop.stop_id) ?? [];
    for (const destStop of destStops) {
      if (originStop.stop_id === destStop.stop_id) continue;
      const destLines = destLinesByStop.get(destStop.stop_id) ?? [];

      for (const originLine of originLines) {
        for (const destLine of destLines) {
          if (originLine.route_id !== destLine.route_id) continue;
          if (originLine.direction_id !== destLine.direction_id) continue;
          if (
            originLine.stop_sequence != null &&
            destLine.stop_sequence != null &&
            originLine.stop_sequence >= destLine.stop_sequence
          ) {
            continue;
          }

          const originCoords = pointCoordinates(originStop.geom);
          const destCoords = pointCoordinates(destStop.geom);
          if (!originCoords || !destCoords) continue;
          const score =
            estimatedFirstLegSeconds(
              originLine,
              originStop.distance_m,
              originCoords,
              destCoords,
            ) + estimatedWalkSeconds(destStop.distance_m);
          candidates.push({ originStop, destStop, originLine, destLine, score });
        }
      }
    }
  }

  if (!candidates.length) return null;

  // Le score géométrique sert à réduire le nombre d'appels. Les meilleurs
  // candidats sont ensuite reclassés avec le prochain passage Naolib afin de
  // ne pas choisir un quai plus lointain uniquement sur une moyenne théorique.
  const finalists = candidates.sort((a, b) => a.score - b.score).slice(0, 8);
  const stopNames = [...new Set(finalists.map((candidate) => candidate.originStop.stop_name))];
  const departuresByStop = new Map(
    await Promise.all(
      stopNames.map(async (stopName) => [stopName, await safeNaolibDepartures(stopName)] as const),
    ),
  );

  let best: DirectMatch | null = null;
  for (const candidate of finalists) {
    const originCoords = pointCoordinates(candidate.originStop.geom);
    const destCoords = pointCoordinates(candidate.destStop.geom);
    if (!originCoords || !destCoords) continue;
    const accessSeconds = estimatedWalkSeconds(candidate.originStop.distance_m);
    const fallbackWait = remainingWaitSeconds(
      AVG_WAIT_SECONDS[candidate.originLine.route_type === 0 ? "tram" : "bus"],
      accessSeconds,
    );
    const passages = departuresByStop.get(candidate.originStop.stop_name) ?? [];
    const liveTiming = nextDepartureWaitSeconds(
      passages,
      candidate.originLine.route_short_name ?? candidate.originLine.route_id,
      null,
      new Date(Date.now() + accessSeconds * 1000),
    );
    const timing = liveTiming ?? { waitSeconds: fallbackWait, realtime: false };
    const score =
      accessSeconds +
      timing.waitSeconds +
      estimatedRideSecondsForScore(candidate.originLine, originCoords, destCoords) +
      estimatedWalkSeconds(candidate.destStop.distance_m);
    if (!best || score < best.score) best = { ...candidate, score };
  }
  return best ?? finalists[0];
}

type TransferMatch = {
  originStop: NearbyStop;
  destStop: NearbyStop;
  transferStopId: string;
  originLine: ServingLine;
  transferArriveLine: ServingLine;
  transferDepartLine: ServingLine;
  destLine: ServingLine;
  score: number;
};

async function findTransferMatch(
  supabase: Awaited<ReturnType<typeof createClient>>,
  originStops: NearbyStop[],
  destStops: NearbyStop[],
  originLinesByStop: Map<string, ServingLine[]>,
  destLinesByStop: Map<string, ServingLine[]>,
): Promise<TransferMatch | null> {
  const destByRouteDir = new Map<string, { destStop: NearbyStop; destLine: ServingLine }>();
  for (const destStop of destStops) {
    for (const destLine of destLinesByStop.get(destStop.stop_id) ?? []) {
      const key = `${destLine.route_id}:${destLine.direction_id}`;
      const existing = destByRouteDir.get(key);
      if (!existing || destStop.distance_m < existing.destStop.distance_m) {
        destByRouteDir.set(key, { destStop, destLine });
      }
    }
  }
  if (!destByRouteDir.size) return null;

  const probes = originStops
    .slice(0, MAX_TRANSFER_ORIGIN_STOPS)
    .flatMap((originStop) =>
      (originLinesByStop.get(originStop.stop_id) ?? [])
        .filter((originLine) => originLine.trip_id != null && originLine.stop_sequence != null)
        .map((originLine) => ({ originStop, originLine })),
    );

  const matches = await mapWithConcurrency(probes, QUERY_CONCURRENCY, async ({ originStop, originLine }) => {
    const downstream = await fetchDownstreamStops(
      supabase,
      originLine.trip_id!,
      originLine.stop_sequence!,
    );
    if (!downstream.length) return null;

    const uuidMap = await mapGtfsIdsToUuidStops(
      supabase,
      downstream.map((stop) => stop.gtfsStopId),
    );
    const transferUuids = [...new Set(uuidMap.values())].filter((id) => id !== originStop.stop_id);
    if (!transferUuids.length) return null;

    const routeIdsByStop = await fetchMappedRouteIdsByStops(supabase, transferUuids);
    const served = [...routeIdsByStop].flatMap(([stopId, routeIds]) =>
      [...routeIds].map((routeId) => ({ stop_id: stopId, route_id: routeId })),
    );
    const candidates = served.flatMap((row) => {
      if (row.route_id === originLine.route_id) return [];
      return [`${row.route_id}:0`, `${row.route_id}:1`]
        .map((key) => ({ row, destEntry: destByRouteDir.get(key) }))
        .filter(
          (candidate): candidate is {
            row: { stop_id: string; route_id: string };
            destEntry: { destStop: NearbyStop; destLine: ServingLine };
          } => candidate.destEntry != null,
        );
    });
    if (!candidates.length) return null;

    const transferStopIds = [...new Set(candidates.map(({ row }) => row.stop_id))];
    const [transferLinesByStop, transferStopsGeo] = await Promise.all([
      fetchServingLinesForStops(supabase, transferStopIds),
      fetchStopsByIds(supabase, transferStopIds),
    ]);

    let bestForProbe: TransferMatch | null = null;
    for (const { row, destEntry } of candidates) {
      const transferLines = transferLinesByStop.get(row.stop_id) ?? [];
      const arriveLine = transferLines.find(
        (line) => line.route_id === originLine.route_id && line.direction_id === originLine.direction_id,
      );
      const departLine = transferLines.find(
        (line) => line.route_id === destEntry.destLine.route_id && line.direction_id === destEntry.destLine.direction_id,
      );
      if (!departLine || departLine.stop_sequence == null || destEntry.destLine.stop_sequence == null) continue;
      if (departLine.stop_sequence >= destEntry.destLine.stop_sequence) continue;

      const originCoords = pointCoordinates(originStop.geom);
      const destCoords = pointCoordinates(destEntry.destStop.geom);
      const transferCoords = transferStopsGeo.get(row.stop_id)?.coords;
      if (!originCoords || !destCoords || !transferCoords) continue;
      const score =
        estimatedFirstLegSeconds(
          originLine,
          originStop.distance_m,
          originCoords,
          transferCoords,
        ) +
        estimatedSecondLegSeconds(
          destEntry.destLine,
          0,
          transferCoords,
          destCoords,
        ) +
        estimatedWalkSeconds(destEntry.destStop.distance_m);
      if (!bestForProbe || score < bestForProbe.score) {
        bestForProbe = {
          originStop,
          destStop: destEntry.destStop,
          transferStopId: row.stop_id,
          originLine,
          transferArriveLine: arriveLine ?? originLine,
          transferDepartLine: departLine,
          destLine: destEntry.destLine,
          score,
        };
      }
    }
    return bestForProbe;
  });

  return matches.reduce<TransferMatch | null>(
    (best, match) => (!match || (best && best.score <= match.score) ? best : match),
    null,
  );
}

// Rayon de correspondance à pied entre deux arrêts (mètres). Relie deux
// réseaux distincts (ex. TAN ↔ Aléop) dont les arrêts, même à un pôle
// d'échange commun, sont deux `stops` différents jamais réunis par
// findTransferMatch (qui exige un arrêt commun).
const WALK_TRANSFER_RADIUS_M = 500;
const MAX_WALK_TRANSFER_PROBES = 60;
const MAX_WALK_TRANSFER_PROBES_PER_ROUTE = 10;

type StopGeo = { name: string; coords: [number, number] };

async function fetchStopsByIds(
  supabase: Awaited<ReturnType<typeof createClient>>,
  ids: string[],
): Promise<Map<string, StopGeo>> {
  const map = new Map<string, StopGeo>();
  if (!ids.length) return map;
  const { data, error } = await supabase.from("stops").select("id, name, geom").in("id", ids);
  if (error) throw new Error(`Détails des arrêts introuvables: ${error.message}`);
  for (const row of data ?? []) {
    const coords = pointCoordinates(row.geom);
    if (coords) map.set(row.id as string, { name: (row.name as string) ?? "arrêt", coords });
  }
  return map;
}

type WalkingTransferMatch = {
  originStop: NearbyStop;
  destStop: NearbyStop;
  originLine: ServingLine;
  fromStop: StopGeo; // descente (ligne origine)
  toStop: StopGeo; // montée (ligne destination), à distance de marche
  departLine: ServingLine; // ligne destination vue à l'arrêt de montée
  destLine: ServingLine;
  walkMeters: number;
  score: number;
};

/**
 * Correspondance à pied entre réseaux : on descend d'une ligne (origine),
 * on marche jusqu'à un arrêt VOISIN — potentiellement d'un autre réseau —
 * qui dessert une ligne menant à destination. Complète findTransferMatch,
 * qui ne relie que des arrêts strictement identiques (donc jamais deux
 * réseaux). N'est tenté qu'en dernier recours (coûteux en requêtes).
 */
async function findWalkingTransferMatch(
  supabase: Awaited<ReturnType<typeof createClient>>,
  originStops: NearbyStop[],
  destStops: NearbyStop[],
  originLinesByStop: Map<string, ServingLine[]>,
  destLinesByStop: Map<string, ServingLine[]>,
): Promise<WalkingTransferMatch | null> {
  const destByRouteDir = new Map<string, { destStop: NearbyStop; destLine: ServingLine }>();
  for (const destStop of destStops) {
    for (const destLine of destLinesByStop.get(destStop.stop_id) ?? []) {
      const key = `${destLine.route_id}:${destLine.direction_id}`;
      const existing = destByRouteDir.get(key);
      if (!existing || destStop.distance_m < existing.destStop.distance_m) {
        destByRouteDir.set(key, { destStop, destLine });
      }
    }
  }
  if (!destByRouteDir.size) return null;

  // Point de descente candidat : arrêt en aval d'une ligne origine, d'où l'on
  // tentera de rejoindre à pied une ligne menant à destination.
  type AlightCandidate = { originStop: NearbyStop; originLine: ServingLine; alightId: string; from: StopGeo };
  const originProbes = originStops
    .slice(0, MAX_TRANSFER_ORIGIN_STOPS)
    .flatMap((originStop) =>
      (originLinesByStop.get(originStop.stop_id) ?? [])
        .filter((originLine) => originLine.trip_id != null && originLine.stop_sequence != null)
        .map((originLine) => ({ originStop, originLine })),
    );
  const candidateGroups = await mapWithConcurrency(
    originProbes,
    QUERY_CONCURRENCY,
    async ({ originStop, originLine }): Promise<AlightCandidate[]> => {
      const downstream = await fetchDownstreamStops(
        supabase,
        originLine.trip_id!,
        originLine.stop_sequence!,
      );
      if (!downstream.length) return [];
      const uuidMap = await mapGtfsIdsToUuidStops(supabase, downstream.map((stop) => stop.gtfsStopId));
      const alightIds = [...new Set(uuidMap.values())].filter((id) => id !== originStop.stop_id);
      const alightGeo = await fetchStopsByIds(supabase, alightIds);
      return [...alightGeo].map(([alightId, from]) => ({ originStop, originLine, alightId, from }));
    },
  );

  const candidates: AlightCandidate[] = [];
  const seenAlight = new Set<string>();
  for (const candidate of candidateGroups.flat()) {
    const key = `${candidate.originStop.stop_id}:${candidate.originLine.route_id}:${candidate.originLine.direction_id}:${candidate.alightId}`;
    if (seenAlight.has(key)) continue;
    seenAlight.add(key);
    candidates.push(candidate);
  }
  if (!candidates.length) return null;

  // On sonde en priorité les descentes les PLUS PROCHES de la destination : la
  // correspondance utile est là où les deux réseaux se croisent, souvent loin
  // de l'origine sur une longue ligne. Sans ce tri, le plafond de sondage
  // s'épuisait près de l'origine (asymétrie selon le sens du trajet).
  const destProxy =
    destStops.map((d) => pointCoordinates(d.geom)).find((c): c is [number, number] => c != null) ?? null;
  if (destProxy) {
    candidates.sort(
      (a, b) => haversineMeters(a.from.coords, destProxy) - haversineMeters(b.from.coords, destProxy),
    );
  }

  // Garder plusieurs lignes dans la recherche. Un simple `slice(0, 30)` était
  // saturé par les nombreux arrêts d'une seule ligne et pouvait éliminer 75 →
  // 86 avant toute comparaison avec 1 → 86.
  const probesByRoute = new Map<string, number>();
  const selectedCandidates: AlightCandidate[] = [];
  for (const candidate of candidates) {
    const routeKey = `${candidate.originLine.route_id}:${candidate.originLine.direction_id}`;
    const count = probesByRoute.get(routeKey) ?? 0;
    if (count >= MAX_WALK_TRANSFER_PROBES_PER_ROUTE) continue;
    probesByRoute.set(routeKey, count + 1);
    selectedCandidates.push(candidate);
    if (selectedCandidates.length >= MAX_WALK_TRANSFER_PROBES) break;
  }

  const nearbyGroups = await mapWithConcurrency(
    selectedCandidates,
    QUERY_CONCURRENCY,
    async (candidate) => {
      const { originStop, alightId, from } = candidate;
      const { data: nearby, error } = await supabase.rpc("get_nearby_stops", {
        p_lng: from.coords[0],
        p_lat: from.coords[1],
        p_radius_m: WALK_TRANSFER_RADIUS_M,
        p_audience: "passenger",
      });
      if (error) throw new Error(`Recherche de correspondance impossible: ${error.message}`);

      const nearbyStops = ((nearby as NearbyStop[]) ?? []).filter(
        (stop) => stop.stop_id !== alightId && stop.stop_id !== originStop.stop_id,
      );
      return { candidate, nearbyStops };
    },
  );

  const nearbyStopIds = [
    ...new Set(nearbyGroups.flatMap(({ nearbyStops }) => nearbyStops.map((stop) => stop.stop_id))),
  ];
  if (!nearbyStopIds.length) return null;

  // Des lectures GTFS groupées éliminent d'abord les arrêts qui ne desservent
  // aucune ligne de destination. Le RPC détaillé n'est ensuite appelé que pour
  // les quelques arrêts réellement prometteurs, au lieu de tous les voisins.
  const destRouteIds = new Set(
    [...destByRouteDir.values()].map(({ destLine }) => destLine.route_id),
  );
  const routeIdsByStop = await fetchMappedRouteIdsByStops(supabase, nearbyStopIds);
  const promisingStopIds = [
    ...routeIdsByStop.entries(),
  ]
    .filter(([, routeIds]) => [...routeIds].some((routeId) => destRouteIds.has(routeId)))
    .map(([stopId]) => stopId);
  if (!promisingStopIds.length) return null;

  const linesByStop = await fetchServingLinesForStops(supabase, promisingStopIds);

  const matchesByPath = new Map<string, WalkingTransferMatch>();
  const promisingStops = new Set(promisingStopIds);
  for (const { candidate, nearbyStops } of nearbyGroups) {
    const { originStop, originLine, from } = candidate;
    for (const candidateStop of nearbyStops) {
      if (!promisingStops.has(candidateStop.stop_id)) continue;
      for (const candidateLine of linesByStop.get(candidateStop.stop_id) ?? []) {
        if (candidateLine.route_id === originLine.route_id) continue;
        const destEntry =
          destByRouteDir.get(`${candidateLine.route_id}:${candidateLine.direction_id}`) ??
          destByRouteDir.get(`${candidateLine.route_id}:0`) ??
          destByRouteDir.get(`${candidateLine.route_id}:1`);
        if (!destEntry) continue;
        if (
          candidateLine.stop_sequence != null &&
          destEntry.destLine.stop_sequence != null &&
          candidateLine.stop_sequence >= destEntry.destLine.stop_sequence
        ) {
          continue;
        }
        const candidateCoords = pointCoordinates(candidateStop.geom);
        if (!candidateCoords) continue;
        const walkMeters = haversineMeters(from.coords, candidateCoords);
        const originCoords = pointCoordinates(originStop.geom);
        const destCoords = pointCoordinates(destEntry.destStop.geom);
        if (!originCoords || !destCoords) continue;
        const score =
          estimatedFirstLegSeconds(
            originLine,
            originStop.distance_m,
            originCoords,
            from.coords,
          ) +
          estimatedSecondLegSeconds(
            destEntry.destLine,
            walkMeters,
            candidateCoords,
            destCoords,
          ) +
          estimatedWalkSeconds(destEntry.destStop.distance_m);
        const match: WalkingTransferMatch = {
          originStop,
          destStop: destEntry.destStop,
          originLine,
          fromStop: from,
          toStop: { name: candidateStop.stop_name, coords: candidateCoords },
          departLine: candidateLine,
          destLine: destEntry.destLine,
          walkMeters,
          score,
        };
        const pathKey = [
          originStop.stop_id,
          `${originLine.route_id}:${originLine.direction_id}`,
          from.name,
          candidateStop.stop_id,
          `${candidateLine.route_id}:${candidateLine.direction_id}`,
          destEntry.destStop.stop_id,
        ].join("|");
        const existing = matchesByPath.get(pathKey);
        if (!existing || score < existing.score) matchesByPath.set(pathKey, match);
      }
    }
  }

  const finalists: WalkingTransferMatch[] = [];
  const finalistCountByRoute = new Map<string, number>();
  for (const match of [...matchesByPath.values()].sort((a, b) => a.score - b.score)) {
    const routeKey = `${match.originLine.route_id}:${match.originLine.direction_id}`;
    const count = finalistCountByRoute.get(routeKey) ?? 0;
    if (count >= 4) continue;
    finalistCountByRoute.set(routeKey, count + 1);
    finalists.push(match);
    if (finalists.length >= 32) break;
  }
  if (!finalists.length) return null;

  const stopNames = [
    ...new Set(
      finalists.flatMap((match) => [match.originStop.stop_name, match.toStop.name]),
    ),
  ];
  const departuresByStop = new Map(
    await Promise.all(
      stopNames.map(async (stopName) => [stopName, await safeNaolibDepartures(stopName)] as const),
    ),
  );

  let best: WalkingTransferMatch | null = null;
  for (const match of finalists) {
    const originCoords = pointCoordinates(match.originStop.geom);
    const destCoords = pointCoordinates(match.destStop.geom);
    if (!originCoords || !destCoords) continue;

    const accessSeconds = estimatedWalkSeconds(match.originStop.distance_m);
    const fallbackWaitA = remainingWaitSeconds(
      AVG_WAIT_SECONDS[match.originLine.route_type === 0 ? "tram" : "bus"],
      accessSeconds,
    );
    const passagesA = departuresByStop.get(match.originStop.stop_name) ?? [];
    const liveA = nextDepartureWaitSeconds(
      passagesA,
      match.originLine.route_short_name ?? match.originLine.route_id,
      null,
      new Date(Date.now() + accessSeconds * 1000),
    );
    const timingA = liveA ?? { waitSeconds: fallbackWaitA, realtime: false };
    const rideA = estimatedRideSecondsForScore(
      match.originLine,
      originCoords,
      match.fromStop.coords,
    );
    const transferWalkSeconds = estimatedWalkSeconds(match.walkMeters);
    const secondArrivalFromNow =
      accessSeconds + timingA.waitSeconds + rideA + transferWalkSeconds;
    const fallbackWaitB = AVG_WAIT_SECONDS[match.destLine.route_type === 0 ? "tram" : "bus"];
    const passagesB = departuresByStop.get(match.toStop.name) ?? [];
    const liveB = nextDepartureWaitSeconds(
      passagesB,
      match.departLine.route_short_name ?? match.departLine.route_id,
      null,
      new Date(Date.now() + secondArrivalFromNow * 1000),
    );
    const timingB = liveB ?? { waitSeconds: fallbackWaitB, realtime: false };
    const score =
      secondArrivalFromNow +
      timingB.waitSeconds +
      estimatedRideSecondsForScore(match.destLine, match.toStop.coords, destCoords) +
      estimatedWalkSeconds(match.destStop.distance_m);
    if (!best || score < best.score) best = { ...match, score };
  }

  return best ?? finalists[0];
}

function buildWalkStep(label: string, distance: number, duration: number): TransitStep {
  return { icon: "🚶", label, detail: distanceLabel(distance), duration: durationLabel(duration) };
}

function buildRideStep(
  line: ServingLine,
  toStopName: string,
  waitSeconds: number,
  inVehicleSeconds: number,
  realtime = false,
): TransitStep {
  const isTram = line.route_type === 0;
  const lineLabel = line.route_short_name ?? line.route_long_name ?? line.route_id;
  return {
    icon: isTram ? "🚋" : "🚌",
    label: `${isTram ? "Tram" : "Bus"} ${lineLabel} · descendre à ${toStopName}`,
    detail: `${realtime ? "Temps réel" : "Attente estimée"} ~${Math.round(waitSeconds / 60)} min`,
    duration: durationLabel(waitSeconds + inVehicleSeconds),
  };
}

type WalkSegment = { coordinates: [number, number][]; distance: number; duration: number };
type WalkFetcher = (from: [number, number], to: [number, number]) => Promise<WalkSegment>;

async function safeNaolibDepartures(stopName: string): Promise<RealtimeStopPassage[]> {
  try {
    return (await fetchNaolibDepartures(stopName)).passages;
  } catch {
    return [];
  }
}

function waitForServingLine(
  passages: RealtimeStopPassage[],
  line: ServingLine,
  arrivalFromNowSeconds: number,
  fallbackSeconds: number,
): { waitSeconds: number; realtime: boolean } {
  const lineName = line.route_short_name ?? line.route_id;
  return (
    nextDepartureWaitSeconds(
      passages,
      lineName,
      null,
      new Date(Date.now() + arrivalFromNowSeconds * 1000),
    ) ?? { waitSeconds: fallbackSeconds, realtime: false }
  );
}

/** Construit l'itinéraire d'une correspondance à pied inter-réseaux :
 *  marche → ligne A → marche (changement d'arrêt) → ligne B → marche. */
async function buildWalkingTransferResult(
  supabase: Awaited<ReturnType<typeof createClient>>,
  from: [number, number],
  to: [number, number],
  w: WalkingTransferMatch,
  fetchWalkSegment: WalkFetcher,
): Promise<TransitResult> {
  const originCoords = pointCoordinates(w.originStop.geom);
  const destCoords = pointCoordinates(w.destStop.geom);
  if (!originCoords || !destCoords) throw new Error("Position des arrêts introuvable");

  const [walk1, walkTransfer, walk2] = await Promise.all([
    fetchWalkSegment(from, originCoords),
    fetchWalkSegment(w.fromStop.coords, w.toStop.coords),
    fetchWalkSegment(destCoords, to),
  ]);

  const [shapesA, shapesB] = await Promise.all([
    loadShapesForServingLine(supabase, w.originLine),
    loadShapesForServingLine(supabase, w.destLine),
  ]);
  const segA = routeAlongShapes(shapesA, originCoords, w.fromStop.coords) ?? [originCoords, w.fromStop.coords];
  const segB = routeAlongShapes(shapesB, w.toStop.coords, destCoords) ?? [w.toStop.coords, destCoords];

  const straightA = haversineMeters(originCoords, w.fromStop.coords);
  const straightB = haversineMeters(w.toStop.coords, destCoords);
  const inVehicleA = estimateInVehicleSeconds(w.originLine.time_from_terminus_seconds, null, straightA);
  const inVehicleB = estimateInVehicleSeconds(
    w.departLine.time_from_terminus_seconds,
    w.destLine.time_from_terminus_seconds,
    straightB,
  );
  const fallbackWaitA = remainingWaitSeconds(
    AVG_WAIT_SECONDS[w.originLine.route_type === 0 ? "tram" : "bus"],
    walk1.duration,
  );
  const fallbackWaitB = AVG_WAIT_SECONDS[w.destLine.route_type === 0 ? "tram" : "bus"];
  const [passagesA, passagesB] = await Promise.all([
    safeNaolibDepartures(w.originStop.stop_name),
    safeNaolibDepartures(w.toStop.name),
  ]);
  const timingA = waitForServingLine(
    passagesA,
    w.originLine,
    walk1.duration,
    fallbackWaitA,
  );
  const secondArrivalFromNow =
    walk1.duration + timingA.waitSeconds + inVehicleA + walkTransfer.duration;
  const timingB = waitForServingLine(
    passagesB,
    w.destLine,
    secondArrivalFromNow,
    fallbackWaitB,
  );
  const waitA = timingA.waitSeconds;
  const waitB = timingB.waitSeconds;

  return {
    coordinates: [
      ...walk1.coordinates,
      ...segA,
      ...walkTransfer.coordinates,
      ...segB,
      ...walk2.coordinates,
    ],
    distance: walk1.distance + straightA + walkTransfer.distance + straightB + walk2.distance,
    duration:
      walk1.duration + waitA + inVehicleA + walkTransfer.duration + waitB + inVehicleB + walk2.duration,
    steps: [
      buildWalkStep(`Marche jusqu'à l'arrêt ${w.originStop.stop_name}`, walk1.distance, walk1.duration),
      buildRideStep(w.originLine, w.fromStop.name, waitA, inVehicleA, timingA.realtime),
      buildWalkStep(`Correspondance à pied jusqu'à ${w.toStop.name}`, walkTransfer.distance, walkTransfer.duration),
      buildRideStep(w.destLine, w.destStop.stop_name, waitB, inVehicleB, timingB.realtime),
      buildWalkStep("Marche jusqu'à destination", walk2.distance, walk2.duration),
    ],
  };
}

/** Calcule un itinéraire marche + transport en commun réel (une ligne directe, ou une correspondance), à partir des arrêts et horaires GTFS en base. */
export async function computeTransitRoute(
  from: [number, number],
  to: [number, number],
  fetchWalkSegment: WalkFetcher,
  recordTiming?: (name: string, durationMs: number) => void,
): Promise<TransitResult> {
  const supabase = await createClient();
  let phaseStartedAt = Date.now();
  const markPhase = (name: string) => {
    const now = Date.now();
    recordTiming?.(name, now - phaseStartedAt);
    phaseStartedAt = now;
  };

  const [originStops, destStops] = await Promise.all([fetchNearbyStops(supabase, from), fetchNearbyStops(supabase, to)]);
  markPhase("nearby");

  if (!originStops.length || !destStops.length) {
    throw new Error("Aucun arrêt de transport en commun à proximité");
  }

  const candidateStops = [
    ...new Map([...originStops, ...destStops].map((stop) => [stop.stop_id, stop])).values(),
  ];
  const linesByStop = await fetchServingLinesForStops(
    supabase,
    candidateStops.map((stop) => stop.stop_id),
  );
  const originLinesByStop = linesByStop;
  const destLinesByStop = linesByStop;
  markPhase("lines");

  const direct = await findDirectMatch(
    originStops,
    destStops,
    originLinesByStop,
    destLinesByStop,
  );

  if (direct) {
    const originCoords = pointCoordinates(direct.originStop.geom);
    const destCoords = pointCoordinates(direct.destStop.geom);
    if (!originCoords || !destCoords) throw new Error("Position des arrêts introuvable");

    const [walk1, walk2] = await Promise.all([
      fetchWalkSegment(from, originCoords),
      fetchWalkSegment(destCoords, to),
    ]);

    const shapes = await loadShapesForServingLine(supabase, direct.originLine);
    const transitSegment = routeAlongShapes(shapes, originCoords, destCoords) ?? [originCoords, destCoords];
    const straightDistance = haversineMeters(originCoords, destCoords);
    const inVehicleSeconds = estimateInVehicleSeconds(
      direct.originLine.time_from_terminus_seconds,
      direct.destLine.time_from_terminus_seconds,
      straightDistance,
    );
    const fallbackWait = remainingWaitSeconds(
      AVG_WAIT_SECONDS[direct.originLine.route_type === 0 ? "tram" : "bus"],
      walk1.duration,
    );
    const directTiming = waitForServingLine(
      await safeNaolibDepartures(direct.originStop.stop_name),
      direct.originLine,
      walk1.duration,
      fallbackWait,
    );
    const waitSeconds = directTiming.waitSeconds;
    markPhase("assemble");

    return {
      coordinates: [...walk1.coordinates, ...transitSegment, ...walk2.coordinates],
      distance: walk1.distance + straightDistance + walk2.distance,
      duration: walk1.duration + waitSeconds + inVehicleSeconds + walk2.duration,
      steps: [
        buildWalkStep(`Marche jusqu'à l'arrêt ${direct.originStop.stop_name}`, walk1.distance, walk1.duration),
        buildRideStep(
          direct.originLine,
          direct.destStop.stop_name,
          waitSeconds,
          inVehicleSeconds,
          directTiming.realtime,
        ),
        buildWalkStep("Marche jusqu'à destination", walk2.distance, walk2.duration),
      ],
    };
  }

  const interchangeStartedAt = Date.now();
  const transferPromise = findTransferMatch(
    supabase,
    originStops,
    destStops,
    originLinesByStop,
    destLinesByStop,
  );
  const walkingPromise = findWalkingTransferMatch(
    supabase,
    originStops,
    destStops,
    originLinesByStop,
    destLinesByStop,
  )
    .then((match) => ({ match, error: null }))
    .catch((error: unknown) => ({ match: null, error }));
  const transfer = await transferPromise;
  recordTiming?.("transfer", Date.now() - interchangeStartedAt);

  if (!transfer) {
    const walkingResult = await walkingPromise;
    if (walkingResult.error) throw walkingResult.error;
    const walking = walkingResult.match;
    recordTiming?.("walking", Date.now() - interchangeStartedAt);
    phaseStartedAt = Date.now();
    if (walking) {
      const result = await buildWalkingTransferResult(supabase, from, to, walking, fetchWalkSegment);
      markPhase("assemble");
      return result;
    }
    throw new Error(
      "Aucun trajet en transport en commun trouvé entre ces deux points, même avec une correspondance (essayez la voiture ou la marche)",
    );
  }

  const { data: transferStopRow, error: transferStopError } = await supabase
    .from("stops")
    .select("name, geom")
    .eq("id", transfer.transferStopId)
    .maybeSingle();
  if (transferStopError) {
    throw new Error(`Arrêt de correspondance introuvable: ${transferStopError.message}`);
  }

  const originCoords = pointCoordinates(transfer.originStop.geom);
  const destCoords = pointCoordinates(transfer.destStop.geom);
  const transferCoords = pointCoordinates(transferStopRow?.geom);
  if (!originCoords || !destCoords || !transferCoords) {
    throw new Error("Position des arrêts introuvable");
  }
  const transferStopName = (transferStopRow?.name as string | undefined) ?? "correspondance";

  const [walk1, walk2] = await Promise.all([
    fetchWalkSegment(from, originCoords),
    fetchWalkSegment(destCoords, to),
  ]);

  const [shapesLeg1, shapesLeg2] = await Promise.all([
    loadShapesForServingLine(supabase, transfer.originLine),
    loadShapesForServingLine(supabase, transfer.destLine),
  ]);
  const segmentLeg1 = routeAlongShapes(shapesLeg1, originCoords, transferCoords) ?? [originCoords, transferCoords];
  const segmentLeg2 = routeAlongShapes(shapesLeg2, transferCoords, destCoords) ?? [transferCoords, destCoords];

  const straightLeg1 = haversineMeters(originCoords, transferCoords);
  const straightLeg2 = haversineMeters(transferCoords, destCoords);

  const inVehicleLeg1 = estimateInVehicleSeconds(
    transfer.originLine.time_from_terminus_seconds,
    transfer.transferArriveLine.time_from_terminus_seconds,
    straightLeg1,
  );
  const inVehicleLeg2 = estimateInVehicleSeconds(
    transfer.transferDepartLine.time_from_terminus_seconds,
    transfer.destLine.time_from_terminus_seconds,
    straightLeg2,
  );
  const fallbackWaitLeg1 = remainingWaitSeconds(
    AVG_WAIT_SECONDS[transfer.originLine.route_type === 0 ? "tram" : "bus"],
    walk1.duration,
  );
  const fallbackWaitLeg2 = AVG_WAIT_SECONDS[transfer.destLine.route_type === 0 ? "tram" : "bus"];
  const [passagesLeg1, passagesLeg2] = await Promise.all([
    safeNaolibDepartures(transfer.originStop.stop_name),
    safeNaolibDepartures(transferStopName),
  ]);
  const timingLeg1 = waitForServingLine(
    passagesLeg1,
    transfer.originLine,
    walk1.duration,
    fallbackWaitLeg1,
  );
  const secondArrivalFromNow = walk1.duration + timingLeg1.waitSeconds + inVehicleLeg1;
  const timingLeg2 = waitForServingLine(
    passagesLeg2,
    transfer.destLine,
    secondArrivalFromNow,
    fallbackWaitLeg2,
  );
  const waitLeg1 = timingLeg1.waitSeconds;
  const waitLeg2 = timingLeg2.waitSeconds;
  markPhase("assemble");

  return {
    coordinates: [...walk1.coordinates, ...segmentLeg1, ...segmentLeg2, ...walk2.coordinates],
    distance: walk1.distance + straightLeg1 + straightLeg2 + walk2.distance,
    duration: walk1.duration + waitLeg1 + inVehicleLeg1 + waitLeg2 + inVehicleLeg2 + walk2.duration,
    steps: [
      buildWalkStep(`Marche jusqu'à l'arrêt ${transfer.originStop.stop_name}`, walk1.distance, walk1.duration),
      buildRideStep(
        transfer.originLine,
        transferStopName,
        waitLeg1,
        inVehicleLeg1,
        timingLeg1.realtime,
      ),
      buildRideStep(
        transfer.destLine,
        transfer.destStop.stop_name,
        waitLeg2,
        inVehicleLeg2,
        timingLeg2.realtime,
      ),
      buildWalkStep("Marche jusqu'à destination", walk2.distance, walk2.duration),
    ],
  };
}
