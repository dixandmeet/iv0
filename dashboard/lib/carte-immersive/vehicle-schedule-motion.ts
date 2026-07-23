export type VehicleScheduleControlPoint = {
  fraction: number;
  passageAtMs: number;
};

export type VehicleScheduleMotion = {
  fraction: number;
  fractionPerSecond: number;
  stopped: boolean;
};

const MIN_DWELL_MS = 4_000;
const MAX_DWELL_MS = 15_000;

/**
 * Interpole la position entre deux passages GTFS. Une courte partie de chaque
 * intervalle est réservée à l'arrêt en station ; le reste du temps sert au
 * déplacement, de sorte que la station suivante est atteinte à l'heure prévue.
 */
export function vehicleScheduleMotionAt(
  stops: VehicleScheduleControlPoint[],
  nowMs: number,
): VehicleScheduleMotion | null {
  if (stops.length < 2 || !Number.isFinite(nowMs)) return null;
  const first = stops[0];
  const last = stops[stops.length - 1];
  if (nowMs <= first.passageAtMs) {
    return { fraction: first.fraction, fractionPerSecond: 0, stopped: true };
  }
  if (nowMs >= last.passageAtMs) {
    return { fraction: last.fraction, fractionPerSecond: 0, stopped: true };
  }

  for (let index = 0; index < stops.length - 1; index += 1) {
    const from = stops[index];
    const to = stops[index + 1];
    if (nowMs > to.passageAtMs) continue;

    const intervalMs = Math.max(1, to.passageAtMs - from.passageAtMs);
    const dwellMs = Math.min(
      MAX_DWELL_MS,
      Math.max(MIN_DWELL_MS, intervalMs * 0.12),
      intervalMs * 0.45,
    );
    const movementStartsAt = from.passageAtMs + dwellMs;
    if (nowMs <= movementStartsAt) {
      return { fraction: from.fraction, fractionPerSecond: 0, stopped: true };
    }

    const movementMs = Math.max(1, to.passageAtMs - movementStartsAt);
    const progress = Math.min(1, Math.max(0, (nowMs - movementStartsAt) / movementMs));
    const fractionDelta = to.fraction - from.fraction;
    return {
      fraction: from.fraction + fractionDelta * progress,
      fractionPerSecond: fractionDelta / (movementMs / 1_000),
      stopped: false,
    };
  }

  return { fraction: last.fraction, fractionPerSecond: 0, stopped: true };
}
