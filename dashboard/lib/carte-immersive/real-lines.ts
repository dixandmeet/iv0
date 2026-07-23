import type { createClient } from "@/lib/supabase/server";
import { buildDepotRegulationLines } from "@/lib/regulation-depot";
import { buildRegulationLines } from "@/lib/regulation-data";
import type { GtfsRoute } from "@/lib/types";
import type { LineEditorState } from "@/lib/line-editor-types";
import type { RegulationLine } from "@/lib/regulation-mock-data";
import { CITY_CENTER } from "./data";
import type { LatLng } from "./geo";
import realLineShapes from "./real-line-shapes.json";
import aleopLineShapes from "./aleop-line-shapes.json";

const CROP_RADIUS_DEG = 0.02;

type RealLineShape = { color: string; type: "bus" | "tram"; variants: LatLng[][] };

/**
 * Géométrie fine (un point tous les ~5-30 m) des lignes Naolib associées aux véhicules de démo,
 * extraite des relations OSM du réseau TAN — les shapes.txt GTFS officiels n'ont qu'un point tous
 * les ~350-500 m et coupent tout droit à travers les bâtiments à ce niveau de zoom.
 * Voir tool/fetch_osm_shapes.py (racine du monorepo) pour le pipeline de génération.
 */
const REAL_LINE_SHAPES = realLineShapes as unknown as Record<string, RealLineShape>;

/** Ne garde que la portion du tracé proche du centre-ville affiché sur la carte immersive. */
function cropAroundCenter(coords: LatLng[]): LatLng[] | null {
  const within = (p: LatLng) => Math.hypot(p[0] - CITY_CENTER[0], p[1] - CITY_CENTER[1]) < CROP_RADIUS_DEG;

  let closestIdx = 0;
  let closestDist = Infinity;
  coords.forEach((p, i) => {
    const d = Math.hypot(p[0] - CITY_CENTER[0], p[1] - CITY_CENTER[1]);
    if (d < closestDist) {
      closestDist = d;
      closestIdx = i;
    }
  });
  if (closestDist > CROP_RADIUS_DEG) return null;

  let start = closestIdx;
  let end = closestIdx;
  while (start > 0 && within(coords[start - 1])) start--;
  while (end < coords.length - 1 && within(coords[end + 1])) end++;

  const cropped = coords.slice(start, end + 1);
  return cropped.length >= 2 ? cropped : null;
}

function bestCroppedVariant(variants: LatLng[][]): LatLng[] | null {
  let best: LatLng[] | null = null;
  for (const variant of variants) {
    const cropped = cropAroundCenter(variant);
    if (cropped && (!best || cropped.length > best.length)) best = cropped;
  }
  return best;
}

/** Tracés réels (rues/rails) des lignes bus/tram affichées sur la carte immersive. */
export function loadRealVehiclePaths(): Record<string, LatLng[]> {
  const result: Record<string, LatLng[]> = {};
  for (const [vehicleId, shape] of Object.entries(REAL_LINE_SHAPES)) {
    const best = bestCroppedVariant(shape.variants);
    if (best) result[vehicleId] = best;
  }
  return result;
}

export type RealLineTrace = { id: string; type: "bus" | "tram"; color: string; coords: LatLng[] };

export type DashboardLineSearchItem = {
  id: string;
  routeId: string;
  shortName: string;
  origin: string;
  destination: string;
  transportType: string;
  depotCode: string;
  color: string;
};

type NetworkLineCatalogRow = {
  network_id: string;
  line_id: string;
  short_name: string;
  long_name: string;
  transport_mode: string;
  color: string;
  data: Partial<RegulationLine> | null;
  editor_state: LineEditorState | null;
};

function transportModeLabel(mode: string): string {
  if (mode === "tram") return "Tramway";
  if (mode === "boat") return "Navibus";
  if (mode === "shuttle") return "Navette";
  return "Bus";
}

