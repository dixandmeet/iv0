import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";

type ProfileStop = {
  profile_id: string;
  offset_seconds: number;
};

type TripProfile = {
  profile_id: string;
  route_id: string;
  headsign: string | null;
};

type TripDeparture = {
  departure_id: string;
  profile_id: string;
  service_id: string;
  start_seconds: number;
};

function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function directionScore(headsign: string | null, requested: string): number {
  const actual = normalize(headsign ?? "");
  const aliases = requested
    .split(/[/|]/)
    .map(normalize)
    .filter((value) => value.length >= 3);
  const expected = normalize(requested);
  if (!actual) return 0;
  if (actual === expected) return 100;
  if (actual.includes(expected) || expected.includes(actual)) return 80;
  if (aliases.some((alias) => actual.includes(alias) || alias.includes(actual))) {
    return 70;
  }
  return 0;
}

function validDate(value: string | null): value is string {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T12:00:00Z`);
  return !Number.isNaN(date.getTime());
}

function serviceTime(seconds: number): {
  time: string;
  dayOffset: number;
} {
  const dayOffset = Math.floor(seconds / 86_400);
  const inDay = ((seconds % 86_400) + 86_400) % 86_400;
  const hours = Math.floor(inDay / 3_600);
  const minutes = Math.floor((inDay % 3_600) / 60);
  return {
    time: `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`,
    dayOffset,
  };
}

async function activeServiceIds(
  date: string,
): Promise<{ ids: string[]; error: boolean }> {
  const supabase = createAdminClient();
  if (!supabase) return { ids: [], error: true };
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
  if (regularError || exceptionError) return { ids: [], error: true };

  const removed = new Set(
    (exceptions ?? [])
      .filter((item) => item.exception_type === 2)
      .map((item) => String(item.service_id)),
  );
  const active = new Set(
    (regular ?? [])
      .filter((item) => {
        const runsOn = item.runs_on as boolean[] | null;
        return Boolean(runsOn?.[isoDay - 1]);
      })
      .map((item) => String(item.service_id))
      .filter((serviceId) => !removed.has(serviceId)),
  );
  for (const exception of exceptions ?? []) {
    if (exception.exception_type === 1) active.add(String(exception.service_id));
  }
  return { ids: [...active], error: false };
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const stopName = searchParams.get("name")?.trim() ?? "";
  const line = searchParams.get("line")?.trim() ?? "";
  const direction = searchParams.get("direction")?.trim() ?? "";
  const date = searchParams.get("date");

  if (!stopName || !line || !direction || !validDate(date)) {
    return NextResponse.json(
      { error: "Arrêt, ligne, direction ou date invalide" },
      { status: 400 },
    );
  }

  const supabase = createAdminClient();
  if (!supabase) {
    return NextResponse.json(
      { error: "Horaires théoriques indisponibles" },
      { status: 503 },
    );
  }

  try {
    const [{ data: routes, error: routesError }, { data: stops, error: stopsError }] =
      await Promise.all([
        supabase
          .from("gtfs_routes")
          .select("route_id, route_color, route_type")
          .eq("route_short_name", line),
        supabase
          .from("gtfs_stops")
          .select("stop_id, stop_name")
          .eq("stop_name", stopName)
          .limit(30),
      ]);
    if (routesError || stopsError) throw routesError ?? stopsError;
    const routeIds = (routes ?? []).map((item) => String(item.route_id));
    const stopIds = (stops ?? []).map((item) => String(item.stop_id));
    if (!routeIds.length || !stopIds.length) {
      return NextResponse.json(
        { error: "Aucun horaire GTFS trouvé pour cet arrêt" },
        { status: 404 },
      );
    }

    const { data: rawProfileStops, error: profileStopsError } = await supabase
      .from("gtfs_trip_profile_stops")
      .select("profile_id, offset_seconds")
      .in("stop_id", stopIds);
    if (profileStopsError) throw profileStopsError;
    const profileStops = (rawProfileStops ?? []) as ProfileStop[];
    const profileIds = [...new Set(profileStops.map((item) => item.profile_id))];
    if (!profileIds.length) {
      return NextResponse.json({ date, line, direction, times: [] });
    }

    const { data: rawProfiles, error: profilesError } = await supabase
      .from("gtfs_trip_profiles")
      .select("profile_id, route_id, headsign")
      .in("profile_id", profileIds)
      .in("route_id", routeIds);
    if (profilesError) throw profilesError;
    const profiles = (rawProfiles ?? []) as TripProfile[];
    const scored = profiles.map((profile) => ({
      profile,
      score: directionScore(profile.headsign, direction),
    }));
    const bestScore = Math.max(0, ...scored.map((item) => item.score));
    const selectedProfiles = scored
      .filter((item) => item.score === bestScore && (bestScore > 0 || profiles.length === 1))
      .map((item) => item.profile);
    if (!selectedProfiles.length) {
      return NextResponse.json(
        { error: "Direction introuvable dans les horaires GTFS" },
        { status: 404 },
      );
    }

    const services = await activeServiceIds(date);
    if (services.error) throw new Error("Calendrier GTFS indisponible");
    if (!services.ids.length) {
      return NextResponse.json({ date, line, direction, times: [] });
    }

    const selectedProfileIds = selectedProfiles.map((profile) => profile.profile_id);
    const departures: TripDeparture[] = [];
    const pageSize = 1_000;
    for (let from = 0; ; from += pageSize) {
      const { data, error } = await supabase
        .from("gtfs_trip_departures")
        .select("departure_id, profile_id, service_id, start_seconds")
        .in("profile_id", selectedProfileIds)
        .in("service_id", services.ids)
        .order("start_seconds")
        .range(from, from + pageSize - 1);
      if (error) throw error;
      departures.push(...((data ?? []) as TripDeparture[]));
      if (!data || data.length < pageSize) break;
    }

    const offsets = new Map(
      profileStops
        .filter((item) => selectedProfileIds.includes(item.profile_id))
        .map((item) => [item.profile_id, item.offset_seconds]),
    );
    const routeById = new Map(
      (routes ?? []).map((route) => [String(route.route_id), route]),
    );
    const profileById = new Map(
      selectedProfiles.map((profile) => [profile.profile_id, profile]),
    );
    const scheduledBySeconds = new Map<number, {
      seconds: number;
      departureId: string;
      profileId: string;
      routeId: string;
      vehicleType: "bus" | "tram";
    }>();
    for (const departure of departures) {
      const offset = offsets.get(departure.profile_id);
      const profile = profileById.get(departure.profile_id);
      if (offset == null || !profile) continue;
      const seconds = departure.start_seconds + offset;
      if (seconds < 0 || seconds >= 108_000 || scheduledBySeconds.has(seconds)) continue;
      const route = routeById.get(profile.route_id);
      const routeType = Number(route?.route_type);
      scheduledBySeconds.set(seconds, {
        seconds,
        departureId: departure.departure_id,
        profileId: departure.profile_id,
        routeId: profile.route_id,
        vehicleType: routeType >= 0 && routeType <= 2 ? "tram" : "bus",
      });
    }
    const scheduled = [...scheduledBySeconds.values()].sort(
      (a, b) => a.seconds - b.seconds,
    );

    return NextResponse.json(
      {
        date,
        line,
        direction,
        lineColor: routes?.[0]?.route_color
          ? `#${String(routes[0].route_color).replace(/^#/, "")}`
          : null,
        times: scheduled.map((passage) => ({
          ...passage,
          ...serviceTime(passage.seconds),
        })),
      },
      { headers: { "Cache-Control": "private, max-age=300" } },
    );
  } catch {
    return NextResponse.json(
      { error: "Impossible de charger les horaires de cette journée" },
      { status: 500 },
    );
  }
}
