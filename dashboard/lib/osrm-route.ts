import type { EditorTransportMode } from "@/lib/line-editor-types";

export interface RouteSegmentOptions {
  mode?: EditorTransportMode;
  lineId?: string;
  signal?: AbortSignal;
}

export async function fetchRoadSegment(
  from: [number, number],
  to: [number, number],
  options: RouteSegmentOptions = {},
): Promise<[number, number][]> {
  const { mode = "bus", lineId, signal } = options;

  const params = new URLSearchParams({
    from: `${from[0]},${from[1]}`,
    to: `${to[0]},${to[1]}`,
    mode,
  });
  if (lineId) params.set("lineId", lineId);

  const res = await fetch(`/api/route?${params}`, { signal });
  if (!res.ok) {
    const body = (await res.json().catch(() => null)) as { error?: string } | null;
    throw new Error(body?.error ?? "Impossible de calculer l'itinéraire");
  }

  const data = (await res.json()) as { coordinates: [number, number][] };
  return data.coordinates ?? [];
}
