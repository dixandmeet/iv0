import { createAdminClient } from "@/lib/supabase/admin";
import {
  fetchNaolibDepartures,
  nextDepartureWaitSeconds,
  type RealtimeStopPassage,
} from "@/lib/carte-immersive/naolib-realtime";
import {
  fetchNaolibServiceAlerts,
  type NaolibServiceAlert,
} from "@/lib/carte-immersive/naolib-siri-alerts";
import { routeAlongShapes } from "@/lib/shape-route";
import {
  canBoardScheduledDeparture,
  journeyPathKey,
  rankTransitCandidates,
} from "@/lib/carte-immersive/transit-quality";
import type {
  TransitAlert,
  TransitAlternative,
  TransitRouteSegment,
  TransitResult,
  TransitStep,
} from "@/lib/carte-immersive/transit-route";

type TimetableOptions = {
  departureAt?: Date;
  maxTransfers?: number;
  wheelchair?: boolean;
  avoidDisruptions?: boolean;
  limit?: number;
  fetchWalkSegment?: WalkSegmentFetcher;
  fetchTransitSegment?: TransitSegmentFetcher;
};

type WalkSegment = {
  coordinates: [number, number][];
  distance: number;
  duration: number;
};

type WalkSegmentFetcher = (
  from: [number, number],
  to: [number, number],
) => Promise<WalkSegment>;

type TransitSegmentFetcher = (
  coordinates: [number, number][],
  mode: "tram" | "bus" | "navibus",
) => Promise<[number, number][]>;

type RawGeometry = {
  type?: string;
  coordinates?: unknown;
};

type RawLeg = {
  type?: "walk" | "transit";
  kind?: "access" | "transfer" | "egress";
  mode?: "tram" | "bus" | "navibus";
  route_id?: string;
  route_short_name?: string | null;
  direction_id?: number | null;
  headsign?: string | null;
  departure_id?: string;
  profile_id?: string;
  from_stop_id?: string;
  to_stop_id?: string;
  from_name?: string;
  to_name?: string;
  departure_at?: string;
  arrival_at?: string;
  duration_seconds?: number;
  distance_m?: number;
  accessible?: boolean;
  alerts?: TransitAlert[];
  geometry?: RawGeometry;
};

type RawJourney = {
  id?: string;
  departure_at?: string;
  arrival_at?: string;
  duration_seconds?: number;
  transfers?: number;
  walk_seconds?: number;
  accessible?: boolean;
  alerts?: TransitAlert[];
  route_ids?: string[];
  legs?: RawLeg[];
};

const MAX_REALTIME_STOPS = 20;
const TIMETABLE_SEARCH_WINDOW_MS = 8 * 60 * 60 * 1000;
const TIMETABLE_SEARCH_ATTEMPTS = 4;
// Quatre alternatives finales n'exigent pas de recalculer les géométries et
// le temps réel de dizaines de variantes presque identiques.
const MAX_RAW_JOURNEYS = 10;
const MAX_DEPARTURE_CHOICES = 3;
// Sous cette distance à vol d'oiseau (déjà majorée du facteur GTFS), le tracé
// direct d'une correspondance reste fiable : inutile de payer un aller-retour
// vers le routeur piéton public, qui sérialise les requêtes par IP.
const SHORT_TRANSFER_DIRECT_M = 250;
// Le routeur piéton public traite les requêtes une par une : au-delà de ce
// délai, la jambe conserve son estimation GTFS et l'appel continue en
// arrière-plan pour remplir le cache des prochains calculs.
const GEOMETRY_FETCH_TIMEOUT_MS = 2000;
const WALK_SEGMENT_COLOR = "#94a3b8";
const FALLBACK_LINE_COLORS = [
  "#00a8e8",
  "#f59e0b",
  "#ef4444",
  "#8b5cf6",
  "#22c55e",
  "#ec4899",
  "#06b6d4",
  "#f97316",
];

function isCoordinate(value: unknown): value is [number, number] {
  return (
    Array.isArray(value) &&
    value.length >= 2 &&
    Number.isFinite(value[0]) &&
    Number.isFinite(value[1])
  );
}

