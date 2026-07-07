import { createClient } from "@/lib/supabase/server";
import { pointCoordinates } from "@/lib/geo";
import { routeAlongShapes } from "@/lib/shape-route";

const MAX_SHAPES = 24;
const MAX_POINTS_PER_SHAPE = 4000;
const NEARBY_RADIUS_M = 900;
const MAX_CANDIDATE_STOPS = 5;
const MAX_TRANSFER_ORIGIN_STOPS = 3;
const MAX_DOWNSTREAM_STOPS = 30;

export type TransitStep = { icon: string; label: string; detail: string; duration: string };
export type TransitResult = {
  coordinates: [number, number][];
  distance: number;
  duration: number;
  steps: TransitStep[];
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

type ServedRoute = { stop_id: string; route_id: string; route_short_name: string | null; route_color: string | null };

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
const AVG_WAIT_SECONDS: Record<"tram" | "bus", number> = { tram: 6 * 60, bus: 10 * 60 };

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
  const { data } = await supabase.rpc("get_nearby_stops", {
    p_lng: point[0],
    p_lat: point[1],
    p_radius_m: NEARBY_RADIUS_M,
    p_audience: "passenger",
  });
  return ((data as NearbyStop[]) ?? []).slice(0, MAX_CANDIDATE_STOPS);
}

async function fetchServingLines(
  supabase: Awaited<ReturnType<typeof createClient>>,
  stopId: string,
): Promise<ServingLine[]> {
  const { data } = await supabase.rpc("get_stop_serving_lines", { p_stop_id: stopId });
  return (data as ServingLine[]) ?? [];
}

async function fetchDownstreamStops(
  supabase: Awaited<ReturnType<typeof createClient>>,
  tripId: string,
  fromSeq: number,
): Promise<Array<{ gtfsStopId: string; stopSequence: number }>> {
  const { data } = await supabase
    .from("gtfs_stop_times")
    .select("stop_id, stop_sequence")
    .eq("trip_id", tripId)
    .gt("stop_sequence", fromSeq)
    .order("stop_sequence")
    .limit(MAX_DOWNSTREAM_STOPS);
  return (data ?? []).map((r) => ({ gtfsStopId: r.stop_id as string, stopSequence: r.stop_sequence as number }));
}

async function mapGtfsIdsToUuidStops(
  supabase: Awaited<ReturnType<typeof createClient>>,
  gtfsIds: string[],
): Promise<Map<string, string>> {
  if (!gtfsIds.length) return new Map();
  const { data } = await supabase.from("gtfs_stop_mapping").select("stop_id, gtfs_stop_id").in("gtfs_stop_id", gtfsIds);
  const map = new Map<string, string>();
  for (const row of data ?? []) map.set(row.gtfs_stop_id as string, row.stop_id as string);
  return map;
}

async function fetchBulkServedRoutes(
  supabase: Awaited<ReturnType<typeof createClient>>,
  stopUuids: string[],
): Promise<ServedRoute[]> {
  if (!stopUuids.length) return [];
  const { data } = await supabase.rpc("get_stops_served_routes", { p_stop_ids: stopUuids });
  return (data as ServedRoute[]) ?? [];
}

async function loadShapesForRoute(
  supabase: Awaited<ReturnType<typeof createClient>>,
  routeId: string,
): Promise<[number, number][][]> {
  const { data: trips } = await supabase
    .from("gtfs_trips")
    .select("shape_id")
    .eq("route_id", routeId)
    .not("shape_id", "is", null)
    .limit(MAX_SHAPES);

  const shapeIds = [
    ...new Set((trips ?? []).map((t) => t.shape_id as string | null).filter((id): id is string => Boolean(id))),
  ];

  const shapes: [number, number][][] = [];
  for (const shapeId of shapeIds) {
    const { data: pts } = await supabase
      .from("gtfs_shapes")
      .select("shape_pt_sequence, geom")
      .eq("shape_id", shapeId)
      .order("shape_pt_sequence")
      .limit(MAX_POINTS_PER_SHAPE);
    const coords = (pts ?? [])
      .map((row) => pointCoordinates(row.geom))
      .filter((c): c is [number, number] => c != null);
    if (coords.length >= 2) shapes.push(coords);
  }
  return shapes;
}

