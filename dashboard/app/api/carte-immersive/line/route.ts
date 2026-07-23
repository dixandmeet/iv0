import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { lineStringCoordinates, pointCoordinates } from "@/lib/geo";
import { distanceMeters } from "@/lib/carte-immersive/geo";
import { parseLineId } from "@/lib/depot-lines";
import { buildDepotTimelineFromSchema } from "@/lib/regulation-depot";
import type { LineEditorState } from "@/lib/line-editor-types";
import { getVoicePoints, isStopType, normalizeLineEditorState } from "@/lib/line-editor-utils";
import { serviceDayElapsedSeconds } from "@/lib/carte-immersive/stop-schedule";
import type { GtfsStop } from "@/lib/types";

type LineStop = {
  id: string;
  name: string;
  lat: number;
  lng: number;
};

type LineSchedule = {
  generatedAt: string;
  departureId: string;
  profileId: string;
  patternShapeId: string | null;
  directionId: number | null;
  destination: string | null;
  source: "gtfs";
  stops: Array<{
    stopId: string;
    fraction: number;
    passageInSeconds: number;
  }>;
};

type TripProfile = {
  profile_id: string;
  direction_id: number | null;
  pattern_shape_id: string | null;
  headsign: string | null;
  duration_seconds: number;
};

type TripDeparture = {
  departure_id: string;
  profile_id: string;
  service_id: string;
  start_seconds: number;
};

type ProfileStopRow = {
  profile_id: string;
  stop_id: string;
  stop_sequence: number;
  offset_seconds: number;
  shape_fraction: number;
};

const parisClockFormatter = new Intl.DateTimeFormat("fr-CA", {
  timeZone: "Europe/Paris",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hourCycle: "h23",
});

function parisServiceClock(now: Date): { date: string; seconds: number } {
  const parts = Object.fromEntries(
    parisClockFormatter
      .formatToParts(now)
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, Number(part.value)]),
  );
  return {
    date: `${parts.year}-${String(parts.month).padStart(2, "0")}-${String(parts.day).padStart(2, "0")}`,
    seconds: parts.hour * 3_600 + parts.minute * 60 + parts.second,
  };
}