function geometryCoordinates(
  geometry: RawGeometry | undefined,
): [number, number][] {
  const raw = geometry?.coordinates;
  if (!Array.isArray(raw)) return [];
  if (raw.every(isCoordinate)) return raw as [number, number][];
  const flattened = raw.flat(2);
  return Array.isArray(flattened) && flattened.every(isCoordinate)
    ? (flattened as [number, number][])
    : [];
}

function appendCoordinates(
  target: [number, number][],
  coordinates: [number, number][],
) {
  for (const coordinate of coordinates) {
    const previous = target[target.length - 1];
    if (
      !previous ||
      previous[0] !== coordinate[0] ||
      previous[1] !== coordinate[1]
    ) {
      target.push(coordinate);
    }
  }
}

function withEndpoints(
  coordinates: [number, number][],
  from: [number, number],
  to: [number, number],
): [number, number][] {
  const result: [number, number][] = [];
  appendCoordinates(result, [from, ...coordinates, to]);
  return result;
}

/**
 * Les fractions GTFS peuvent viser la mauvaise occurrence d'un arrêt lorsque
 * un tracé boucle près d'un terminus. On redécoupe alors la géométrie reçue
 * entre les points réels des jambes voisines. Cela supprime automatiquement
 * les crochets et triangles sans modifier le calcul horaire.
 */
function correctedTransitCoordinates(
  legs: RawLeg[],
  legIndex: number,
  coordinates: [number, number][],
  journeyFrom: [number, number],
  journeyTo: [number, number],
): [number, number][] {
  if (coordinates.length < 2) return coordinates;

  const previous =
    legIndex > 0 ? geometryCoordinates(legs[legIndex - 1]?.geometry) : [];
  const next =
    legIndex + 1 < legs.length
      ? geometryCoordinates(legs[legIndex + 1]?.geometry)
      : [];
  const fromAnchor = previous.at(-1) ?? journeyFrom;
  const toAnchor = next[0] ?? journeyTo;
  const corrected = routeAlongShapes([coordinates], fromAnchor, toAnchor);
  return corrected && corrected.length >= 2 ? corrected : coordinates;
}

async function fetchWithDeadline<T>(
  work: Promise<T>,
  timeoutMs: number,
): Promise<T | null> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<null>((resolve) => {
    timer = setTimeout(() => resolve(null), timeoutMs);
  });
  try {
    return await Promise.race([work, deadline]);
  } finally {
    clearTimeout(timer);
    // L'appel abandonné peut encore échouer plus tard : neutraliser le rejet.
    void work.catch(() => undefined);
  }
}

async function correctJourneyGeometry(
  journey: RawJourney,
  from: [number, number],
  to: [number, number],
  fetchWalkSegment: WalkSegmentFetcher | undefined,
  fetchTransitSegment: TransitSegmentFetcher | undefined,
): Promise<RawJourney> {
  const rawLegs = journey.legs ?? [];
  const legs = await Promise.all(
    rawLegs.map(async (leg, index): Promise<RawLeg> => {
      const coordinates = geometryCoordinates(leg.geometry);
      if (coordinates.length < 2) return leg;

      if (leg.type === "transit") {
        const corrected = correctedTransitCoordinates(
          rawLegs,
          index,
          coordinates,
          from,
          to,
        );
        let routed = corrected;
        if (fetchTransitSegment && leg.mode) {
          try {
            const candidate = await fetchWithDeadline(
              fetchTransitSegment(corrected, leg.mode),
              GEOMETRY_FETCH_TIMEOUT_MS,
            );
            if (candidate && candidate.length >= 2) {
              routed = withEndpoints(
                candidate,
                corrected[0],
                corrected.at(-1)!,
              );
            }
          } catch {
            // Le segment GTFS corrigé reste utilisable si le recalage routier
            // n'est pas disponible ou refuse une voie réservée aux bus.
          }
        }
        return {
          ...leg,
          geometry: {
            type: "LineString",
            coordinates: routed,
          },
        };
      }

      if (leg.type !== "walk" || !fetchWalkSegment) return leg;
      if (
        (leg.kind ?? "transfer") === "transfer" &&
        (leg.distance_m ?? 0) <= SHORT_TRANSFER_DIRECT_M
      ) {
        return leg;
      }
      const walkFrom = coordinates[0];
      const walkTo = coordinates.at(-1)!;
      try {
        const routed = await fetchWithDeadline(
          fetchWalkSegment(walkFrom, walkTo),
          GEOMETRY_FETCH_TIMEOUT_MS,
        );
        if (!routed || routed.coordinates.length < 2) return leg;
        return {
          ...leg,
          distance_m: routed.distance,
          duration_seconds: Math.max(0, routed.duration),
          geometry: {
            type: "LineString",
            coordinates: withEndpoints(routed.coordinates, walkFrom, walkTo),
          },
        };
      } catch {
        // La géométrie GTFS droite reste un secours disponible si le routeur
        // piéton externe est momentanément indisponible.
        return leg;
      }
    }),
  );
  return { ...journey, legs };
}

