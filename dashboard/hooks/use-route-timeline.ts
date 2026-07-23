"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { pointCoordinates } from "@/lib/geo";
import type { GtfsStop } from "@/lib/types";
import {
  buildStopsFromShape,
  mapStopTimesToTimeline,
  type RouteTimelinePoint,
} from "@/lib/regulation-data";
import {
  buildDepotTimelinesFromSchema,
  resolveDepotStopsToTimeline,
} from "@/lib/regulation-depot";
import { getDepotLineByCompositeId, parseLineId } from "@/lib/depot-lines";
import { getNetworkLinePatterns } from "@/lib/network-line-patterns";
import { isCustomRegulationLine } from "@/lib/regulation-custom-line";
import {
  buildLineTopologyFromEditorState,
  buildLineTopologyFromTrips,
  resolveActiveVariant,
  stopsForVariant,
  type LineTopology,
  type TripStopSequence,
} from "@/lib/line-topology";
import type { LineEditorState } from "@/lib/line-editor-types";

async function fetchAllStops(supabase: ReturnType<typeof createClient>): Promise<GtfsStop[]> {
  const pageSize = 1000;
  let from = 0;
  const all: GtfsStop[] = [];

  while (true) {
    const { data, error } = await supabase
      .from("stops")
      .select("id, code, name, geom, station_id, stations(name)")
      .eq("status", "active")
      .range(from, from + pageSize - 1);

    if (error) throw error;
    if (!data?.length) break;

    for (const row of data) {
      const station = row.stations as { name: string } | { name: string }[] | null;
      const stationName = Array.isArray(station) ? station[0]?.name : station?.name;
      all.push({
        stop_id: row.code as string,
        stop_name: (row.name as string) ?? stationName ?? (row.code as string),
        station_id: row.station_id as string,
        geom: row.geom as GtfsStop["geom"],
      });
    }

    if (data.length < pageSize) break;
    from += pageSize;
  }

  return all;
}

type StopRow = {
  code: string;
  name: string | null;
  geom: unknown;
  station_id: string;
  stations: { name: string } | { name: string }[];
};

async function resolveStopMapping(
  supabase: ReturnType<typeof createClient>,
  gtfsIds: string[],
): Promise<Map<string, { code: string; name: string; geom: unknown; stationId?: string }>> {
  const stopByGtfs = new Map<
    string,
    { code: string; name: string; geom: unknown; stationId?: string }
  >();

  if (gtfsIds.length === 0) return stopByGtfs;

  const { data: mappings } = await supabase
    .from("gtfs_stop_mapping")
    .select("gtfs_stop_id, stops(code, name, geom, station_id, stations(name))")
    .in("gtfs_stop_id", gtfsIds);

  for (const m of mappings ?? []) {
    const stopRow = m.stops as StopRow | StopRow[] | null;
    const stop = Array.isArray(stopRow) ? stopRow[0] : stopRow;
    if (!stop) continue;
    const station = stop.stations;
    const stationName = Array.isArray(station) ? station[0]?.name : station?.name;
    stopByGtfs.set(m.gtfs_stop_id as string, {
      code: stop.code,
      name: stop.name ?? stationName ?? stop.code,
      geom: stop.geom,
      stationId: stop.station_id,
    });
  }

  return stopByGtfs;
}

async function fetchTripSequence(
  supabase: ReturnType<typeof createClient>,
  tripId: string,
  headsign: string,
  directionId: number,
  shapeId: string | null,
): Promise<TripStopSequence | null> {
  const { data: stopTimes, error } = await supabase
    .from("gtfs_stop_times")
    .select("stop_sequence, arrival_time, stop_id")
    .eq("trip_id", tripId)
    .order("stop_sequence");

  if (error) throw error;
  if (!stopTimes || stopTimes.length < 2) return null;

  const gtfsIds = stopTimes.map((r) => r.stop_id as string);
  const stopByGtfs = await resolveStopMapping(supabase, gtfsIds);

  const stops = mapStopTimesToTimeline(
    stopTimes.map((row) => ({
      ...row,
      stop_id: row.stop_id as string,
      stop: stopByGtfs.get(row.stop_id as string) ?? null,
    })),
  );

  if (stops.length < 2) return null;

  return {
    tripId,
    headsign,
    directionId,
    shapeId,
    stopIds: stops.map((s) => s.stopId),
    stops,
  };
}