type DirectMatch = {
  originStop: NearbyStop;
  destStop: NearbyStop;
  originLine: ServingLine;
  destLine: ServingLine;
  score: number;
};

function findDirectMatch(
  originStops: NearbyStop[],
  destStops: NearbyStop[],
  originLinesByStop: Map<string, ServingLine[]>,
  destLinesByStop: Map<string, ServingLine[]>,
): DirectMatch | null {
  let best: DirectMatch | null = null;

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

          const score = originStop.distance_m + destStop.distance_m;
          if (!best || score < best.score) {
            best = { originStop, destStop, originLine, destLine, score };
          }
        }
      }
    }
  }

  return best;
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

  const servingLinesCache = new Map<string, Promise<ServingLine[]>>();
  const getServingLinesCached = (stopId: string) => {
    let promise = servingLinesCache.get(stopId);
    if (!promise) {
      promise = fetchServingLines(supabase, stopId);
      servingLinesCache.set(stopId, promise);
    }
    return promise;
  };

  let best: TransferMatch | null = null;

  for (const originStop of originStops.slice(0, MAX_TRANSFER_ORIGIN_STOPS)) {
    const originLines = originLinesByStop.get(originStop.stop_id) ?? [];
    for (const originLine of originLines) {
      if (originLine.trip_id == null || originLine.stop_sequence == null) continue;

      const downstream = await fetchDownstreamStops(supabase, originLine.trip_id, originLine.stop_sequence);
      if (!downstream.length) continue;

      const uuidMap = await mapGtfsIdsToUuidStops(
        supabase,
        downstream.map((d) => d.gtfsStopId),
      );
      const transferUuids = [...new Set(uuidMap.values())].filter((id) => id !== originStop.stop_id);
      if (!transferUuids.length) continue;

      const served = await fetchBulkServedRoutes(supabase, transferUuids);
      for (const row of served) {
        if (row.route_id === originLine.route_id) continue;

        const candidateKeys = [`${row.route_id}:0`, `${row.route_id}:1`];
        for (const key of candidateKeys) {
          const destEntry = destByRouteDir.get(key);
          if (!destEntry) continue;

          const transferLines = await getServingLinesCached(row.stop_id);
          const arriveLine = transferLines.find(
            (tl) => tl.route_id === originLine.route_id && tl.direction_id === originLine.direction_id,
          );
          const departLine = transferLines.find(
            (tl) => tl.route_id === destEntry.destLine.route_id && tl.direction_id === destEntry.destLine.direction_id,
          );
          if (!departLine || departLine.stop_sequence == null || destEntry.destLine.stop_sequence == null) continue;
          if (departLine.stop_sequence >= destEntry.destLine.stop_sequence) continue;

          const score = originStop.distance_m + destEntry.destStop.distance_m;
          if (!best || score < best.score) {
            best = {
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
      }
    }
  }

  return best;
}

function buildWalkStep(label: string, distance: number, duration: number): TransitStep {
  return { icon: "🚶", label, detail: distanceLabel(distance), duration: durationLabel(duration) };
}

function buildRideStep(
  line: ServingLine,
  toStopName: string,
  waitSeconds: number,
  inVehicleSeconds: number,
): TransitStep {
  const isTram = line.route_type === 0;
  const lineLabel = line.route_short_name ?? line.route_long_name ?? line.route_id;
  return {
    icon: isTram ? "🚋" : "🚌",
    label: `${isTram ? "Tram" : "Bus"} ${lineLabel} · descendre à ${toStopName}`,
    detail: `Attente estimée ~${Math.round(waitSeconds / 60)} min`,
    duration: durationLabel(waitSeconds + inVehicleSeconds),
  };
}

type WalkSegment = { coordinates: [number, number][]; distance: number; duration: number };
type WalkFetcher = (from: [number, number], to: [number, number]) => Promise<WalkSegment>;

/** Calcule un itinéraire marche + transport en commun réel (une ligne directe, ou une correspondance), à partir des arrêts et horaires GTFS en base. */
export async function computeTransitRoute(
  from: [number, number],
  to: [number, number],
  fetchWalkSegment: WalkFetcher,
): Promise<TransitResult> {
  const supabase = await createClient();

  const [originStops, destStops] = await Promise.all([fetchNearbyStops(supabase, from), fetchNearbyStops(supabase, to)]);

  if (!originStops.length || !destStops.length) {
    throw new Error("Aucun arrêt de transport en commun à proximité");
  }

  const originLinesByStop = new Map<string, ServingLine[]>(
    await Promise.all(
      originStops.map(async (s) => [s.stop_id, await fetchServingLines(supabase, s.stop_id)] as const),
    ),
  );
  const destLinesByStop = new Map<string, ServingLine[]>(
    await Promise.all(destStops.map(async (s) => [s.stop_id, await fetchServingLines(supabase, s.stop_id)] as const)),
  );

  const direct = findDirectMatch(originStops, destStops, originLinesByStop, destLinesByStop);

  if (direct) {
    const originCoords = pointCoordinates(direct.originStop.geom);
    const destCoords = pointCoordinates(direct.destStop.geom);
    if (!originCoords || !destCoords) throw new Error("Position des arrêts introuvable");

    const [walk1, walk2] = await Promise.all([
      fetchWalkSegment(from, originCoords),
      fetchWalkSegment(destCoords, to),
    ]);

    const shapes = await loadShapesForRoute(supabase, direct.originLine.route_id);
    const transitSegment = routeAlongShapes(shapes, originCoords, destCoords) ?? [originCoords, destCoords];
    const straightDistance = haversineMeters(originCoords, destCoords);
    const inVehicleSeconds = estimateInVehicleSeconds(
      direct.originLine.time_from_terminus_seconds,
      direct.destLine.time_from_terminus_seconds,
      straightDistance,
    );
    const waitSeconds = AVG_WAIT_SECONDS[direct.originLine.route_type === 0 ? "tram" : "bus"];

    return {
      coordinates: [...walk1.coordinates, ...transitSegment, ...walk2.coordinates],
      distance: walk1.distance + straightDistance + walk2.distance,
      duration: walk1.duration + waitSeconds + inVehicleSeconds + walk2.duration,
      steps: [
        buildWalkStep(`Marche jusqu'à l'arrêt ${direct.originStop.stop_name}`, walk1.distance, walk1.duration),
        buildRideStep(direct.originLine, direct.destStop.stop_name, waitSeconds, inVehicleSeconds),
        buildWalkStep("Marche jusqu'à destination", walk2.distance, walk2.duration),
      ],
    };
  }

  const transfer = await findTransferMatch(supabase, originStops, destStops, originLinesByStop, destLinesByStop);

  if (!transfer) {
    throw new Error(
      "Aucun trajet en transport en commun trouvé entre ces deux points, même avec une correspondance (essayez la voiture ou la marche)",
    );
  }

  const { data: transferStopRow } = await supabase
    .from("stops")
    .select("name, geom")
    .eq("id", transfer.transferStopId)
    .maybeSingle();

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
    loadShapesForRoute(supabase, transfer.originLine.route_id),
    loadShapesForRoute(supabase, transfer.destLine.route_id),
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
  const waitLeg1 = AVG_WAIT_SECONDS[transfer.originLine.route_type === 0 ? "tram" : "bus"];
  const waitLeg2 = AVG_WAIT_SECONDS[transfer.destLine.route_type === 0 ? "tram" : "bus"];

  return {
    coordinates: [...walk1.coordinates, ...segmentLeg1, ...segmentLeg2, ...walk2.coordinates],
    distance: walk1.distance + straightLeg1 + straightLeg2 + walk2.distance,
    duration: walk1.duration + waitLeg1 + inVehicleLeg1 + waitLeg2 + inVehicleLeg2 + walk2.duration,
    steps: [
      buildWalkStep(`Marche jusqu'à l'arrêt ${transfer.originStop.stop_name}`, walk1.distance, walk1.duration),
      buildRideStep(transfer.originLine, transferStopName, waitLeg1, inVehicleLeg1),
      buildRideStep(transfer.destLine, transfer.destStop.stop_name, waitLeg2, inVehicleLeg2),
      buildWalkStep("Marche jusqu'à destination", walk2.distance, walk2.duration),
    ],
  };
}
