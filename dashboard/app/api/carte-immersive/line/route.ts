import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { pointCoordinates } from "@/lib/geo";
import { parseLineId } from "@/lib/depot-lines";
import { buildDepotTimelineFromSchema } from "@/lib/regulation-depot";
import type { GtfsStop } from "@/lib/types";

type LineStop = {
  id: string;
  name: string;
  lat: number;
  lng: number;
};

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

export async function GET(request: Request) {
  const lineId = new URL(request.url).searchParams.get("lineId")?.trim();
  if (!lineId) {
    return NextResponse.json({ error: "Identifiant de ligne manquant" }, { status: 400 });
  }

  const { depotCode, routeId } = parseLineId(lineId);
  const supabase = await createClient();

  try {
    const { data: trips, error: tripsError } = await supabase
      .from("gtfs_trips")
      .select("trip_id, shape_id, direction_id")
      .eq("route_id", routeId)
      .order("direction_id")
      .order("trip_id")
      .limit(40);
    if (tripsError) throw tripsError;

    const trip = trips?.find((item) => item.shape_id) ?? trips?.[0] ?? null;
    let trace: [number, number][] = [];
    let stops: LineStop[] = [];

    if (trip?.shape_id) {
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

    if (trip?.trip_id) {
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

    return NextResponse.json({ trace, stops });
  } catch {
    return NextResponse.json(
      { error: "Impossible de charger le tracé de la ligne" },
      { status: 500 },
    );
  }
}
