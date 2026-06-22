import { createClient } from "@/lib/supabase/server";
import { pointCoordinates } from "@/lib/geo";
import { gtfsRouteIdFromLineId } from "@/lib/depot-types";

const MAX_SHAPES = 48;
const MAX_POINTS_PER_SHAPE = 4000;

async function loadShapeCoords(
  supabase: Awaited<ReturnType<typeof createClient>>,
  shapeId: string,
): Promise<[number, number][] | null> {
  const { data: shapePts } = await supabase
    .from("gtfs_shapes")
    .select("shape_pt_sequence, geom")
    .eq("shape_id", shapeId)
    .order("shape_pt_sequence")
    .limit(MAX_POINTS_PER_SHAPE);

  if (!shapePts?.length) return null;

  const coords = shapePts
    .map((row) => pointCoordinates(row.geom))
    .filter((coord): coord is [number, number] => coord != null);

  return coords.length >= 2 ? coords : null;
}

/** Charge les tracés GTFS associés à une ligne (ex. TRAM:1 → route_id 1). */
export async function loadGtfsShapesForLine(
  lineId: string | undefined,
): Promise<[number, number][][]> {
  const supabase = await createClient();
  const gtfsRouteId = lineId ? gtfsRouteIdFromLineId(lineId) : null;

  if (gtfsRouteId) {
    const { data: trips } = await supabase
      .from("gtfs_trips")
      .select("shape_id")
      .eq("route_id", gtfsRouteId)
      .not("shape_id", "is", null);

    const shapeIds = [
      ...new Set(
        (trips ?? [])
          .map((trip) => trip.shape_id as string | null)
          .filter((id): id is string => Boolean(id)),
      ),
    ].slice(0, MAX_SHAPES);

    const shapes: [number, number][][] = [];
    for (const shapeId of shapeIds) {
      const coords = await loadShapeCoords(supabase, shapeId);
      if (coords) shapes.push(coords);
    }
    if (shapes.length > 0) return shapes;
  }

  const { data: tramRoutes } = await supabase
    .from("gtfs_routes")
    .select("route_id")
    .eq("route_type", 0)
    .limit(20);

  const shapes: [number, number][][] = [];
  for (const route of tramRoutes ?? []) {
    const { data: trips } = await supabase
      .from("gtfs_trips")
      .select("shape_id")
      .eq("route_id", route.route_id as string)
      .not("shape_id", "is", null)
      .limit(8);

    const shapeIds = [
      ...new Set(
        (trips ?? [])
          .map((trip) => trip.shape_id as string | null)
          .filter((id): id is string => Boolean(id)),
      ),
    ];

    for (const shapeId of shapeIds) {
      if (shapes.length >= MAX_SHAPES) break;
      const coords = await loadShapeCoords(supabase, shapeId);
      if (coords) shapes.push(coords);
    }
    if (shapes.length >= MAX_SHAPES) break;
  }

  return shapes;
}
