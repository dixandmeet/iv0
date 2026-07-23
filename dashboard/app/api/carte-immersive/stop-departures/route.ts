import { NextResponse } from "next/server";
import { fetchNaolibDepartures } from "@/lib/carte-immersive/naolib-realtime";
import { createAdminClient } from "@/lib/supabase/admin";

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
const lineColorCache = new Map<string, string>();

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

async function colorsForLines(lines: string[]): Promise<Map<string, string>> {
  const uniqueLines = [...new Set(lines.filter(Boolean))];
  const colors = new Map(
    uniqueLines.flatMap((line) => {
      const color = lineColorCache.get(line);
      return color ? [[line, color] as const] : [];
    }),
  );
  const missingLines = uniqueLines.filter((line) => !colors.has(line));
  if (!missingLines.length) return colors;

  const supabase = createAdminClient();
  if (!supabase) return colors;
  const { data, error } = await supabase
    .from("gtfs_routes")
    .select("route_id, route_short_name, route_color")
    .in("route_short_name", missingLines);
  if (error) return colors;

  for (const line of missingLines) {
    const matches = (data ?? []).filter(
      (route) => String(route.route_short_name ?? "") === line,
    );
    const preferred =
      matches.find((route) => String(route.route_id ?? "") === line) ??
      matches.find((route) => normalizedColor(route.route_color));
    const color = normalizedColor(preferred?.route_color);
    if (color) {
      colors.set(line, color);
      lineColorCache.set(line, color);
    }
  }
  return colors;
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const stopName = searchParams.get("name")?.trim();
  if (!stopName) {
    return NextResponse.json({ error: "Nom d'arrêt manquant" }, { status: 400 });
  }

  try {
    const { stopId: logicalStopId, passages } = await fetchNaolibDepartures(stopName);

    if (!passages.length) {
      return NextResponse.json(
        { error: "Aucun passage prévu dans les trois prochaines heures" },
        { status: 404 },
      );
    }

    const lineColors = await colorsForLines(passages.map((passage) => passage.line));
    return NextResponse.json(
      {
        stopId: logicalStopId,
        passages: passages.map((passage) => ({
          ...passage,
          lineColor:
            lineColors.get(passage.line) ?? fallbackLineColor(passage.line),
        })),
        updatedAt: new Date().toISOString(),
      },
      {
        headers: { "Cache-Control": "no-store" },
      },
    );
  } catch {
    return NextResponse.json(
      { error: "Service temps réel Naolib momentanément indisponible" },
      { status: 502 },
    );
  }
}
