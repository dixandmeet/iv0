export type StopPassageTime = {
  expectedAt: string;
};

const parisClockFormatter = new Intl.DateTimeFormat("en-CA", {
  timeZone: "Europe/Paris",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hourCycle: "h23",
});

export function serviceDayElapsedSeconds(
  serviceDate: string,
  nowMs: number,
): number | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(serviceDate) || !Number.isFinite(nowMs)) {
    return null;
  }

  const parts = Object.fromEntries(
    parisClockFormatter
      .formatToParts(new Date(nowMs))
      .filter((part) => part.type !== "literal")
      .map((part) => [part.type, Number(part.value)]),
  );
  const selectedDay = Date.parse(`${serviceDate}T00:00:00Z`);
  const currentDay = Date.UTC(parts.year, parts.month - 1, parts.day);
  if (!Number.isFinite(selectedDay) || !Number.isFinite(currentDay)) return null;

  const elapsedDays = Math.round((currentDay - selectedDay) / 86_400_000);
  return (
    elapsedDays * 86_400
    + parts.hour * 3_600
    + parts.minute * 60
    + parts.second
  );
}

export function nextDayScheduleIndex<T extends { seconds: number }>(
  passages: T[],
  serviceDate: string,
  nowMs: number,
): number {
  const elapsedSeconds = serviceDayElapsedSeconds(serviceDate, nowMs);
  if (elapsedSeconds == null) return -1;
  return passages.findIndex((passage) => passage.seconds >= elapsedSeconds);
}

export function activeStopPassages<T extends StopPassageTime>(
  passages: T[],
  nowMs: number,
  expiryGraceMs = 1_000,
): T[] {
  const grace = Math.max(0, expiryGraceMs);
  return passages.filter((passage) => {
    const expectedAt = new Date(passage.expectedAt).getTime();
    return Number.isFinite(expectedAt) && expectedAt + grace >= nowMs;
  });
}

export function stopPassageWaitMinutes(
  expectedAt: string,
  nowMs: number,
): number | null {
  const expectedAtMs = new Date(expectedAt).getTime();
  if (!Number.isFinite(expectedAtMs)) return null;
  return Math.max(0, Math.ceil((expectedAtMs - nowMs) / 60_000));
}

export function lineBadgeTextColor(background: string): string {
  const match = background.trim().match(/^#?([0-9a-f]{6})$/i);
  if (!match) return "#ffffff";
  const value = Number.parseInt(match[1], 16);
  const red = (value >> 16) & 0xff;
  const green = (value >> 8) & 0xff;
  const blue = value & 0xff;
  const perceivedBrightness = (red * 299 + green * 587 + blue * 114) / 1000;
  return perceivedBrightness > 175 ? "#102018" : "#ffffff";
}
