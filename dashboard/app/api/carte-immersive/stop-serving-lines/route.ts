import { NextResponse } from "next/server";
import { createAdminClient } from "@/lib/supabase/admin";

/**
 * Lignes desservant un arrêt (source GTFS statique), avec leur direction.
 *
 * Contrairement à `stop-departures`, cette liste ne dépend pas du temps réel :
 * un arrêt sans passage dans les trois prochaines heures affiche quand même
 * toutes ses lignes, dont on peut ensuite ouvrir les horaires.
 */

type ProfileStop = {
  profile_id: string;
  offset_seconds: number;
};

type TripProfile = {
  profile_id: string;
  route_id: string;
  headsign: string | null;
};

type Route = {
  route_id: string;
  route_short_name: string | null;
  route_color: string | null;
  route_type: number | null;
};

export type StopServingLine = {
  line: string;
  direction: string;
  lineColor: string | null;
  vehicleType: "bus" | "tram";
};

const FALLBACK_LINE_COLORS = [
  "#2563eb",
  "#dc2626",
  "#7c3aed",
  "#0891b2",
  "#ca8a04",
  "#db2777",
  "#0f766e",
  "#ea580c",
];

function normalizedColor(value: string | null | undefined): string | null {
  const hex = value?.trim().replace(/^#/, "");
  return hex && /^[0-9a-f]{6}$/i.test(hex) ? `#${hex.toLowerCase()}` : null;
}

function fallbackLineColor(line: string): string {
  let hash = 0;
  for (const character of line) {
    hash = (hash * 31 + character.charCodeAt(0)) >>> 0;
  }
  return FALLBACK_LINE_COLORS[hash % FALLBACK_LINE_COLORS.length];
}

export async function GET(request: Request) {
  const stopName = new URL(request.url).searchParams.get("name")?.trim() ?? "";
  if (!stopName) {
    return NextResponse.json({ error: "Nom d'arrêt manquant" }, { status: 400 });
  }

  const supabase = createAdminClient();
  if (!supabase) {
    return NextResponse.json(
      { error: "Lignes desservant l'arrêt indisponibles" },
      { status: 503 },
    );
  }

  try {
    const { data: stops, error: stopsError } = await supabase
      .from("gtfs_stops")
      .select("stop_id")
      .eq("stop_name", stopName)
      .limit(30);
    if (stopsError) throw stopsError;

    const stopIds = (stops ?? []).map((item) => String(item.stop_id));
    if (!stopIds.length) {
      return NextResponse.json({ stopName, lines: [] });
    }

    const { data: rawProfileStops, error: profileStopsError } = await supabase
      .from("gtfs_trip_profile_stops")
      .select("profile_id, offset_seconds")
      .in("stop_id", stopIds);
    if (profileStopsError) throw profileStopsError;

    const profileIds = [
      ...new Set(((rawProfileStops ?? []) as ProfileStop[]).map((item) => item.profile_id)),
    ];
    if (!profileIds.length) {
      return NextResponse.json({ stopName, lines: [] });
    }

    const { data: rawProfiles, error: profilesError } = await supabase
      .from("gtfs_trip_profiles")
      .select("profile_id, route_id, headsign")
      .in("profile_id", profileIds);
    if (profilesError) throw profilesError;
    const profiles = (rawProfiles ?? []) as TripProfile[];

    const routeIds = [...new Set(profiles.map((profile) => profile.route_id))];
    if (!routeIds.length) {
      return NextResponse.json({ stopName, lines: [] });
    }

    const { data: rawRoutes, error: routesError } = await supabase
      .from("gtfs_routes")
      .select("route_id, route_short_name, route_color, route_type")
      .in("route_id", routeIds);
    if (routesError) throw routesError;
    const routeById = new Map(
      ((rawRoutes ?? []) as Route[]).map((route) => [String(route.route_id), route]),
    );

    // Une même ligne/direction est portée par plusieurs profils de course :
    // on ne garde qu'une entrée par couple (ligne, destination affichée).
    const byLineDirection = new Map<string, StopServingLine>();
    for (const profile of profiles) {
      const route = routeById.get(profile.route_id);
      const line = route?.route_short_name?.trim();
      const direction = profile.headsign?.trim();
      if (!line || !direction) continue;
      const key = `${line}|${direction}`;
      if (byLineDirection.has(key)) continue;
      const routeType = Number(route?.route_type);
      byLineDirection.set(key, {
        line,
        direction,
        lineColor: normalizedColor(route?.route_color) ?? fallbackLineColor(line),
        vehicleType: routeType >= 0 && routeType <= 2 ? "tram" : "bus",
      });
    }

    const lines = [...byLineDirection.values()].sort(
      (a, b) =>
        a.line.localeCompare(b.line, "fr", { numeric: true }) ||
        a.direction.localeCompare(b.direction, "fr"),
    );

    return NextResponse.json(
      { stopName, lines },
      { headers: { "Cache-Control": "private, max-age=300" } },
    );
  } catch {
    return NextResponse.json(
      { error: "Lignes desservant cet arrêt indisponibles" },
      { status: 502 },
    );
  }
}
