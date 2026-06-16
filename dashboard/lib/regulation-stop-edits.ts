import type { RegulationLine, RegulationStop } from "@/lib/regulation-mock-data";

export function applyEditedStops(
  line: RegulationLine,
  editedStops: RegulationStop[],
): RegulationLine {
  const stopCount = editedStops.length;
  const segmentCount = Math.max(stopCount - 1, 0);

  const vehicles = line.vehicles.map((vehicle) => {
    const maxSegment = Math.max(stopCount - 2, 0);
    const segmentIndex = Math.min(vehicle.segmentIndex, maxSegment);
    const delays = Array.from({ length: stopCount }, (_, i) => {
      if (i < vehicle.delays.length) return vehicle.delays[i];
      return vehicle.delays[vehicle.delays.length - 1] ?? 0;
    }).slice(0, stopCount);

    return { ...vehicle, segmentIndex, delays };
  });

  const segmentQuality = Array.from({ length: segmentCount }, (_, seg) => {
    const left = editedStops[seg];
    const right = editedStops[seg + 1];
    if (left?.unavailable || right?.unavailable) return "major-delay" as const;
    return line.segmentQuality[seg] ?? "on-time";
  });

  return {
    ...line,
    stops: editedStops,
    stopCount,
    vehicles,
    segmentQuality,
  };
}

export function toggleStopUnavailable(
  stops: RegulationStop[],
  index: number,
): RegulationStop[] {
  return stops.map((stop, i) =>
    i === index ? { ...stop, unavailable: !stop.unavailable } : stop,
  );
}

export function deleteStopAt(
  stops: RegulationStop[],
  index: number,
): RegulationStop[] | null {
  if (stops.length <= 2) return null;
  const next = stops.filter((_, i) => i !== index);
  if (next.length >= 2) {
    next[0] = { ...next[0], isTerminus: true };
    next[next.length - 1] = { ...next[next.length - 1], isTerminus: true };
    for (let i = 1; i < next.length - 1; i++) {
      next[i] = { ...next[i], isTerminus: false };
    }
  }
  return next;
}

export function addStopAfter(
  stops: RegulationStop[],
  afterIndex: number,
  name: string,
): RegulationStop[] {
  const trimmed = name.trim();
  if (!trimmed) return stops;

  const newStop: RegulationStop = {
    stopId: `custom-${Date.now()}`,
    name: trimmed,
    theoreticalTime: "—",
    unavailable: false,
  };

  const next = [...stops];
  next.splice(afterIndex + 1, 0, newStop);

  if (next.length >= 2) {
    next[0] = { ...next[0], isTerminus: true };
    next[next.length - 1] = { ...next[next.length - 1], isTerminus: true };
    for (let i = 1; i < next.length - 1; i++) {
      next[i] = { ...next[i], isTerminus: false };
    }
  }

  return next;
}
