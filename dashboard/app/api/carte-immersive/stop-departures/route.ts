import { NextResponse } from "next/server";

type LogicalStopFeature = {
  properties?: { id?: string | number; name?: string };
};

type LogicalStopsGeoJson = { features?: LogicalStopFeature[] };

type NaolibHour = {
  time?: string;
  is_rt?: boolean;
  destination_label?: string;
};

type NaolibDirection = {
  direction?: string;
  direction_label?: string;
  hours?: NaolibHour[];
};

type NaolibStopDetail = {
  departures?: Record<string, Record<string, NaolibDirection>>;
};

export type RealtimeStopPassage = {
  id: string;
  line: string;
  direction: string;
  destination: string;
  expectedAt: string;
  waitMinutes: number;
  realtime: boolean;
};

const NAOLIB_PLAN_BASE = "https://plan.naolib.fr";

function normalize(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function parisClockMinutes(date: Date): number {
  const parts = new Intl.DateTimeFormat("fr-FR", {
    timeZone: "Europe/Paris",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(date);
  const hour = Number(parts.find((part) => part.type === "hour")?.value ?? 0);
  const minute = Number(parts.find((part) => part.type === "minute")?.value ?? 0);
  return hour * 60 + minute;
}

function waitForTime(time: string, now: Date): number | null {
  const match = time.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return null;
  const targetMinutes = Number(match[1]) * 60 + Number(match[2]);
  let waitMinutes = targetMinutes - parisClockMinutes(now);
  if (waitMinutes < -120) waitMinutes += 24 * 60;
  if (waitMinutes < 0 || waitMinutes > 180) return null;
  return waitMinutes;
}

async function resolveLogicalStopId(stopName: string): Promise<string | null> {
  const response = await fetch(`${NAOLIB_PLAN_BASE}/map/logical_stops.geojson`, {
    next: { revalidate: 86_400 },
  });
  if (!response.ok) throw new Error(`Catalogue Naolib ${response.status}`);
  const data = (await response.json()) as LogicalStopsGeoJson;
  const normalizedName = normalize(stopName);
  const feature = data.features?.find(
    (item) => normalize(item.properties?.name ?? "") === normalizedName,
  );
  const id = feature?.properties?.id;
  return id == null ? null : String(id);
}

function normalizeDepartures(detail: NaolibStopDetail): RealtimeStopPassage[] {
  const now = new Date();
  const passages: RealtimeStopPassage[] = [];

  for (const [lineKey, directions] of Object.entries(detail.departures ?? {})) {
    for (const [directionKey, direction] of Object.entries(directions ?? {})) {
      for (const [index, hour] of (direction.hours ?? []).entries()) {
        if (!hour.time) continue;
        const waitMinutes = waitForTime(hour.time, now);
        if (waitMinutes == null) continue;
        passages.push({
          id: `${lineKey}-${directionKey}-${hour.time}-${index}`,
          line: lineKey,
          direction: direction.direction || direction.direction_label || "Direction non renseignée",
          destination:
            hour.destination_label || direction.direction_label || direction.direction || "Destination",
          expectedAt: new Date(now.getTime() + waitMinutes * 60_000).toISOString(),
          waitMinutes,
          realtime: Boolean(hour.is_rt),
        });
      }
    }
  }

  return passages.sort((a, b) => a.waitMinutes - b.waitMinutes);
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const stopName = searchParams.get("name")?.trim();
  if (!stopName) {
    return NextResponse.json({ error: "Nom d'arrêt manquant" }, { status: 400 });
  }

  try {
    const logicalStopId = await resolveLogicalStopId(stopName);
    if (!logicalStopId) {
      return NextResponse.json({ error: "Arrêt Naolib introuvable" }, { status: 404 });
    }

    const response = await fetch(
      `${NAOLIB_PLAN_BASE}/api/stop/logical/${encodeURIComponent(logicalStopId)}`,
      { cache: "no-store", signal: AbortSignal.timeout(8_000) },
    );
    if (!response.ok) throw new Error(`Horaires Naolib ${response.status}`);
    const detail = (await response.json()) as NaolibStopDetail;
    const passages = normalizeDepartures(detail);

    if (!passages.length) {
      return NextResponse.json(
        { error: "Aucun passage prévu dans les trois prochaines heures" },
        { status: 404 },
      );
    }

    return NextResponse.json({
      stopId: logicalStopId,
      passages,
      updatedAt: new Date().toISOString(),
    });
  } catch {
    return NextResponse.json(
      { error: "Service temps réel Naolib momentanément indisponible" },
      { status: 502 },
    );
  }
}
