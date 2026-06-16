"use client";

import { useCallback, useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { pointCoordinates } from "@/lib/geo";
import type { GtfsStop } from "@/lib/types";
import {
  buildStopsFromShape,
  mapStopTimesToTimeline,
  type RouteTimelinePoint,
} from "@/lib/regulation-data";
import { buildDepotTimelineFromSchema } from "@/lib/regulation-depot";
import { getDepotLineByCompositeId, parseLineId } from "@/lib/depot-lines";

async function fetchAllStops(supabase: ReturnType<typeof createClient>): Promise<GtfsStop[]> {
  const pageSize = 1000;
  let from = 0;
  const all: GtfsStop[] = [];

  while (true) {
    const { data, error } = await supabase
      .from("gtfs_stops")
      .select("stop_id, stop_name, geom")
      .range(from, from + pageSize - 1);

    if (error) throw error;
    if (!data?.length) break;

    all.push(...(data as GtfsStop[]));
    if (data.length < pageSize) break;
    from += pageSize;
  }

  return all;
}

interface UseRouteTimelineOptions {
  routeId: string | null;
  preferredTripId?: string | null;
  enabled?: boolean;
}

export function useRouteTimeline({
  routeId,
  preferredTripId,
  enabled = true,
}: UseRouteTimelineOptions) {
  const [timelineStops, setTimelineStops] = useState<RouteTimelinePoint[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadTimeline = useCallback(async () => {
    if (!routeId || !enabled) {
      setTimelineStops([]);
      return;
    }

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { depotCode, routeId: gtfsRouteId } = parseLineId(routeId);

    try {
      const depotLine = getDepotLineByCompositeId(routeId);
      if (depotLine) {
        const allStops = await fetchAllStops(supabase);
        const schemaTimeline = buildDepotTimelineFromSchema(
          depotLine.depotCode,
          depotLine.id,
          allStops,
        );
        if (schemaTimeline.length >= 2) {
          setTimelineStops(schemaTimeline);
          return;
        }
      }

      let tripId = preferredTripId ?? null;
      let shapeId: string | null = null;

      if (tripId) {
        const { data: trip } = await supabase
          .from("gtfs_trips")
          .select("trip_id, shape_id")
          .eq("trip_id", tripId)
          .maybeSingle();
        shapeId = trip?.shape_id ?? null;
      } else {
        const { data: trips } = await supabase
          .from("gtfs_trips")
          .select("trip_id, shape_id")
          .eq("route_id", gtfsRouteId)
          .order("trip_id")
          .limit(1);
        tripId = trips?.[0]?.trip_id ?? null;
        shapeId = trips?.[0]?.shape_id ?? null;
      }

      if (tripId) {
        const { data: stopTimes, error: stopTimesError } = await supabase
          .from("gtfs_stop_times")
          .select(
            "stop_sequence, arrival_time, stop_id, gtfs_stops(stop_id, stop_name, geom)",
          )
          .eq("trip_id", tripId)
          .order("stop_sequence");

        if (stopTimesError) throw stopTimesError;

        if (stopTimes && stopTimes.length >= 2) {
          setTimelineStops(mapStopTimesToTimeline(stopTimes));
          return;
        }
      }

      if (shapeId) {
        const [{ data: shapeRows, error: shapeError }, allStops] = await Promise.all([
          supabase
            .from("gtfs_shapes")
            .select("shape_pt_sequence, geom")
            .eq("shape_id", shapeId)
            .order("shape_pt_sequence"),
          fetchAllStops(supabase),
        ]);

        if (shapeError) throw shapeError;

        const shapeCoords = (shapeRows ?? [])
          .map((row) => pointCoordinates(row.geom))
          .filter((c): c is [number, number] => c !== null);

        if (shapeCoords.length >= 2) {
          setTimelineStops(buildStopsFromShape(shapeCoords, allStops));
          return;
        }
      }

      setTimelineStops([]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erreur chargement frise");
      setTimelineStops([]);
    } finally {
      setLoading(false);
    }
  }, [routeId, preferredTripId, enabled]);

  useEffect(() => {
    void loadTimeline();
  }, [loadTimeline]);

  return { timelineStops, loading, error, refresh: loadTimeline };
}