function moveServiceDate(date: string, days: number): string {
  const value = new Date(`${date}T12:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

async function activeServiceIds(
  supabase: Awaited<ReturnType<typeof createClient>>,
  date: string,
): Promise<string[]> {
  const day = new Date(`${date}T12:00:00Z`);
  const isoDay = day.getUTCDay() === 0 ? 7 : day.getUTCDay();
  const [{ data: regular, error: regularError }, { data: exceptions, error: exceptionError }] =
    await Promise.all([
      supabase
        .from("gtfs_calendar")
        .select("service_id, runs_on")
        .lte("start_date", date)
        .gte("end_date", date),
      supabase
        .from("gtfs_calendar_dates")
        .select("service_id, exception_type")
        .eq("service_date", date),
    ]);
  if (regularError || exceptionError) throw regularError ?? exceptionError;

  const removed = new Set(
    (exceptions ?? [])
      .filter((item) => item.exception_type === 2)
      .map((item) => String(item.service_id)),
  );
  const active = new Set(
    (regular ?? [])
      .filter((item) => Boolean((item.runs_on as boolean[] | null)?.[isoDay - 1]))
      .map((item) => String(item.service_id))
      .filter((serviceId) => !removed.has(serviceId)),
  );
  for (const exception of exceptions ?? []) {
    if (exception.exception_type === 1) active.add(String(exception.service_id));
  }
  return [...active];
}

/**
 * Trouve toutes les courses en circulation dans le sens affiché (ou la
 * prochaine si aucune n'a encore démarré) et expose leurs heures de passage
 * relatives. Le navigateur peut ainsi placer chaque véhicule indépendamment.
 */
async function loadLineSchedules(
  supabase: Awaited<ReturnType<typeof createClient>>,
  routeId: string,
  directionId: number | null,
  now = new Date(),
  preferred?: { departureId: string; profileId?: string; serviceDate: string },
): Promise<LineSchedule[]> {
  let profilesQuery = supabase
    .from("gtfs_trip_profiles")
    .select("profile_id, direction_id, pattern_shape_id, headsign, duration_seconds")
    .eq("route_id", routeId);
  if (directionId != null) profilesQuery = profilesQuery.eq("direction_id", directionId);

  const { data: rawProfiles, error: profilesError } = await profilesQuery;
  if (profilesError) throw profilesError;
  const profiles = (rawProfiles ?? []) as TripProfile[];
  if (!profiles.length) return [];

  const profileById = new Map(profiles.map((profile) => [profile.profile_id, profile]));
  const profileIds = [...profileById.keys()];
  type ScheduleCandidate = {
    departure: TripDeparture;
    profile: TripProfile;
    startsInSeconds: number;
  };
  let selected: ScheduleCandidate[] = [];

  if (preferred) {
    const elapsed = serviceDayElapsedSeconds(preferred.serviceDate, now.getTime());
    if (elapsed == null) return [];
    const services = await activeServiceIds(supabase, preferred.serviceDate);
    if (!services.length) return [];
    let departuresQuery = supabase
      .from("gtfs_trip_departures")
      .select("departure_id, profile_id, service_id, start_seconds")
      .eq("departure_id", preferred.departureId)
      .in("profile_id", profileIds)
      .in("service_id", services);
    if (preferred.profileId) {
      departuresQuery = departuresQuery.eq("profile_id", preferred.profileId);
    }
    const { data, error } = await departuresQuery.limit(1);
    if (error) throw error;
    const departure = (data?.[0] ?? null) as TripDeparture | null;
    const profile = departure ? profileById.get(departure.profile_id) : null;
    if (departure && profile) {
      selected = [{
        departure,
        profile,
        startsInSeconds: departure.start_seconds - elapsed,
      }];
    }
  } else {
    const maxDuration = Math.max(...profiles.map((profile) => profile.duration_seconds), 0);
    const clock = parisServiceClock(now);
    const serviceDays = [
      { date: clock.date, elapsed: clock.seconds },
      { date: moveServiceDate(clock.date, -1), elapsed: clock.seconds + 86_400 },
    ];
    const candidates: ScheduleCandidate[] = [];

    for (const serviceDay of serviceDays) {
      const services = await activeServiceIds(supabase, serviceDay.date);
      if (!services.length) continue;
      const { data, error } = await supabase
        .from("gtfs_trip_departures")
        .select("departure_id, profile_id, service_id, start_seconds")
        .in("profile_id", profileIds)
        .in("service_id", services)
        .gte("start_seconds", Math.max(0, serviceDay.elapsed - maxDuration - 60))
        .lte("start_seconds", serviceDay.elapsed + 3 * 3_600)
        .order("start_seconds")
        .limit(500);
      if (error) throw error;
      for (const departure of (data ?? []) as TripDeparture[]) {
        const profile = profileById.get(departure.profile_id);
        if (!profile) continue;
        candidates.push({
          departure,
          profile,
          startsInSeconds: departure.start_seconds - serviceDay.elapsed,
        });
      }
    }

    const running = candidates
      .filter(
        (candidate) =>
          candidate.startsInSeconds <= 0 &&
          candidate.startsInSeconds + candidate.profile.duration_seconds >= 0,
      )
      .sort((a, b) => b.startsInSeconds - a.startsInSeconds);
    selected =
      running.length > 0
        ? running
        :
      candidates
        .filter((candidate) => candidate.startsInSeconds > 0)
        .sort((a, b) => a.startsInSeconds - b.startsInSeconds)
        .slice(0, 1);
  }
  if (!selected.length) return [];

  const { data: rawStops, error: stopsError } = await supabase
    .from("gtfs_trip_profile_stops")
    .select("profile_id, stop_id, stop_sequence, offset_seconds, shape_fraction")
    .in("profile_id", [...new Set(selected.map((item) => item.profile.profile_id))])
    .order("profile_id")
    .order("stop_sequence");
  if (stopsError) throw stopsError;
  const stopsByProfile = new Map<string, ProfileStopRow[]>();
  for (const stop of (rawStops ?? []) as ProfileStopRow[]) {
    const profileId = stop.profile_id;
    const values = stopsByProfile.get(profileId) ?? [];
    values.push(stop);
    stopsByProfile.set(profileId, values);
  }

  return selected.flatMap((candidate) => {
    const scheduleStops = (stopsByProfile.get(candidate.profile.profile_id) ?? [])
      .map((stop) => ({
        stopId: String(stop.stop_id),
        fraction: Math.min(1, Math.max(0, Number(stop.shape_fraction))),
        passageInSeconds:
          candidate.startsInSeconds + Number(stop.offset_seconds),
      }))
      .filter(
        (stop) =>
          Number.isFinite(stop.fraction) && Number.isFinite(stop.passageInSeconds),
      );
    if (scheduleStops.length < 2) return [];
    return [{
      generatedAt: now.toISOString(),
      departureId: candidate.departure.departure_id,
      profileId: candidate.profile.profile_id,
      patternShapeId: candidate.profile.pattern_shape_id,
      directionId: candidate.profile.direction_id,
      destination: candidate.profile.headsign,
      source: "gtfs" as const,
      stops: scheduleStops,
    }];
  });
}

function parseNetworkLineId(lineId: string): { networkId: string; routeId: string } | null {
  const match = /^network:([^:]+):(.+)$/.exec(lineId);
  return match ? { networkId: match[1], routeId: match[2] } : null;
}

async function loadPublishedNetworkLine(
  supabase: Awaited<ReturnType<typeof createClient>>,
  lineId: string,
): Promise<{ trace: [number, number][]; stops: LineStop[] } | null> {
  const parsed = parseNetworkLineId(lineId);
  if (!parsed) return null;

  const { data, error } = await supabase
    .from("network_lines")
    .select("editor_state")
    .eq("network_id", parsed.networkId)
    .eq("line_id", parsed.routeId)
    .maybeSingle();
  if (error) throw error;

  const rawState = data?.editor_state as LineEditorState | null | undefined;
  if (!rawState || rawState.status !== "published") return null;

  const state = normalizeLineEditorState(rawState);
  const points = getVoicePoints(state, "aller");
  const trace = points.map(
    (point) => [point.coordinates[1], point.coordinates[0]] as [number, number],
  );
  if (trace.length < 2) return null;

  const stops = points
    .filter((point) => isStopType(point.type))
    .map((point) => ({
      id: point.id,
      name: point.stop?.name?.trim() || "Arrêt",
      lat: point.coordinates[1],
      lng: point.coordinates[0],
    }));

  return { trace, stops };
}

async function loadActiveStops(
  supabase: Awaited<ReturnType<typeof createClient>>,
): Promise<GtfsStop[]> {
  const pageSize = 1000;
  const stops: GtfsStop[] = [];

  for (let from = 0; ; from += pageSize) {
    const { data, error } = await supabase
      .from("stops")
      .select("code, name, geom, station_id")
      .eq("status", "active")
      .range(from, from + pageSize - 1);
    if (error) throw error;
    if (!data?.length) break;

    stops.push(
      ...data.map((row) => ({
        stop_id: row.code as string,
        stop_name: (row.name as string) || (row.code as string),
        station_id: row.station_id as string,
        geom: row.geom as GtfsStop["geom"],
      })),
    );
    if (data.length < pageSize) break;
  }

  return stops;
}

type PublishedTraceVariant = { direction: string; coordinates: [number, number][] };
type PublishedTraceRow = {
  line_id: string;
  transport_mode: string;
  color: string;
  variants: PublishedTraceVariant[];
};

/**
 * Fraction (0..1) de la position de `point` le long de `trace` ([lat,lng]).
 * Métrique planaire cohérente avec pathLen/pointAt côté client : le véhicule
 * animé (fraction → point) reste ainsi calé sur la géométrie renvoyée.
 */
function fractionAlongTrace(
  trace: [number, number][],
  point: [number, number],
): number {
  if (trace.length < 2) return 0;
  let bestDist = Infinity;
  let bestAlong = 0;
  let cumulative = 0;
  for (let i = 1; i < trace.length; i++) {
    const [x1, y1] = trace[i - 1];
    const [x2, y2] = trace[i];
    const dx = x2 - x1;
    const dy = y2 - y1;
    const segLen = Math.hypot(dx, dy);
    const t =
      segLen > 0
        ? Math.max(
            0,
            Math.min(
              1,
              ((point[0] - x1) * dx + (point[1] - y1) * dy) / (segLen * segLen),
            ),
          )
        : 0;
    const projX = x1 + dx * t;
    const projY = y1 + dy * t;
    const d = Math.hypot(point[0] - projX, point[1] - projY);
    if (d < bestDist) {
      bestDist = d;
      bestAlong = cumulative + segLen * t;
    }
    cumulative += segLen;
  }
  return cumulative > 0 ? Math.max(0, Math.min(1, bestAlong / cumulative)) : 0;
}

/**
 * Choisit, parmi les variantes de tracé publiées (éditeur de ligne), celle dont
 * les extrémités collent au premier et au dernier arrêt de la course — en
 * testant les deux orientations. Renvoie la géométrie en [lat,lng], ou null si
 * aucune variante n'est assez proche (on conserve alors le shape GTFS).
 */
function pickManualTrace(
  variants: PublishedTraceVariant[],
  stops: LineStop[],
): [number, number][] | null {
  if (variants.length === 0 || stops.length < 2) return null;
  const first: [number, number] = [stops[0].lat, stops[0].lng];
  const last: [number, number] = [
    stops[stops.length - 1].lat,
    stops[stops.length - 1].lng,
  ];
  const THRESHOLD_M = 350;
  let best: { trace: [number, number][]; score: number } | null = null;
  for (const variant of variants) {
    const latLng = (variant.coordinates ?? [])
      .filter((coords) => Array.isArray(coords) && coords.length === 2)
      .map(([lng, lat]) => [lat, lng] as [number, number]);
    if (latLng.length < 2) continue;
    for (const oriented of [latLng, [...latLng].reverse()]) {
      const dStart = distanceMeters(oriented[0], first);
      const dEnd = distanceMeters(oriented[oriented.length - 1], last);
      if (dStart > THRESHOLD_M || dEnd > THRESHOLD_M) continue;
      const score = dStart + dEnd;
      if (!best || score < best.score) best = { trace: oriented, score };
    }
  }
  return best?.trace ?? null;
}

export async function GET(request: Request) {
  const searchParams = new URL(request.url).searchParams;
  const lineId = searchParams.get("lineId")?.trim();
  const departureId = searchParams.get("departureId")?.trim();
  const profileId = searchParams.get("profileId")?.trim();
  const serviceDate = searchParams.get("serviceDate")?.trim();
  if (!lineId) {
    return NextResponse.json({ error: "Identifiant de ligne manquant" }, { status: 400 });
  }

  const { depotCode, routeId } = parseLineId(lineId);
  const supabase = await createClient();

  try {
    const networkLine = await loadPublishedNetworkLine(supabase, lineId);
    if (networkLine) return NextResponse.json(networkLine);

    if (parseNetworkLineId(lineId)) {
      return NextResponse.json(
        { error: "Cette ligne réseau n'est pas publiée ou ne possède aucun tracé" },
        { status: 404 },
      );
    }

    const preferred =
      departureId && serviceDate && /^\d{4}-\d{2}-\d{2}$/.test(serviceDate)
        ? { departureId, profileId: profileId || undefined, serviceDate }
        : undefined;
    let schedules: LineSchedule[] = [];
    try {
      if (preferred) {
        // Les heures GTFS après minuit appartiennent parfois au service de la
        // veille (ex. 24:28). L'itinéraire transporte l'heure civile : essayer
        // aussi J-1 garantit que le bouton de suivi retrouve bien la course.
        for (const candidateDate of [
          preferred.serviceDate,
          moveServiceDate(preferred.serviceDate, -1),
        ]) {
          schedules = await loadLineSchedules(
            supabase,
            routeId,
            null,
            new Date(),
            { ...preferred, serviceDate: candidateDate },
          );
          if (schedules.length) break;
        }
      }
      if (preferred && !schedules.length) {
        return NextResponse.json(
          { error: "Cette course n'est pas disponible pour le suivi" },
          { status: 404 },
        );
      }
    } catch {
      schedules = [];
    }

    let trace: [number, number][] = [];
    let stops: LineStop[] = [];

    // Pour le suivi d'une course, le sens ne suffit pas : certaines lignes
    // possèdent plusieurs branches dans une même direction (ligne 1 :
    // Beaujoire et Babinière). Le profil exact porte le bon tracé et les bons
    // arrêts, contrairement au premier trip arbitraire de ce sens.
    const selectedSchedule = preferred ? schedules[0] : null;
    if (selectedSchedule?.patternShapeId) {
      const { data: patternShape, error: patternShapeError } = await supabase
        .from("gtfs_pattern_shapes")
        .select("geom")
        .eq("pattern_shape_id", selectedSchedule.patternShapeId)
        .maybeSingle();
      if (patternShapeError) throw patternShapeError;
      trace = lineStringCoordinates(patternShape?.geom).map(([lng, lat]) => [lat, lng]);
    }

    if (selectedSchedule?.stops.length) {
      const profileStopIds = [...new Set(selectedSchedule.stops.map((stop) => stop.stopId))];
      const { data: profileStops, error: profileStopsError } = await supabase
        .from("gtfs_stops")
        .select("stop_id, stop_name, geom")
        .in("stop_id", profileStopIds);
      if (profileStopsError) throw profileStopsError;
      const stopsById = new Map(
        (profileStops ?? []).map((stop) => [String(stop.stop_id), stop]),
      );
      stops = selectedSchedule.stops.flatMap((scheduledStop) => {
        const stop = stopsById.get(scheduledStop.stopId);
        const coordinates = pointCoordinates(stop?.geom);
        return stop && coordinates
          ? [{
              id: String(stop.stop_id),
              name: String(stop.stop_name || stop.stop_id),
              lat: coordinates[1],
              lng: coordinates[0],
            }]
          : [];
      });
    }

    let tripsQuery = supabase
      .from("gtfs_trips")
      .select("trip_id, shape_id, direction_id")
      .eq("route_id", routeId)
      .order("direction_id")
      .order("trip_id")
      .limit(40);
    if (schedules[0]?.directionId != null) {
      tripsQuery = tripsQuery.eq("direction_id", schedules[0].directionId);
    }
    const { data: trips, error: tripsError } = await tripsQuery;
    if (tripsError) throw tripsError;

    const trip = trips?.find((item) => item.shape_id) ?? trips?.[0] ?? null;

    if (trace.length < 2 && trip?.shape_id) {
      const { data: shapeRows, error: shapeError } = await supabase
        .from("gtfs_shapes")
        .select("shape_pt_sequence, geom")
        .eq("shape_id", trip.shape_id as string)
        .order("shape_pt_sequence");
      if (shapeError) throw shapeError;

      trace = (shapeRows ?? [])
        .map((row) => pointCoordinates(row.geom))
        .filter((coords): coords is [number, number] => coords !== null)
        .map(([lng, lat]) => [lat, lng]);
    }

    if (stops.length < 2 && trip?.trip_id) {
      const { data: stopTimes, error: stopTimesError } = await supabase
        .from("gtfs_stop_times")
        .select("stop_id, stop_sequence")
        .eq("trip_id", trip.trip_id as string)
        .order("stop_sequence");
      if (stopTimesError) throw stopTimesError;

      const stopIds = [...new Set((stopTimes ?? []).map((row) => row.stop_id as string))];
      if (stopIds.length > 0) {
        const { data: gtfsStops, error: stopsError } = await supabase
          .from("gtfs_stops")
          .select("stop_id, stop_name, geom")
          .in("stop_id", stopIds);
        if (stopsError) throw stopsError;

        const byId = new Map(
          (gtfsStops ?? []).map((row) => [row.stop_id as string, row]),
        );
        stops = (stopTimes ?? [])
          .map((row) => {
            const stop = byId.get(row.stop_id as string);
            const coords = pointCoordinates(stop?.geom);
            if (!stop || !coords) return null;
            return {
              id: stop.stop_id as string,
              name: (stop.stop_name as string) || (stop.stop_id as string),
              lat: coords[1],
              lng: coords[0],
            };
          })
          .filter((stop): stop is LineStop => stop !== null);
      }
    }

    if (depotCode) {
      const activeStops = await loadActiveStops(supabase);
      const depotTimeline = buildDepotTimelineFromSchema(
        depotCode,
        routeId,
        activeStops,
      );
      if (depotTimeline.length >= 2) {
        stops = depotTimeline.map((stop) => ({
          id: stop.stopId,
          name: stop.name,
          lat: stop.coordinates[1],
          lng: stop.coordinates[0],
        }));
      }
    }

    if (trace.length < 2 && stops.length >= 2) {
      trace = stops.map((stop) => [stop.lat, stop.lng]);
    }

    if (trace.length < 2) {
      return NextResponse.json(
        { error: "Aucun tracé disponible pour cette ligne" },
        { status: 404 },
      );
    }

    if (!preferred) {
      try {
        const traceDirectionId =
          trip?.direction_id == null ? null : Number(trip.direction_id);
        schedules = await loadLineSchedules(
          supabase,
          routeId,
          null,
        );
        if (Number.isFinite(traceDirectionId)) {
          schedules = schedules.map((lineSchedule) =>
            lineSchedule.directionId == null
            || lineSchedule.directionId === traceDirectionId
              ? lineSchedule
              : {
                  ...lineSchedule,
                  stops: lineSchedule.stops.map((stop) => ({
                    ...stop,
                    fraction: 1 - stop.fraction,
                  })),
                },
          );
        }
      } catch {
        schedules = [];
      }
    }

    // Tracé manuel prioritaire : si l'itinéraire de la ligne a été édité puis
    // publié depuis l'éditeur (clé = short name, alignée sur driver_services),
    // le suivi ET l'affichage des véhicules en mouvement doivent suivre CE tracé
    // plutôt que le shape GTFS. Les fractions d'arrêt sont recalculées sur la
    // nouvelle géométrie pour que les véhicules restent calés sur leurs horaires.
    try {
      const [routeRes, publishedRes] = await Promise.all([
        supabase
          .from("gtfs_routes")
          .select("route_short_name")
          .eq("route_id", routeId)
          .maybeSingle(),
        supabase.rpc("get_published_line_traces"),
      ]);
      const shortName = (routeRes.data?.route_short_name as string | null)?.trim();
      const published = shortName
        ? ((publishedRes.data as PublishedTraceRow[] | null) ?? []).find(
            (row) => row.line_id === shortName,
          )
        : undefined;
      const manualTrace = published
        ? pickManualTrace(published.variants ?? [], stops)
        : null;

      if (manualTrace && manualTrace.length >= 2) {
        const coordsById = new Map<string, [number, number]>();
        for (const stop of stops) coordsById.set(stop.id, [stop.lat, stop.lng]);
        const missingIds = [
          ...new Set(
            schedules.flatMap((schedule) =>
              schedule.stops
                .map((stop) => stop.stopId)
                .filter((stopId) => !coordsById.has(stopId)),
            ),
          ),
        ];
        if (missingIds.length) {
          const { data: extraStops } = await supabase
            .from("gtfs_stops")
            .select("stop_id, geom")
            .in("stop_id", missingIds);
          for (const row of extraStops ?? []) {
            const coords = pointCoordinates(row.geom);
            if (coords) coordsById.set(String(row.stop_id), [coords[1], coords[0]]);
          }
        }

        trace = manualTrace;
        schedules = schedules.map((schedule) => {
          let running = 0;
          return {
            ...schedule,
            stops: schedule.stops.map((stop) => {
              const coords = coordsById.get(stop.stopId);
              if (!coords) return stop;
              // Monotone croissant : la géométrie manuelle peut faire remonter
              // une projection isolée, mais un arrêt ne recule jamais.
              running = Math.max(running, fractionAlongTrace(manualTrace, coords));
              return { ...stop, fraction: running };
            }),
          };
        });
      }
    } catch {
      // Aucun tracé manuel exploitable : on conserve la géométrie GTFS.
    }

    return NextResponse.json(
      { trace, stops, schedule: schedules[0] ?? null, schedules },
      { headers: { "Cache-Control": "no-store, max-age=0" } },
    );
  } catch {
    return NextResponse.json(
      { error: "Impossible de charger le tracé de la ligne" },
      { status: 500 },
    );
  }
}