async function fetchRouteTripSequences(
  supabase: ReturnType<typeof createClient>,
  gtfsRouteId: string,
  preferredTripId?: string | null,
): Promise<TripStopSequence[]> {
  const { data: trips, error } = await supabase
    .from("gtfs_trips")
    .select("trip_id, direction_id, shape_id")
    .eq("route_id", gtfsRouteId)
    .order("trip_id")
    .limit(400);

  if (error) throw error;
  if (!trips?.length) return [];

  const representativeTrips: typeof trips = [];
  const seenKeys = new Set<string>();

  if (preferredTripId) {
    const preferred = trips.find((t) => t.trip_id === preferredTripId);
    if (preferred) representativeTrips.push(preferred);
  }

  for (const trip of trips) {
    const variantKey = `${trip.direction_id}|${trip.shape_id ?? trip.trip_id}`;
    if (seenKeys.has(variantKey)) continue;
    seenKeys.add(variantKey);
    if (trip.trip_id === preferredTripId) continue;
    representativeTrips.push(trip);
  }

  const seenSequences = new Set<string>();
  const sequences: TripStopSequence[] = [];

  for (const trip of representativeTrips) {
    try {
      const seq = await fetchTripSequence(
        supabase,
        trip.trip_id as string,
        "",
        (trip.direction_id as number) ?? 0,
        (trip.shape_id as string) ?? null,
      );
      if (!seq) continue;

      const key = seq.stopIds.join(">");
      if (seenSequences.has(key)) continue;
      seenSequences.add(key);
      sequences.push(seq);
    } catch {
      // Course sans stop_times valides — on essaie la suivante
      continue;
    }
  }

  return sequences;
}

async function fetchSingleTripSequence(
  supabase: ReturnType<typeof createClient>,
  gtfsRouteId: string,
  preferredTripId?: string | null,
): Promise<TripStopSequence | null> {
  let tripId = preferredTripId ?? null;
  const headsign = "";
  let directionId = 0;
  let shapeId: string | null = null;

  if (tripId) {
    const { data: trip } = await supabase
      .from("gtfs_trips")
      .select("trip_id, direction_id, shape_id")
      .eq("trip_id", tripId)
      .maybeSingle();
    if (trip) {
      directionId = (trip.direction_id as number) ?? 0;
      shapeId = (trip.shape_id as string) ?? null;
    } else {
      tripId = null;
    }
  }

  if (!tripId) {
    const { data: trips } = await supabase
      .from("gtfs_trips")
      .select("trip_id, direction_id, shape_id")
      .eq("route_id", gtfsRouteId)
      .order("trip_id")
      .limit(1);
    const trip = trips?.[0];
    if (!trip) return null;
    tripId = trip.trip_id as string;
    directionId = (trip.direction_id as number) ?? 0;
    shapeId = (trip.shape_id as string) ?? null;
  }

  return fetchTripSequence(supabase, tripId, headsign, directionId, shapeId);
}

interface UseRouteTimelineOptions {
  routeId: string | null;
  preferredTripId?: string | null;
  selectedVariantId?: string | null;
  editorState?: LineEditorState | null;
  enabled?: boolean;
}

