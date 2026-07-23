import type { LineEditorState, RoutePoint } from "@/lib/line-editor-types";
import { TRANSPORT_MODE_LABELS } from "@/lib/line-editor-types";
import { getVoicePoints, isStopType, normalizeLineEditorState } from "@/lib/line-editor-utils";
import { applyEditedStops } from "@/lib/regulation-stop-edits";
import {
  registeredStopsFromPoints,
  type RegisteredStop,
} from "@/lib/registered-stops";
import {
  type RegulationLine,
  type RegulationStop,
} from "@/lib/regulation-mock-data";

export const LINE_EDITOR_DRAFTS_KEY = "line-editor-drafts";

type DraftStore = Record<string, { state: LineEditorState; savedAt: number }>;

function loadDraftStore(): DraftStore {
  if (typeof window === "undefined") return {};

  try {
    const raw = localStorage.getItem(LINE_EDITOR_DRAFTS_KEY);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as DraftStore;
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

export function loadLineEditorDraft(lineId: string): LineEditorState | null {
  const draft = loadDraftStore()[lineId]?.state;
  return draft ? normalizeLineEditorState(draft) : null;
}

export function registeredStopsFromEditorDrafts(): RegisteredStop[] {
  const seen = new Set<string>();
  const result: RegisteredStop[] = [];

  for (const draft of Object.values(loadDraftStore())) {
    const state = normalizeLineEditorState(draft.state);
    for (const stop of registeredStopsFromPoints(state.pointsAller)) {
      const key = stop.code.trim().toUpperCase() || stop.name.trim().toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      result.push(stop);
    }
    for (const stop of registeredStopsFromPoints(state.pointsRetour)) {
      const key = stop.code.trim().toUpperCase() || stop.name.trim().toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      result.push(stop);
    }
  }

  return result;
}

export function saveLineEditorDraft(lineId: string, state: LineEditorState): void {
  if (typeof window === "undefined") return;

  try {
    const store = loadDraftStore();
    store[lineId] = { state, savedAt: Date.now() };
    localStorage.setItem(LINE_EDITOR_DRAFTS_KEY, JSON.stringify(store));
  } catch {
    // Ignore quota or private-mode storage errors.
  }
}

export function parseDirectionEnds(directionAller: string): {
  origin: string;
  destination: string;
} {
  const parts = directionAller.split("→").map((part) => part.trim());
  if (parts.length >= 2) {
    return {
      origin: parts[0],
      destination: parts[parts.length - 1],
    };
  }
  return { origin: "", destination: "" };
}

export function regulationStopsFromEditor(
  state: LineEditorState,
  existingStops: RegulationStop[] = [],
): RegulationStop[] {
  const stopPoints = getVoicePoints(state, "aller").filter((point) => isStopType(point.type));

  return stopPoints.map((point: RoutePoint, index) => {
    const previous = existingStops[index];
    const isTerminus =
      point.type === "terminus_start" ||
      point.type === "terminus_end" ||
      index === 0 ||
      index === stopPoints.length - 1;

    return {
      stopId:
        point.stop?.code?.trim() ||
        previous?.stopId ||
        `${state.id}-stop-${index}`,
      stationId: previous?.stationId,
      name: point.stop?.name?.trim() || `Arrêt ${index + 1}`,
      theoreticalTime: previous?.theoreticalTime ?? "—",
      isTerminus,
      unavailable: previous?.unavailable ?? false,
    };
  });
}

export function applyEditorStateToRegulationLine(
  line: RegulationLine,
  state: LineEditorState,
): RegulationLine {
  const stops = regulationStopsFromEditor(state, line.stops);
  const { origin, destination } = parseDirectionEnds(state.directionAller);
  const transportLabel = TRANSPORT_MODE_LABELS[state.transportMode];

  const updated = applyEditedStops(line, stops);

  return {
    ...updated,
    shortName: state.shortName.trim() || line.shortName,
    origin: origin || line.origin,
    destination: destination || line.destination,
    lineColor: state.color,
    transportType: transportLabel,
    stopCount: stops.length,
  };
}
