export type RealtimeStopPassage = {
  id: string;
  line: string;
  direction: string;
  destination: string;
  expectedAt: string;
  waitMinutes: number;
  realtime: boolean;
  directionKey: number | null;
};

export type RealtimeDepartureMatch = {
  waitSeconds: number;
  realtime: boolean;
  expectedAt: string;
  destination: string;
  direction: string;
};

type LogicalStopFeature = {
  properties?: { id?: string | number; name?: string };
};

type LogicalStopsGeoJson = { features?: LogicalStopFeature[] };
type NaolibHour = { time?: string; is_rt?: boolean; destination_label?: string };
type NaolibDirection = {
  direction?: string;
  direction_label?: string;
  hours?: NaolibHour[];
};
type NaolibStopDetail = {
  departures?: Record<string, Record<string, NaolibDirection>>;
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

function directionAliases(value: string): string[] {
  const normalized = normalize(value);
  if (!normalized) return [];
  const aliases = new Set([normalized]);
  for (const part of value.split(/[/|]/)) {
    const candidate = normalize(part);
    if (candidate.length >= 3) aliases.add(candidate);
  }
  return [...aliases];
}

function directionMatchScore(passage: RealtimeStopPassage, headsign: string): number {
  const expected = directionAliases(headsign);
  const actual = [normalize(passage.destination), normalize(passage.direction)].filter(Boolean);
  let best = 0;

  for (const expectedLabel of expected) {
    const expectedTokens = new Set(expectedLabel.split(" ").filter((token) => token.length > 1));
    for (const actualLabel of actual) {
      if (expectedLabel === actualLabel) best = Math.max(best, 100);
      else if (expectedLabel.includes(actualLabel) || actualLabel.includes(expectedLabel)) {
        best = Math.max(best, 80);
      } else {
        const actualTokens = new Set(actualLabel.split(" ").filter((token) => token.length > 1));
        const common = [...expectedTokens].filter((token) => actualTokens.has(token)).length;
        const denominator = Math.max(1, Math.min(expectedTokens.size, actualTokens.size));
        if (common / denominator >= 0.6) best = Math.max(best, 60);
      }
    }
  }
  return best;
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

function expectedDate(waitMinutes: number, now: Date): Date {
  return new Date(
    now.getTime() +
      waitMinutes * 60_000 -
      now.getSeconds() * 1000 -
      now.getMilliseconds(),
  );
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
          expectedAt: expectedDate(waitMinutes, now).toISOString(),
          waitMinutes,
          realtime: Boolean(hour.is_rt),
          directionKey: Number.isFinite(Number(directionKey)) ? Number(directionKey) : null,
        });
      }
    }
  }

  return passages.sort((a, b) => a.waitMinutes - b.waitMinutes);
}

export async function fetchNaolibDepartures(
  stopName: string,
): Promise<{ stopId: string; passages: RealtimeStopPassage[] }> {
  const logicalStopId = await resolveLogicalStopId(stopName);
  if (!logicalStopId) throw new Error("Arrêt Naolib introuvable");

  const response = await fetch(
    `${NAOLIB_PLAN_BASE}/api/stop/logical/${encodeURIComponent(logicalStopId)}`,
    { cache: "no-store", signal: AbortSignal.timeout(8_000) },
  );
  if (!response.ok) throw new Error(`Horaires Naolib ${response.status}`);
  const detail = (await response.json()) as NaolibStopDetail;
  return { stopId: logicalStopId, passages: normalizeDepartures(detail) };
}

export function nextDepartureWaitSeconds(
  passages: RealtimeStopPassage[],
  lineName: string,
  headsign: string | null | undefined,
  readyAt: Date,
): RealtimeDepartureMatch | null {
  const onLine = passages.filter(
    (passage) => normalize(passage.line) === normalize(lineName),
  );
  if (!onLine.length || Number.isNaN(readyAt.getTime())) return null;

  // GTFS direction_id (0/1) et les clés Naolib (1/2) n'ont aucun ordre
  // contractuel commun. On associe donc le passage au terminus annoncé. Sans
  // terminus, le temps réel n'est sûr que si le flux ne contient qu'un sens.
  let candidates: RealtimeStopPassage[];
  if (headsign?.trim()) {
    const scored = onLine
      .map((passage) => ({ passage, score: directionMatchScore(passage, headsign) }))
      .filter(({ score }) => score >= 60);
    if (!scored.length) return null;
    const bestScore = Math.max(...scored.map(({ score }) => score));
    candidates = scored.filter(({ score }) => score === bestScore).map(({ passage }) => passage);
  } else {
    const directions = new Set(
      onLine.map((passage) => normalize(passage.destination || passage.direction)).filter(Boolean),
    );
    if (directions.size !== 1) return null;
    candidates = onLine;
  }

  const readyTimestamp = readyAt.getTime();
  const departure = candidates
    .map((passage) => ({ passage, timestamp: new Date(passage.expectedAt).getTime() }))
    .filter(({ timestamp }) => Number.isFinite(timestamp) && timestamp + 30_000 >= readyTimestamp)
    .sort((a, b) => a.timestamp - b.timestamp)[0];
  if (!departure) return null;
  return {
    waitSeconds: Math.max(0, (departure.timestamp - readyTimestamp) / 1000),
    realtime: departure.passage.realtime,
    expectedAt: departure.passage.expectedAt,
    destination: departure.passage.destination,
    direction: departure.passage.direction,
  };
}
