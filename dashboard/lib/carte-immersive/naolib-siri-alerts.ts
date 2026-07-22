import type { TransitAlert } from "@/lib/carte-immersive/transit-route";

export type NaolibServiceAlert = TransitAlert & {
  routeIds: string[];
  startsAt: string | null;
  endsAt: string | null;
};

const SIRI_ENDPOINT = "https://api.okina.fr/gateway/sem/realtime/anshar/siri";
const SIRI_DATASET = "NAOLIBORG";
const CACHE_TTL_MS = 30_000;

let alertCache:
  | { expiresAt: number; promise: Promise<NaolibServiceAlert[]> }
  | undefined;

function escapeXml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function decodeXml(value: string): string {
  return value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, "$1")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/<[^>]+>/g, "")
    .trim();
}

function tagValues(xml: string, tag: string): string[] {
  const expression = new RegExp(
    `<(?:[A-Za-z0-9_-]+:)?${tag}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/(?:[A-Za-z0-9_-]+:)?${tag}>`,
    "gi",
  );
  return [...xml.matchAll(expression)].map((match) => decodeXml(match[1]));
}

function firstTag(xml: string, ...tags: string[]): string | null {
  for (const tag of tags) {
    const value = tagValues(xml, tag)[0];
    if (value) return value;
  }
  return null;
}

function normalizedSeverity(value: string | null): string {
  const normalized = value?.toLowerCase() ?? "";
  if (normalized.includes("severe") || normalized.includes("critical")) return "critical";
  if (normalized.includes("normal") || normalized.includes("warning")) return "warning";
  return "info";
}

function parseSituationExchange(xml: string): NaolibServiceAlert[] {
  const situations = xml.split(/<(?:[A-Za-z0-9_-]+:)?PtSituationElement(?:\s[^>]*)?>/i).slice(1);
  const alerts: NaolibServiceAlert[] = [];
  for (const [index, situationWithTail] of situations.entries()) {
    const situation = situationWithTail.split(
      /<\/(?:[A-Za-z0-9_-]+:)?PtSituationElement>/i,
    )[0];
    const routeIds = [
      ...new Set(
        tagValues(situation, "LineRef")
          .map((routeId) => routeId.trim())
          .filter(Boolean),
      ),
    ];
    const title = firstTag(situation, "Summary", "ReasonName", "Description");
    if (!title) continue;
    alerts.push({
      id: firstTag(situation, "SituationNumber", "ParticipantRef") ?? `naolib-sx-${index}`,
      title,
      message: firstTag(situation, "Description", "Detail", "Advice") ?? "",
      type: firstTag(situation, "MiscellaneousReason", "PublicEvent", "Progress") ?? "disruption",
      severity: normalizedSeverity(firstTag(situation, "Severity")),
      source: "naolib-siri",
      routeIds,
      startsAt: firstTag(situation, "StartTime"),
      endsAt: firstTag(situation, "EndTime"),
    });
  }
  return alerts;
}

async function loadAlerts(): Promise<NaolibServiceAlert[]> {
  const now = new Date().toISOString();
  const messageId = `aule-${Date.now()}`;
  const body = `<?xml version="1.0" encoding="UTF-8"?>
<Siri xmlns="http://www.siri.org.uk/siri" version="2.0">
  <ServiceRequest>
    <RequestTimestamp>${escapeXml(now)}</RequestTimestamp>
    <RequestorRef>AULE</RequestorRef>
    <SituationExchangeRequest version="2.0">
      <RequestTimestamp>${escapeXml(now)}</RequestTimestamp>
      <MessageIdentifier>${escapeXml(messageId)}</MessageIdentifier>
      <PreviewInterval>PT4H</PreviewInterval>
    </SituationExchangeRequest>
  </ServiceRequest>
</Siri>`;
  const url = new URL(SIRI_ENDPOINT);
  url.searchParams.set("datasetId", SIRI_DATASET);
  const apiKey = process.env.NAOLIB_SIRI_API_KEY?.trim();
  if (apiKey) url.searchParams.set("api-key", apiKey);

  const response = await fetch(url, {
    method: "POST",
    headers: { accept: "application/xml", "content-type": "application/xml" },
    body,
    cache: "no-store",
    signal: AbortSignal.timeout(8_000),
  });
  if (!response.ok) throw new Error(`SIRI SituationExchange ${response.status}`);
  return parseSituationExchange(await response.text());
}

export async function fetchNaolibServiceAlerts(): Promise<NaolibServiceAlert[]> {
  // Le portail documente un accès libre mais la passerelle renvoie actuellement
  // 403 sans souscription. Ne pas ralentir le calcul tant qu'aucune clé n'est
  // configurée ; le connecteur s'active automatiquement dès qu'elle l'est.
  if (!process.env.NAOLIB_SIRI_API_KEY?.trim()) return [];
  const now = Date.now();
  if (alertCache && alertCache.expiresAt > now) return alertCache.promise;
  const promise = loadAlerts().catch(() => []);
  alertCache = { expiresAt: now + CACHE_TTL_MS, promise };
  return promise;
}