export function useRouteTimeline({
  routeId,
  preferredTripId,
  selectedVariantId,
  editorState = null,
  enabled = true,
}: UseRouteTimelineOptions) {
  const [topologyResult, setTopologyResult] = useState<{
    routeId: string | null;
    topology: LineTopology | null;
  }>({ routeId: null, topology: null });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const loadRequestRef = useRef(0);

  const loadTimeline = useCallback(async () => {
    const requestId = ++loadRequestRef.current;
    const commitTopology = (topology: LineTopology | null) => {
      if (loadRequestRef.current !== requestId) return false;
      setTopologyResult({ routeId, topology });
      return true;
    };

    if (!routeId || !enabled) {
      commitTopology(null);
      setLoading(false);
      return;
    }

    if (editorState) {
      commitTopology(buildLineTopologyFromEditorState(editorState));
      setError(null);
      setLoading(false);
      return;
    }

    if (isCustomRegulationLine(routeId)) {
      commitTopology(null);
      setError(null);
      setLoading(false);
      return;
    }

    setLoading(true);
    setError(null);
    const supabase = createClient();
    const { routeId: gtfsRouteId } = parseLineId(routeId);

    try {
      const depotLine = getDepotLineByCompositeId(routeId);
      if (depotLine) {
        const allStops = await fetchAllStops(supabase);
        const schemaTimelines = buildDepotTimelinesFromSchema(
          depotLine.depotCode,
          depotLine.id,
          allStops,
        );
        if (schemaTimelines.length > 0) {
          const tripSequences: TripStopSequence[] = schemaTimelines.map((variant) => ({
            tripId: `depot-${routeId}-${variant.id}`,
            headsign: variant.destination,
            directionId: 0,
            shapeId: null,
            stopIds: variant.stops.map((stop) => stop.stopId),
            stops: variant.stops,
          }));
          commitTopology(buildLineTopologyFromTrips(tripSequences));
          return;
        }
      }

      const networkPatterns = getNetworkLinePatterns(gtfsRouteId);
      if (networkPatterns.length > 0) {
        const allStops = await fetchAllStops(supabase);
        const patternSequences: TripStopSequence[] = networkPatterns.map((pattern) => {
          const stops = resolveDepotStopsToTimeline(
            pattern.stops,
            allStops,
            `network-${gtfsRouteId}`,
          );
          return {
            tripId: `network-${gtfsRouteId}-${pattern.id}`,
            headsign: pattern.destination,
            directionId: 0,
            shapeId: null,
            stopIds: stops.map((stop) => stop.stopId),
            stops,
          };
        });
        const patternTopology = buildLineTopologyFromTrips(patternSequences);
        if (patternTopology) {
          commitTopology(patternTopology);
          return;
        }
      }

      let sequences: TripStopSequence[] = [];
      try {
        sequences = await fetchRouteTripSequences(
          supabase,
          gtfsRouteId,
          preferredTripId,
        );
      } catch {
        sequences = [];
      }

      if (sequences.length > 0) {
        try {
          commitTopology(buildLineTopologyFromTrips(sequences));
          return;
        } catch {
          commitTopology(buildLineTopologyFromTrips([sequences[0]]));
          return;
        }
      }

      const single = await fetchSingleTripSequence(
        supabase,
        gtfsRouteId,
        preferredTripId,
      );
      if (single) {
        commitTopology(buildLineTopologyFromTrips([single]));
        return;
      }

      // Repli shape unique
      const { data: trips } = await supabase
        .from("gtfs_trips")
        .select("trip_id, shape_id, direction_id")
        .eq("route_id", gtfsRouteId)
        .order("trip_id")
        .limit(1);

      const shapeId = trips?.[0]?.shape_id ?? null;
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
          const stops = buildStopsFromShape(shapeCoords, allStops);
          if (stops.length >= 2) {
            const tripSeq: TripStopSequence = {
              tripId: trips?.[0]?.trip_id as string,
              headsign: "",
              directionId: (trips?.[0]?.direction_id as number) ?? 0,
              shapeId,
              stopIds: stops.map((s) => s.stopId),
              stops,
            };
            commitTopology(buildLineTopologyFromTrips([tripSeq]));
            return;
          }
        }
      }

      commitTopology(null);
    } catch (err) {
      if (loadRequestRef.current !== requestId) return;
      setError(err instanceof Error ? err.message : "Erreur chargement frise");
      commitTopology(null);
    } finally {
      if (loadRequestRef.current === requestId) setLoading(false);
    }
  }, [routeId, preferredTripId, editorState, enabled]);

  useEffect(() => {
    void loadTimeline();
  }, [loadTimeline]);

  const topology =
    topologyResult.routeId === routeId ? topologyResult.topology : null;
  const timelinePending = Boolean(
    enabled &&
      routeId &&
      !isCustomRegulationLine(routeId) &&
      topologyResult.routeId !== routeId,
  );

  const activeVariant = useMemo(() => {
    if (!topology) return null;
    return resolveActiveVariant(topology, selectedVariantId, preferredTripId);
  }, [topology, selectedVariantId, preferredTripId]);

  const timelineStops = useMemo((): RouteTimelinePoint[] => {
    if (!activeVariant) return [];
    return stopsForVariant(activeVariant);
  }, [activeVariant]);

  return {
    topology,
    timelineStops,
    activeVariant,
    loading: loading || timelinePending,
    error,
    refresh: loadTimeline,
  };
}
