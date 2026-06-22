import { NextResponse } from "next/server";
import { loadGtfsShapesForLine } from "@/lib/gtfs-shape-loader";
import { routeAlongShapes } from "@/lib/shape-route";
import type { EditorTransportMode } from "@/lib/line-editor-types";

const OSRM_DRIVING = "https://router.project-osrm.org/route/v1/driving";

function parseCoord(raw: string | null): [number, number] | null {
  if (!raw) return null;
  const [lng, lat] = raw.split(",").map((v) => Number(v.trim()));
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
  return [lng, lat];
}

function parseMode(raw: string | null): EditorTransportMode {
  if (raw === "tram" || raw === "boat" || raw === "shuttle") return raw;
  return "bus";
}

async function fetchDrivingSegment(
  from: [number, number],
  to: [number, number],
): Promise<[number, number][]> {
  const url = `${OSRM_DRIVING}/${from[0]},${from[1]};${to[0]},${to[1]}?overview=full&geometries=geojson`;
  const res = await fetch(url, { cache: "no-store" });
  if (!res.ok) {
    throw new Error("Service de routage indisponible");
  }

  const data = (await res.json()) as {
    code?: string;
    routes?: Array<{ geometry?: { coordinates?: [number, number][] } }>;
  };

  const coordinates = data.routes?.[0]?.geometry?.coordinates;
  if (data.code !== "Ok" || !coordinates?.length) {
    throw new Error("Aucun itinéraire trouvé entre ces deux points");
  }

  return coordinates;
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
    const coordinates =
      mode === "tram"
        ? await fetchTramSegment(from, to, lineId)
        : await fetchDrivingSegment(from, to);

    return NextResponse.json({ coordinates });
  } catch (err) {
    const message =
      err instanceof Error ? err.message : "Erreur lors du calcul de l'itinéraire";
    const status = message.includes("indisponible") ? 502 : 404;
    return NextResponse.json({ error: message }, { status });
  }
}
