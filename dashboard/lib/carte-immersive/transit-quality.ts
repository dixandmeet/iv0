export type TransitPathLeg = {
  type?: "walk" | "transit";
  kind?: "access" | "transfer" | "egress";
  route_id?: string;
  from_stop_id?: string;
  to_stop_id?: string;
  from_name?: string;
  to_name?: string;
};

export type TransitQualityCandidate = {
  id: string;
  duration: number;
  departureAt?: string;
  arrivalAt?: string;
  transfers: number;
  walkSeconds?: number;
  waitSeconds?: number;
  alertPenaltySeconds?: number;
  routeIds?: string[];
};

function timestamp(value: string | undefined): number | null {
  if (!value) return null;
  const parsed = new Date(value).getTime();
  return Number.isFinite(parsed) ? parsed : null;
}

export function transitRouteRefreshDelay(
  departureAt: string | undefined,
  now = new Date(),
  graceMs = 1_000,
): number | null {
  const departure = timestamp(departureAt);
  if (departure == null) return null;
  return Math.max(0, departure + Math.max(0, graceMs) - now.getTime());
}

export function canBoardScheduledDeparture(
  scheduledDeparture: Date,
  readyAt: Date,
  toleranceSeconds = 30,
): boolean {
  return scheduledDeparture.getTime() + toleranceSeconds * 1000 >= readyAt.getTime();
}

export function journeyPathKey(
  routeIds: string[],
  legs: TransitPathLeg[],
  departureAt?: string,
): string {
  const departure = timestamp(departureAt) ?? 0;
  const roundedDeparture = Math.round(departure / 60_000);
  const path = legs
    .filter((leg) => leg.type === "transit" || leg.kind === "transfer")
    .map((leg) =>
      [
        leg.type ?? "?",
        leg.route_id ?? "walk",
        leg.from_stop_id ?? leg.from_name ?? "?",
        leg.to_stop_id ?? leg.to_name ?? "?",
      ].join(":"),
    )
    .join("|");
  return `${routeIds.join(">")}@${roundedDeparture}:${path}`;
}

function arrivalTimestamp(candidate: TransitQualityCandidate): number {
  const arrival = timestamp(candidate.arrivalAt);
  if (arrival != null) return arrival;
  const departure = timestamp(candidate.departureAt) ?? 0;
  return departure + Math.max(0, candidate.duration) * 1000;
}

function dominates(a: TransitQualityCandidate, b: TransitQualityCandidate): boolean {
  const arrivalA = arrivalTimestamp(a);
  const arrivalB = arrivalTimestamp(b);
  const walkA = a.walkSeconds ?? 0;
  const walkB = b.walkSeconds ?? 0;
  const alertsA = a.alertPenaltySeconds ?? 0;
  const alertsB = b.alertPenaltySeconds ?? 0;
  const noWorse =
    arrivalA <= arrivalB + 30_000 &&
    walkA <= walkB &&
    a.transfers <= b.transfers &&
    alertsA <= alertsB;
  const strictlyBetter =
    arrivalA < arrivalB - 30_000 ||
    walkA < walkB ||
    a.transfers < b.transfers ||
    alertsA < alertsB;
  return noWorse && strictlyBetter;
}

export function transitQualityScore(
  candidate: TransitQualityCandidate,
  requestedAt: Date,
): number {
  const elapsedSeconds = Math.max(
    0,
    (arrivalTimestamp(candidate) - requestedAt.getTime()) / 1000,
  );
  const walkSeconds = candidate.walkSeconds ?? 0;
  const waitSeconds = candidate.waitSeconds ?? 0;
  return (
    elapsedSeconds +
    walkSeconds * 0.45 +
    waitSeconds * 0.1 +
    candidate.transfers * 4 * 60 +
    (candidate.alertPenaltySeconds ?? 0)
  );
}

export function rankTransitCandidates<T extends TransitQualityCandidate>(
  candidates: T[],
  requestedAt: Date,
  limit: number,
): T[] {
  const pareto = candidates.filter(
    (candidate, index) =>
      !candidates.some(
        (other, otherIndex) => otherIndex !== index && dominates(other, candidate),
      ),
  );
  const sorted = pareto.sort((a, b) => {
      const score = transitQualityScore(a, requestedAt) - transitQualityScore(b, requestedAt);
      if (score) return score;
      const arrival = arrivalTimestamp(a) - arrivalTimestamp(b);
      if (arrival) return arrival;
      return (a.walkSeconds ?? 0) - (b.walkSeconds ?? 0) || a.transfers - b.transfers;
    });

  // Deux variantes maximum par chaîne de lignes : assez pour comparer deux
  // points de correspondance, sans masquer les autres stratégies proposées.
  const selected: T[] = [];
  const countByRouteChain = new Map<string, number>();
  for (const candidate of sorted) {
    const chain = candidate.routeIds?.join(">") || candidate.id;
    const count = countByRouteChain.get(chain) ?? 0;
    if (count >= 2) continue;
    countByRouteChain.set(chain, count + 1);
    selected.push(candidate);
    if (selected.length >= Math.max(1, limit)) break;
  }
  return selected;
}