function haversineMeters(a: [number, number], b: [number, number]): number {
  const radius = 6_371_000;
  const radians = Math.PI / 180;
  const deltaLat = (b[1] - a[1]) * radians;
  const deltaLng = (b[0] - a[0]) * radians;
  const lat1 = a[1] * radians;
  const lat2 = b[1] * radians;
  const h =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLng / 2) ** 2;
  return 2 * radius * Math.asin(Math.sqrt(h));
}

function polylineDistance(coordinates: [number, number][]): number {
  let distance = 0;
  for (let index = 1; index < coordinates.length; index += 1) {
    distance += haversineMeters(coordinates[index - 1], coordinates[index]);
  }
  return distance;
}

function durationLabel(seconds: number): string {
  return `${Math.max(1, Math.round(seconds / 60))} min`;
}

function distanceLabel(meters: number): string {
  return meters >= 1000
    ? `${(meters / 1000).toFixed(1)} km`
    : `${Math.round(meters)} m`;
}

function normalizeRouteColor(color: string | null | undefined): string | null {
  const normalized = color?.trim().replace(/^#/, "");
  return normalized && /^[0-9a-f]{6}$/i.test(normalized)
    ? `#${normalized}`
    : null;
}

function fallbackRouteColor(routeId: string): string {
  let hash = 0;
  for (const character of routeId)
    hash = (hash * 31 + character.charCodeAt(0)) >>> 0;
  return FALLBACK_LINE_COLORS[hash % FALLBACK_LINE_COLORS.length];
}

async function routeColorsForJourneys(
  journeys: RawJourney[],
): Promise<Map<string, string>> {
  const routeIds = [
    ...new Set(
      journeys.flatMap((journey) =>
        (journey.legs ?? [])
          .filter((leg) => leg.type === "transit" && leg.route_id)
          .map((leg) => leg.route_id!),
      ),
    ),
  ];
  if (!routeIds.length) return new Map();

  const supabase = createAdminClient();
  if (!supabase) return new Map();
  const { data, error } = await supabase
    .from("gtfs_routes")
    .select("route_id, route_color")
    .in("route_id", routeIds);
  if (error) return new Map();

  return new Map(
    (data ?? []).flatMap((route) => {
      const routeId = route.route_id as string;
      const color = normalizeRouteColor(
        route.route_color as string | null | undefined,
      );
      return color ? [[routeId, color] as const] : [];
    }),
  );
}

function localTime(date: Date): string {
  return new Intl.DateTimeFormat("fr-FR", {
    timeZone: "Europe/Paris",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).format(date);
}

function parisServiceDate(date: Date): string {
  return new Intl.DateTimeFormat("fr-CA", {
    timeZone: "Europe/Paris",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(date);
}

function firstTimetableSearchAt(requestedAt: Date): Date {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Europe/Paris",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(requestedAt);
  const hour = Number(parts.find((part) => part.type === "hour")?.value ?? 12);
  const minute = Number(
    parts.find((part) => part.type === "minute")?.value ?? 0,
  );

  // Entre minuit et 5 h, une recherche démarrant « maintenant » passe
  // l'essentiel de sa fenêtre dans la coupure nocturne. Viser directement 8 h
  // évite aussi les itinéraires très matinaux dominés par plusieurs heures
  // d'attente en correspondance, au profit du premier trajet matinal cohérent.
  if (hour >= 5) return requestedAt;
  const minutesUntilMorningService = 8 * 60 - (hour * 60 + minute);
  return new Date(requestedAt.getTime() + minutesUntilMorningService * 60_000);
}

async function departuresByStopName(
  journeys: RawJourney[],
): Promise<Map<string, RealtimeStopPassage[]>> {
  const stopNames = [
    ...new Set(
      journeys.flatMap((journey) =>
        (journey.legs ?? [])
          .filter((leg) => leg.type === "transit" && leg.from_name)
          .map((leg) => leg.from_name!),
      ),
    ),
  ].slice(0, MAX_REALTIME_STOPS);

  const entries = await Promise.all(
    stopNames.map(async (stopName) => {
      try {
        return [
          stopName,
          (await fetchNaolibDepartures(stopName)).passages,
        ] as const;
      } catch {
        return [stopName, [] as RealtimeStopPassage[]] as const;
      }
    }),
  );
  return new Map(entries);
}

function walkStep(leg: RawLeg, duration: number): TransitStep {
  const kind = leg.kind ?? "transfer";
  const label =
    kind === "access"
      ? `Marche jusqu'à l'arrêt ${leg.to_name ?? "de départ"}`
      : kind === "egress"
        ? "Marche jusqu'à destination"
        : `Correspondance à pied jusqu'à ${leg.to_name ?? "l'arrêt suivant"}`;
  return {
    icon: "🚶",
    label,
    detail: distanceLabel(leg.distance_m ?? 0),
    duration: durationLabel(duration),
  };
}

function routeSummary(
  routeIds: string[],
  transfers: number,
  legs: RawLeg[],
): string {
  const routes = routeIds.length ? routeIds.join(" → ") : "Transport en commun";
  if (transfers === 0) return `${routes} · direct`;
  const transitLegs = legs.filter((leg) => leg.type === "transit");
  const via = transitLegs
    .slice(0, -1)
    .map((leg, index) => {
      const next = transitLegs[index + 1];
      const from = leg.to_name;
      const to = next?.from_name;
      if (!from) return to;
      if (!to || from === to) return from;
      return `${from} / ${to}`;
    })
    .filter(Boolean)
    .join(", ");
  return `${routes} · ${transfers} corresp.${via ? ` · via ${via}` : ""}`;
}

function rawJourneyKey(journey: RawJourney): string {
  return journeyPathKey(
    journey.route_ids ?? [],
    journey.legs ?? [],
    journey.departure_at,
  );
}

function mergeJourneys(groups: RawJourney[][]): RawJourney[] {
  const unique = new Map<string, RawJourney>();
  for (const journey of groups.flat()) {
    const key = rawJourneyKey(journey);
    if (!unique.has(key)) unique.set(key, journey);
  }
  return [...unique.values()]
    .sort((a, b) => {
      const arrivalA = a.arrival_at
        ? new Date(a.arrival_at).getTime()
        : Number.MAX_SAFE_INTEGER;
      const arrivalB = b.arrival_at
        ? new Date(b.arrival_at).getTime()
        : Number.MAX_SAFE_INTEGER;
      return arrivalA - arrivalB;
    })
    .slice(0, MAX_RAW_JOURNEYS);
}

function normalizeAlerts(alerts: TransitAlert[] | undefined): TransitAlert[] {
  const unique = new Map<string, TransitAlert>();
  for (const alert of alerts ?? []) {
    const key = alert.id || `${alert.source}:${alert.title}`;
    if (!unique.has(key)) unique.set(key, alert);
  }
  return [...unique.values()];
}

function withOperatorAlerts(
  journey: RawJourney,
  operatorAlerts: NaolibServiceAlert[],
): RawJourney {
  const routeIds = new Set(journey.route_ids ?? []);
  const appliesToRoute = (alert: NaolibServiceAlert, routeId: string) => {
    const normalizedRoute = routeId.replace(/[^a-z0-9]/gi, "").toUpperCase();
    return alert.routeIds.some((reference) =>
      reference
        .split(":")
        .map((part) => part.replace(/[^a-z0-9]/gi, "").toUpperCase())
        .includes(normalizedRoute),
    );
  };
  const relevant = operatorAlerts.filter(
    (alert) =>
      !alert.routeIds.length ||
      [...routeIds].some((routeId) => appliesToRoute(alert, routeId)),
  );
  if (!relevant.length) return journey;
  return {
    ...journey,
    alerts: [...(journey.alerts ?? []), ...relevant],
    legs: (journey.legs ?? []).map((leg) =>
      leg.type === "transit" && leg.route_id
        ? {
            ...leg,
            alerts: [
              ...(leg.alerts ?? []),
              ...relevant.filter(
                (alert) =>
                  !alert.routeIds.length ||
                  appliesToRoute(alert, leg.route_id!),
              ),
            ],
          }
        : leg,
    ),
  };
}

function alertPenaltySeconds(alerts: TransitAlert[]): number {
  return alerts.reduce((penalty, alert) => {
    const candidate =
      alert.severity === "critical"
        ? 900
        : alert.severity === "warning"
          ? 420
          : 120;
    return Math.max(penalty, candidate);
  }, 0);
}

function buildAlternative(
  journey: RawJourney,
  requestedAt: Date,
  realtimeByStop: Map<string, RealtimeStopPassage[]>,
  routeColors: Map<string, string>,
): TransitAlternative | null {
  const legs = journey.legs ?? [];
  if (!legs.length) return null;

  const rawDeparture = journey.departure_at
    ? new Date(journey.departure_at)
    : requestedAt;
  const journeyDeparture = Number.isNaN(rawDeparture.getTime())
    ? requestedAt
    : rawDeparture;

  const coordinates: [number, number][] = [];
  const segments: TransitRouteSegment[] = [];
  const steps: TransitStep[] = [];
  let distance = 0;
  let elapsedSeconds = 0;
  let walkSeconds = 0;
  let waitSecondsTotal = 0;
  let cursor = new Date(journeyDeparture);
  const realtimeReferenceAt = new Date();

  for (const leg of legs) {
    const legCoordinates = geometryCoordinates(leg.geometry);
    appendCoordinates(coordinates, legCoordinates);
    if (legCoordinates.length >= 2) {
      const routeId = leg.type === "transit" ? leg.route_id : undefined;
      segments.push({
        coordinates: legCoordinates,
        color: routeId
          ? (routeColors.get(routeId) ?? fallbackRouteColor(routeId))
          : WALK_SEGMENT_COLOR,
        routeId,
        type: leg.type === "transit" ? "transit" : "walk",
      });
    }
    const geometryDistance = polylineDistance(legCoordinates);
    distance +=
      leg.type === "walk"
        ? (leg.distance_m ?? geometryDistance)
        : geometryDistance;

    if (leg.type === "walk") {
      const duration = Math.max(0, leg.duration_seconds ?? 0);
      elapsedSeconds += duration;
      walkSeconds += duration;
      cursor = new Date(cursor.getTime() + duration * 1000);
      steps.push(walkStep(leg, duration));
      continue;
    }

    if (leg.type !== "transit") continue;
    const scheduledDeparture = leg.departure_at
      ? new Date(leg.departure_at)
      : cursor;
    const scheduledArrival = leg.arrival_at ? new Date(leg.arrival_at) : null;
    const scheduledRideSeconds = Math.max(
      60,
      leg.duration_seconds ??
        (scheduledArrival
          ? (scheduledArrival.getTime() - scheduledDeparture.getTime()) / 1000
          : 60),
    );
    const routeName = leg.route_short_name ?? leg.route_id ?? "?";
    const passages = realtimeByStop.get(leg.from_name ?? "") ?? [];
    const realtimeOffsetMs =
      scheduledDeparture.getTime() - realtimeReferenceAt.getTime();
    const realtime =
      realtimeOffsetMs >= -5 * 60_000 && realtimeOffsetMs <= 2 * 60 * 60_000
        ? nextDepartureWaitSeconds(passages, routeName, leg.headsign, cursor)
        : null;
    // La durée piétonne vient d'être recalculée sur le vrai réseau. Si elle
    // fait manquer le départ théorique et qu'aucun passage temps réel compatible
    // n'est disponible, ce chemin n'est plus réalisable et doit être écarté.
    if (!realtime && !canBoardScheduledDeparture(scheduledDeparture, cursor))
      return null;
    const scheduledWait = Math.max(
      0,
      (scheduledDeparture.getTime() - cursor.getTime()) / 1000,
    );
    const waitSeconds = realtime?.waitSeconds ?? scheduledWait;
    const actualDeparture = new Date(cursor.getTime() + waitSeconds * 1000);
    const actualArrival = new Date(
      actualDeparture.getTime() + scheduledRideSeconds * 1000,
    );
    const alerts = normalizeAlerts(leg.alerts);
    const alertLabel = alerts.length ? ` · ⚠ ${alerts[0].title}` : "";
    const modeLabel =
      leg.mode === "tram" ? "Tram" : leg.mode === "navibus" ? "Navibus" : "Bus";
    const displayedHeadsign =
      realtime?.destination || leg.headsign || "terminus";

    steps.push({
      icon: leg.mode === "tram" ? "🚋" : leg.mode === "navibus" ? "⛴️" : "🚌",
      label: `${modeLabel} ${routeName} · descendre à ${leg.to_name ?? "destination"}`,
      detail: `${realtime?.realtime ? "Temps réel" : "Horaire"} ${localTime(actualDeparture)} · vers ${displayedHeadsign}${alertLabel}`,
      duration: durationLabel(waitSeconds + scheduledRideSeconds),
      tracking:
        leg.departure_id && leg.profile_id && leg.route_id
          ? {
              departureId: leg.departure_id,
              profileId: leg.profile_id,
              serviceDate: parisServiceDate(scheduledDeparture),
              line: routeName,
              routeId: leg.route_id,
              // Le flux temps réel peut annoncer une destination intermédiaire
              // (ex. Commerce). Pour identifier la bonne course et le bon sens,
              // conserver le terminus GTFS du profil planifié.
              direction: leg.headsign || realtime?.destination || "terminus",
              vehicleType: leg.mode === "tram" ? "tram" : "bus",
            }
          : undefined,
    });
    elapsedSeconds += waitSeconds + scheduledRideSeconds;
    waitSecondsTotal += waitSeconds;
    cursor = actualArrival;
  }

  if (coordinates.length < 2 || !steps.length) return null;
  const routeIds = journey.route_ids ?? [];
  const transfers = Math.max(0, journey.transfers ?? routeIds.length - 1);
  const pathKey = journeyPathKey(routeIds, legs, journey.departure_at);
  const journeyAlerts = normalizeAlerts(journey.alerts);
  return {
    id: `${journey.id ?? pathKey}-${journeyDeparture.getTime()}`,
    coordinates,
    segments,
    distance,
    duration: elapsedSeconds,
    departureAt: journeyDeparture.toISOString(),
    arrivalAt: cursor.toISOString(),
    steps,
    routeIds,
    transfers,
    walkSeconds,
    waitSeconds: waitSecondsTotal,
    alertPenaltySeconds: alertPenaltySeconds(journeyAlerts),
    accessible: Boolean(journey.accessible),
    alerts: journeyAlerts,
    summary: routeSummary(routeIds, transfers, legs),
  };
}

export async function computeTimetableTransitRoute(
  from: [number, number],
  to: [number, number],
  options: TimetableOptions = {},
  recordTiming?: (name: string, durationMs: number) => void,
): Promise<TransitResult | null> {
  // Le planificateur est volontairement réservé au serveur : sa fonction SQL
  // SECURITY DEFINER ne doit pas être exposée directement avec la clé publique.
  const supabase = createAdminClient();
  if (!supabase) return null;
  const departureAt = options.departureAt ?? new Date();
  const firstSearchAt = firstTimetableSearchAt(departureAt);
  const startedAt = Date.now();
  const searchAt = async (date: Date, limit = Math.min(10, Math.max(6, (options.limit ?? 4) * 2))) => {
    const { data, error } = await supabase.rpc("plan_transit_journeys", {
      p_from_lng: from[0],
      p_from_lat: from[1],
      p_to_lng: to[0],
      p_to_lat: to[1],
      p_departure_at: date.toISOString(),
      p_max_transfers: Math.min(2, Math.max(0, options.maxTransfers ?? 2)),
      p_wheelchair: Boolean(options.wheelchair),
      p_avoid_disruptions: options.avoidDisruptions !== false,
      p_limit: limit,
    });
    return {
      error,
      journeys: Array.isArray(data) ? (data as RawJourney[]) : [],
    };
  };

  // La fonction SQL diversifie déjà les chaînes de lignes sur toute sa
  // fenêtre horaire : un seul appel détermine l'itinéraire principal et ses
  // alternatives. Les vrais départs suivants sont obtenus par des requêtes
  // décalées (departureAt) que le client déclenche hors du chemin critique —
  // trois planifications parallèles se disputaient le CPU de Postgres et
  // ralentissaient chacune d'entre elles.
  const primaryResult = await searchAt(firstSearchAt);
  if (primaryResult.error) {
    recordTiming?.("timetable", Date.now() - startedAt);
    return null;
  }
  let journeys = mergeJourneys([primaryResult.journeys]);

  if (!journeys.length) {
    const fallbackResults = await Promise.all(
      Array.from(
        { length: TIMETABLE_SEARCH_ATTEMPTS - 1 },
        (_, index) => index + 1,
      ).map((attempt) =>
        searchAt(
          new Date(
            firstSearchAt.getTime() + attempt * TIMETABLE_SEARCH_WINDOW_MS,
          ),
        ),
      ),
    );
    journeys = mergeJourneys(fallbackResults.map((result) => result.journeys));
  }
  recordTiming?.("timetable", Date.now() - startedAt);
  if (!journeys.length) return null;

  // Les noms d'arrêts et identifiants de lignes ne changent pas pendant la
  // correction géométrique : le temps réel, les alertes et les couleurs se
  // chargent en parallèle des appels OSRM au lieu de s'y additionner. Aucune
  // de ces trois sources ne rejette (elles retombent sur des valeurs vides).
  const realtimeStartedAt = Date.now();
  const enrichmentPromise = Promise.all([
    departuresByStopName(journeys),
    fetchNaolibServiceAlerts(),
    routeColorsForJourneys(journeys),
  ]).then((enrichment) => {
    recordTiming?.("realtime", Date.now() - realtimeStartedAt);
    return enrichment;
  });

  const geometryStartedAt = Date.now();
  const correctedJourneys = await Promise.all(
    journeys.map((journey) =>
      correctJourneyGeometry(
        journey,
        from,
        to,
        options.fetchWalkSegment,
        options.fetchTransitSegment,
      ),
    ),
  );
  recordTiming?.("geometry", Date.now() - geometryStartedAt);

  const [realtimeByStop, operatorAlerts, routeColors] = await enrichmentPromise;
  const builtAlternatives = correctedJourneys
    .map((journey) => withOperatorAlerts(journey, operatorAlerts))
    .map((journey) =>
      buildAlternative(journey, departureAt, realtimeByStop, routeColors),
    )
    .filter(
      (alternative): alternative is TransitAlternative => alternative != null,
    )
    .map((alternative) => ({
      ...alternative,
      alertPenaltySeconds:
        options.avoidDisruptions === false
          ? 0
          : alertPenaltySeconds(alternative.alerts),
    }));
  const alternatives = rankTransitCandidates(
    builtAlternatives,
    departureAt,
    options.limit ?? 4,
  );
  const best = alternatives[0];
  if (!best) return null;

  const departures = [
    best,
    ...builtAlternatives
      .filter((candidate) => candidate.id !== best.id)
      .filter((candidate) => {
        const candidateAt = candidate.departureAt
          ? new Date(candidate.departureAt).getTime()
          : Number.NaN;
        const bestAt = best.departureAt
          ? new Date(best.departureAt).getTime()
          : Number.NaN;
        return Number.isFinite(candidateAt) && candidateAt > bestAt + 30_000;
      })
      .sort(
        (a, b) =>
          new Date(a.departureAt ?? 0).getTime() -
          new Date(b.departureAt ?? 0).getTime(),
      ),
  ].filter(
    (candidate, index, values) =>
      values.findIndex((value) => {
        const left = new Date(value.departureAt ?? 0).getTime();
        const right = new Date(candidate.departureAt ?? 0).getTime();
        return Math.abs(left - right) < 60_000;
      }) === index,
  ).slice(0, MAX_DEPARTURE_CHOICES);

  return {
    coordinates: best.coordinates,
    segments: best.segments,
    distance: best.distance,
    duration: best.duration,
    departureAt: best.departureAt,
    arrivalAt: best.arrivalAt,
    steps: best.steps,
    alternatives,
    departures,
    engine: "timetable",
  };
}
