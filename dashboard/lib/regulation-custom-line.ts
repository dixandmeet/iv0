import { DEPOTS } from "@/lib/depot-lines";
import type { NetworkMode, RegulationLine } from "@/lib/regulation-mock-data";
import { NETWORK_MODE_LABELS, normalizeNetworkMode } from "@/lib/regulation-mock-data";

const CUSTOM_LINE_COLORS = [
  "#2563EB",
  "#7C3AED",
  "#DB2777",
  "#EA580C",
  "#059669",
  "#0891B2",
];

export interface NewLineInput {
  shortName: string;
  origin: string;
  destination: string;
  transportType: NetworkMode;
  depotCode: string;
}

export const CUSTOM_LINES_STORAGE_KEY = "regulation-custom-lines";
export const LINE_INFO_OVERRIDES_STORAGE_KEY = "regulation-line-info-overrides";

export function isCustomRegulationLine(lineId: string): boolean {
  return lineId.startsWith("custom:") || lineId.startsWith("network:");
}

export function loadCustomRegulationLines(scope?: string): RegulationLine[] {
  if (typeof window === "undefined") return [];

  try {
    const storageKey = scope ? `${CUSTOM_LINES_STORAGE_KEY}:${scope}` : CUSTOM_LINES_STORAGE_KEY;
    const raw = localStorage.getItem(storageKey);
    if (!raw) return [];

    const parsed = JSON.parse(raw) as unknown;
    if (!Array.isArray(parsed)) return [];

    return parsed.filter(
      (line): line is RegulationLine =>
        typeof line === "object" &&
        line !== null &&
        typeof (line as RegulationLine).id === "string" &&
        isCustomRegulationLine((line as RegulationLine).id),
    );
  } catch {
    return [];
  }
}

export function saveCustomRegulationLines(lines: RegulationLine[], scope?: string): void {
  if (typeof window === "undefined") return;

  try {
    const storageKey = scope ? `${CUSTOM_LINES_STORAGE_KEY}:${scope}` : CUSTOM_LINES_STORAGE_KEY;
    localStorage.setItem(storageKey, JSON.stringify(lines));
  } catch {
    // Ignore quota or private-mode storage errors.
  }
}

export function lineToInfoInput(line: RegulationLine): NewLineInput {
  return {
    shortName: line.shortName,
    origin: line.origin,
    destination: line.destination,
    transportType: normalizeNetworkMode(line.transportType),
    depotCode: line.depotCode,
  };
}

export function applyLineInfoUpdate(
  line: RegulationLine,
  input: NewLineInput,
): RegulationLine {
  const shortName = input.shortName.trim();
  const origin = input.origin.trim();
  const destination = input.destination.trim();
  const transportLabel =
    input.transportType === "boat"
      ? "Navibus"
      : NETWORK_MODE_LABELS[input.transportType];

  const stops = line.stops.map((stop, index) => {
    if (index === 0 && stop.isTerminus) {
      return { ...stop, name: origin };
    }
    if (index === line.stops.length - 1 && stop.isTerminus) {
      return { ...stop, name: destination };
    }
    return stop;
  });

  return {
    ...line,
    shortName,
    origin,
    destination,
    transportType: transportLabel,
    depotCode: input.depotCode,
    routeId: isCustomRegulationLine(line.id) ? shortName : line.routeId,
    stops,
  };
}

export function loadLineInfoOverrides(): Record<string, NewLineInput> {
  if (typeof window === "undefined") return {};

  try {
    const raw = localStorage.getItem(LINE_INFO_OVERRIDES_STORAGE_KEY);
    if (!raw) return {};

    const parsed = JSON.parse(raw) as unknown;
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return {};
    }

    const result: Record<string, NewLineInput> = {};
    for (const [lineId, value] of Object.entries(parsed)) {
      if (
        typeof value === "object" &&
        value !== null &&
        typeof (value as NewLineInput).shortName === "string" &&
        typeof (value as NewLineInput).origin === "string" &&
        typeof (value as NewLineInput).destination === "string"
      ) {
        result[lineId] = value as NewLineInput;
      }
    }
    return result;
  } catch {
    return {};
  }
}

export function saveLineInfoOverrides(
  overrides: Record<string, NewLineInput>,
): void {
  if (typeof window === "undefined") return;

  try {
    localStorage.setItem(LINE_INFO_OVERRIDES_STORAGE_KEY, JSON.stringify(overrides));
  } catch {
    // Ignore quota or private-mode storage errors.
  }
}

export function createCustomRegulationLine(input: NewLineInput): RegulationLine {
  const shortName = input.shortName.trim();
  const origin = input.origin.trim();
  const destination = input.destination.trim();
  const id = `custom:${Date.now()}:${shortName}`;
  const colorIndex =
    shortName.split("").reduce((acc, char) => acc + char.charCodeAt(0), 0) %
    CUSTOM_LINE_COLORS.length;

  const transportLabel =
    input.transportType === "boat"
      ? "Navibus"
      : NETWORK_MODE_LABELS[input.transportType];

  return {
    id,
    shortName,
    origin,
    destination,
    status: "normal",
    vehicleCount: 0,
    avgDelay: 0,
    incidentCount: 0,
    transportType: transportLabel,
    depotCode: input.depotCode,
    routeId: shortName,
    stopCount: 2,
    maxVehicles: 0,
    punctuality: 100,
    firstDeparture: "—",
    lastDeparture: "—",
    stops: [
      {
        stopId: `${id}-origin`,
        name: origin,
        theoreticalTime: "—",
        isTerminus: true,
      },
      {
        stopId: `${id}-destination`,
        name: destination,
        theoreticalTime: "—",
        isTerminus: true,
      },
    ],
    segmentQuality: ["on-time"],
    vehicles: [],
    lineColor: CUSTOM_LINE_COLORS[colorIndex],
  };
}

export const ADD_LINE_DEPOT_OPTIONS = [
  ...DEPOTS.map((d) => ({ code: d.code, label: d.name })),
  { code: "TRAM", label: "Tramway" },
  { code: "NAV", label: "Navibus" },
];