function directionEnds(direction: string, longName: string): [string, string] {
  const values = (direction || longName)
    .split(/↔|→/)
    .map((value) => value.trim())
    .filter(Boolean);
  return [values[0] ?? "Départ", values[values.length - 1] ?? "Arrivée"];
}

/** Construit le même catalogue de lignes réseau que le dashboard de régulation. */
export async function loadDashboardLineCatalog(
  supabase: Awaited<ReturnType<typeof createClient>>,
): Promise<DashboardLineSearchItem[]> {
  const [{ data }, { data: networkLineRows }] = await Promise.all([
    supabase
      .from("gtfs_routes")
      .select("route_id, route_short_name, route_long_name, route_type, route_color")
      .order("route_short_name"),
    supabase
      .from("network_lines")
      .select(
        "network_id, line_id, short_name, long_name, transport_mode, color, data, editor_state",
      )
      .order("short_name"),
  ]);

  const routes = (data as GtfsRoute[] | null) ?? [];
  const schemaLines = buildDepotRegulationLines([], []);
  let lines = schemaLines;

  if (routes.length > 0) {
    const gtfsLines = buildRegulationLines(routes, [], []);
    const gtfsById = new Map(gtfsLines.map((line) => [line.id, line]));
    const schemaIds = new Set(schemaLines.map((line) => line.id));
    lines = [
      ...schemaLines.map((line) => gtfsById.get(line.id) ?? line),
      ...gtfsLines.filter((line) => !schemaIds.has(line.id)),
    ];
  }

  const catalog = lines
    .map((line) => ({
      id: line.id,
      routeId: line.routeId,
      shortName: line.shortName,
      origin: line.origin,
      destination: line.destination,
      transportType: line.transportType,
      depotCode: line.depotCode,
      color: line.lineColor,
    }));

  const publishedNetworkLines = ((networkLineRows as NetworkLineCatalogRow[] | null) ?? [])
    .filter((row) => row.editor_state?.status === "published")
    .map((row): DashboardLineSearchItem => {
      const [directionOrigin, directionDestination] = directionEnds(
        row.editor_state?.directionAller ?? "",
        row.long_name,
      );
      return {
        id: `network:${row.network_id}:${row.line_id}`,
        routeId: row.line_id,
        shortName:
          row.editor_state?.shortName?.trim() || row.short_name || row.line_id,
        origin: row.data?.origin?.trim() || directionOrigin,
        destination: row.data?.destination?.trim() || directionDestination,
        transportType: transportModeLabel(
          row.editor_state?.transportMode || row.transport_mode,
        ),
        depotCode: row.data?.depotCode?.trim() || "Réseau",
        color: row.editor_state?.color || row.color || "#2563EB",
      };
    });

  const merged = new Map(catalog.map((line) => [line.id, line]));
  for (const line of publishedNetworkLines) merged.set(line.id, line);

  return [...merged.values()].sort((a, b) =>
    a.shortName.localeCompare(b.shortName, "fr", { numeric: true }),
  );
}

/** Tracés à afficher tels quels sur la carte (transparence : on montre la ligne suivie par chaque véhicule). */
export function loadRealLineTraces(): RealLineTrace[] {
  const traces: RealLineTrace[] = [];
  for (const [vehicleId, shape] of Object.entries(REAL_LINE_SHAPES)) {
    const best = bestCroppedVariant(shape.variants);
    if (best) traces.push({ id: vehicleId, type: shape.type, color: shape.color, coords: best });
  }
  return traces;
}

type AleopLineShape = { id: string; short: string; type: "bus"; color: string; coords: LatLng[] };

// Couleur unique du réseau Aléop : les tracés interurbains doivent se LIRE
// comme un réseau distinct du TAN (dont les lignes ont des couleurs variées).
// Un aplat unique est plus lisible que 29 couleurs GTFS qui se noient dans le
// réseau nantais. Changer ici pour retoucher toute la nappe Aléop.
const ALEOP_LINE_COLOR = "#2FA84F";

