import { tracePointsOnRoads } from "@/lib/line-editor-routing";
import type {
  LineEditorState,
  PointType,
  RoutePoint,
  StopDetails,
} from "@/lib/line-editor-types";
import {
  createPointId,
  createRetourPointsFromAller,
  lineEditorFromRegulationLine,
  normalizeLineEditorState,
} from "@/lib/line-editor-utils";
import {
  interpolateTimelineCoordinates,
  type RouteTimelinePoint,
} from "@/lib/regulation-data";
import type { RegulationLine } from "@/lib/regulation-mock-data";

function normalizedStopName(value: string): string {
  return value.trim().toLocaleLowerCase("fr");
}

function parseTimelineMinutes(value: string): number | null {
  const match = value.match(/^(\d{1,2}):(\d{2})/);
  if (!match) return null;

  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (!Number.isFinite(hours) || minutes < 0 || minutes > 59) return null;
  return hours * 60 + minutes;
}

function travelTimeFromTimeline(
  points: RouteTimelinePoint[],
  index: number,
): number {
  if (index === 0) return 0;

  const previous = parseTimelineMinutes(points[index - 1].theoreticalTime);
  const current = parseTimelineMinutes(points[index].theoreticalTime);
  if (previous == null || current == null) return 3;

  const difference =
    current >= previous ? current - previous : current + 1440 - previous;
  return Math.max(0, Math.min(difference, 180));
}

function previousStopDetailsByKey(
  state: LineEditorState,
): Map<string, StopDetails> {
  const details = new Map<string, StopDetails>();

  for (const point of [...state.pointsAller, ...state.pointsRetour]) {
    if (!point.stop) continue;

    const code = point.stop.code.trim().toLocaleUpperCase("fr");
    const name = normalizedStopName(point.stop.name);
    if (code) details.set(`code:${code}`, point.stop);
    if (name) details.set(`name:${name}`, point.stop);
  }

  return details;
}

function pointType(index: number, total: number): PointType {
  if (index === 0) return "terminus_start";
  if (index === total - 1) return "terminus_end";
  return "stop";
}

function routePointsFromTimeline(
  timeline: RouteTimelinePoint[],
  previousState: LineEditorState,
): RoutePoint[] {
  const previousDetails = previousStopDetailsByKey(previousState);

  return timeline.map((stop, index) => {
    const code = stop.stopId.trim();
    const previous =
      previousDetails.get(`code:${code.toLocaleUpperCase("fr")}`) ??
      previousDetails.get(`name:${normalizedStopName(stop.name)}`);

    return {
      id: createPointId(),
      coordinates: [...stop.coordinates] as [number, number],
      type: pointType(index, timeline.length),
      stop: {
        name: stop.name.trim() || `Arrêt ${index + 1}`,
        code,
        address: previous?.address ?? "",
        direction: "both",
        order: index + 1,
        travelTimeMinutes: travelTimeFromTimeline(timeline, index),
        wheelchairAccessible: previous?.wheelchairAccessible ?? false,
        connections: previous?.connections ?? "",
        notes: previous?.notes ?? "",
      },
    };
  });
}

function hasUsableCoordinates(point: RouteTimelinePoint): boolean {
  return (
    Number.isFinite(point.coordinates[0]) &&
    Number.isFinite(point.coordinates[1]) &&
    (point.coordinates[0] !== 0 || point.coordinates[1] !== 0)
  );
}

/**
 * Reconstruit complètement l'état éditeur à partir de la séquence d'arrêts de
 * référence de la fiche ligne, puis recalcule les deux sens sur les voies.
 */
export async function regenerateLineEditorState(
  line: RegulationLine,
  sourceStops: RouteTimelinePoint[],
  previousState?: LineEditorState | null,
): Promise<LineEditorState> {
  if (sourceStops.length < 2) {
    throw new Error(
      "Aucune séquence d’arrêts exploitable n’est disponible pour cette ligne.",
    );
  }

  const timeline = interpolateTimelineCoordinates(sourceStops);
  if (timeline.filter(hasUsableCoordinates).length < 2) {
    throw new Error(
      "Les coordonnées des arrêts sont insuffisantes pour régénérer le tracé.",
    );
  }

  const baseState = normalizeLineEditorState(
    previousState ?? lineEditorFromRegulationLine(line),
  );
  const sourceAller = routePointsFromTimeline(timeline, baseState);
  const sourceRetour = createRetourPointsFromAller(sourceAller);

  let pointsAller = sourceAller;
  let pointsRetour = sourceRetour;

  // Un itinéraire bateau reste une polyligne entre pontons : le routeur
  // routier ne sait pas suivre les chenaux navigables.
  if (baseState.transportMode !== "boat") {
    [pointsAller, pointsRetour] = await Promise.all([
      tracePointsOnRoads(sourceAller, baseState.transportMode, line.id),
      tracePointsOnRoads(sourceRetour, baseState.transportMode, line.id),
    ]);
  }

  const origin = timeline[0].name.trim() || line.origin;
  const destination =
    timeline[timeline.length - 1].name.trim() || line.destination;

  return normalizeLineEditorState({
    ...baseState,
    id: line.id,
    name: `Ligne ${line.shortName}`,
    shortName: line.shortName,
    color: line.lineColor,
    directionAller: `${origin} → ${destination}`,
    directionRetour: `${destination} → ${origin}`,
    pointsAller,
    pointsRetour,
    branchesAller: [],
    branchesRetour: [],
    originLegsAller: [],
    originLegsRetour: [],
    activeVoice: "aller",
    activeBranchId: null,
    activeOriginLegId: null,
    selectedPointId: pointsAller[0]?.id ?? null,
  });
}
