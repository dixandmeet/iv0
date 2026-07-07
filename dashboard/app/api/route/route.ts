import { NextResponse } from "next/server";
import { loadGtfsShapesForLine } from "@/lib/gtfs-shape-loader";
import { routeAlongShapes } from "@/lib/shape-route";
import { computeTransitRoute } from "@/lib/carte-immersive/transit-route";
import type { EditorTransportMode } from "@/lib/line-editor-types";

const OSRM_BASE = "https://router.project-osrm.org/route/v1";
// Le profil piéton du serveur public OSRM renvoie des durées irréalistes (vitesse proche du vélo).
// On recalcule donc la durée de marche à partir d'une vitesse standard plutôt que de faire confiance à OSRM.
const WALK_SPEED_MPS = 1.35;

type OsrmSegment = { coordinates: [number, number][]; distance: number; duration: number };

function parseCoord(raw: string | null): [number, number] | null {
  if (!raw) return null;
  const [lng, lat] = raw.split(",").map((v) => Number(v.trim()));
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return [lng, lat];
}

function parseMode(raw: string | null): EditorTransportMode | "foot" | "car" | "transit" {
  if (
    raw === "tram" ||
    raw === "boat" ||
    raw === "shuttle" ||
    raw === "foot" ||
    raw === "car" ||
    raw === "transit"
  ) {
    return raw;
  }
  return "bus";
}

async function fetchOsrmSegment(
  profile: "driving" | "foot",
  from: [number, number],
  to: [number, number],
): Promise<OsrmSegment> {
  const url = `${OSRM_BASE}/${profile}/${from[0]},${from[1]};${to[0]},${to[1]}?overview=full&geometries=geojson`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) {
    throw new Error("Service de routage indisponible");
  }

  const data = (await res.json()) as {
    code?: string;
    routes?: Array<{
      geometry?: { coordinates?: [number, number][] };
      distance?: number;
      duration?: number;
    }>;
  };

  const routeResult = data.routes?.[0];
  const coordinates = routeResult?.geometry?.coordinates;
  if (data.code !== "Ok" || !coordinates?.length) {
    throw new Error("Aucun itinéraire trouvé entre ces deux points");
  }

  const distance = routeResult?.distance ?? 0;
  return {
    coordinates,
    distance,
    duration: profile === "foot" ? distance / WALK_SPEED_MPS : (routeResult?.duration ?? 0),
  };
}

async function fetchTramSegment(
  from: [number, number],
  to: [number, number],
  lineId: string | undefined,
): Promise<[number, number][]> {
  const shapes = await loadGtfsShapesForLine(lineId);
  const segment = routeAlongShapes(shapes, from, to);

  if (!segment || segment.length < 2) {
    throw new Error(
      "Aucun tracé tramway GTFS trouvé près de ces points — vérifiez le positionnement des arrêts",
    );
  }

  return segment;
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const from = parseCoord(searchParams.get("from"));
  const to = parseCoord(searchParams.get("to"));
  const mode = parseMode(searchParams.get("mode"));
  const lineId = searchParams.get("lineId")?.trim() || undefined;

  if (!from || !to) {
    return NextResponse.json(
      { error: "Coordonnées de départ ou d'arrivée invalides" },
      { status: 400 },
    );
  }

  try {
    if (mode === "tram") {
      const coordinates = await fetchTramSegment(from, to, lineId);
      return NextResponse.json({ coordinates });
    }

    if (mode === "transit") {
      const result = await computeTransitRoute(from, to, (a, b) => fetchOsrmSegment("foot", a, b));
      return NextResponse.json(result);
    }

    const segment = await fetchOsrmSegment(mode === "foot" ? "foot" : "driving", from, to);
    return NextResponse.json(segment);
  } catch (err) {
    const message =
      err instanceof Error ? err.message : "Erreur lors du calcul de l'itinéraire";
    const status = message.includes("indisponible") ? 502 : 404;
    return NextResponse.json({ error: message }, { status });
  }
}