/**
 * Tracés des lignes interurbaines Aléop (Loire-Atlantique), affichés en
 * permanence sur la carte immersive à côté du réseau TAN. Contrairement aux
 * lignes TAN (urbaines, rognées autour du centre-ville par cropAroundCenter),
 * on garde les tracés ENTIERS : l'interurbain Aléop rayonne bien au-delà de
 * Nantes et serait tronqué à néant par le rognage à ~2 km. Un point tous les
 * ~40 m (shapes GTFS Aléop, déjà denses). Voir tool/build_network_assets.py.
 */
export function loadAleopLineTraces(): RealLineTrace[] {
  return (aleopLineShapes as unknown as AleopLineShape[]).map((t) => ({
    id: t.id,
    type: t.type,
    color: ALEOP_LINE_COLOR,
    coords: t.coords,
  }));
}

type PublishedLineTraceRow = {
  line_id: string;
  transport_mode: string;
  color: string;
  variants: { direction: "aller" | "retour"; coordinates: [number, number][] }[];
};

type PublishedNetworkTraceRow = {
  line_id: string;
  transport_mode: string;
  color: string;
  editor_state: LineEditorState | null;
};

/**
 * Tracés publiés depuis l'éditeur de ligne (dashboard), clé = shortName de la ligne
 * (aligné sur driver_services.line_id). Remplacent les entrées démo de real-line-shapes.json
 * partageant le même id.
 */
export async function loadPublishedLineTraces(
  supabase: Awaited<ReturnType<typeof createClient>>,
): Promise<RealLineTrace[]> {
  const [{ data }, { data: networkLineRows }] = await Promise.all([
    supabase.rpc("get_published_line_traces"),
    supabase
      .from("network_lines")
      .select("line_id, transport_mode, color, editor_state"),
  ]);
  const rows = (data as PublishedLineTraceRow[] | null) ?? [];

  const traces: RealLineTrace[] = [];
  for (const row of rows) {
    const variant =
      row.variants.find((v) => v.direction === "aller") ??
      row.variants.find((v) => v.direction === "retour");
    if (!variant || variant.coordinates.length < 2) continue;

    traces.push({
      id: row.line_id,
      type: row.transport_mode === "tram" ? "tram" : "bus",
      color: row.color,
      // coordinates éditeur en [lng,lat], LatLng carte immersive en [lat,lng]
      coords: variant.coordinates.map(([lng, lat]) => [lat, lng]),
    });
  }

  // Les états publiés de network_lines constituent la source de repli. Cela
  // rend immédiatement visibles les lignes créées avant la synchronisation RPC.
  const tracedIds = new Set(traces.map((trace) => trace.id));
  for (const row of (networkLineRows as PublishedNetworkTraceRow[] | null) ?? []) {
    const state = row.editor_state;
    if (!state || state.status !== "published") continue;

    const lineId = state.shortName?.trim() || row.line_id;
    if (tracedIds.has(lineId)) continue;

    const points = state.pointsAller ?? [];
    if (points.length < 2) continue;
    traces.push({
      id: lineId,
      type:
        (state.transportMode || row.transport_mode) === "tram" ? "tram" : "bus",
      color: state.color || row.color || "#2563EB",
      coords: points.map(
        (point) => [point.coordinates[1], point.coordinates[0]] as LatLng,
      ),
    });
    tracedIds.add(lineId);
  }
  return traces;
}

/** Fusionne les tracés publiés (prioritaires) avec les tracés démo statiques pour les lignes non publiées. */
export function mergeLineTraces(
  publishedTraces: RealLineTrace[],
  fallbackTraces: RealLineTrace[],
): RealLineTrace[] {
  const publishedIds = new Set(publishedTraces.map((t) => t.id));
  return [...publishedTraces, ...fallbackTraces.filter((t) => !publishedIds.has(t.id))];
}
