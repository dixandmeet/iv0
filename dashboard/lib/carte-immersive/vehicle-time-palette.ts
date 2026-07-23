export type TimeColoredVehicleType = "bus" | "tram" | "vtc" | "taxi";

type PaletteMoment = "night" | "dawn" | "day" | "dusk";

export type VehicleShadowAtmosphere = {
  period: PaletteMoment;
  condition: "clear" | "cloudy" | "fog" | "rain" | "snow" | "storm";
};

export type VehicleShadowStyle = {
  color: string;
  opacity: number;
};

const VEHICLE_PALETTES: Record<
  TimeColoredVehicleType,
  Record<PaletteMoment, string>
> = {
  bus: {
    night: "#6fa4d5",
    dawn: "#f5ad79",
    day: "#5edfc4",
    dusk: "#f18f85",
  },
  tram: {
    night: "#3f6684",
    dawn: "#c9b58f",
    day: "#e4eeeb",
    dusk: "#bd8068",
  },
  vtc: {
    night: "#27364d",
    dawn: "#756252",
    day: "#3a4743",
    dusk: "#624b52",
  },
  taxi: {
    night: "#a8732d",
    dawn: "#f4b94f",
    day: "#f2a93b",
    dusk: "#e47b37",
  },
};

const COLOR_TIMELINE: Array<{ hour: number; moment: PaletteMoment }> = [
  { hour: 0, moment: "night" },
  { hour: 5, moment: "night" },
  { hour: 7, moment: "dawn" },
  { hour: 10, moment: "day" },
  { hour: 17, moment: "day" },
  { hour: 20, moment: "dusk" },
  { hour: 22, moment: "night" },
  { hour: 24, moment: "night" },
];

const SHADOW_PALETTES: Record<PaletteMoment, VehicleShadowStyle> = {
  dawn: { color: "#765a4d", opacity: 0.16 },
  day: { color: "#756d5a", opacity: 0.12 },
  dusk: { color: "#384151", opacity: 0.2 },
  night: { color: "#071521", opacity: 0.28 },
};

const SHADOW_WEATHER_FACTOR: Record<VehicleShadowAtmosphere["condition"], number> = {
  clear: 1,
  cloudy: 0.74,
  fog: 0.48,
  rain: 0.72,
  snow: 0.56,
  storm: 0.84,
};

const parisTimeFormatter = new Intl.DateTimeFormat("fr-FR", {
  timeZone: "Europe/Paris",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hourCycle: "h23",
});

function decimalHour(date: Date) {
  const parts = parisTimeFormatter.formatToParts(date);
  const value = (type: "hour" | "minute" | "second") =>
    Number(parts.find((part) => part.type === type)?.value ?? 0);
  return value("hour") + value("minute") / 60 + value("second") / 3_600;
}

function hexChannels(color: string) {
  return [
    Number.parseInt(color.slice(1, 3), 16),
    Number.parseInt(color.slice(3, 5), 16),
    Number.parseInt(color.slice(5, 7), 16),
  ];
}

function interpolateHex(from: string, to: string, progress: number) {
  const start = hexChannels(from);
  const end = hexChannels(to);
  return `#${start
    .map((channel, index) =>
      Math.round(channel + (end[index] - channel) * progress)
        .toString(16)
        .padStart(2, "0"),
    )
    .join("")}`;
}

function surroundingMoments(date: Date) {
  const hour = decimalHour(date);
  const nextIndex = COLOR_TIMELINE.findIndex((item) => item.hour >= hour);
  const next = COLOR_TIMELINE[Math.max(1, nextIndex)];
  const previous = COLOR_TIMELINE[Math.max(0, nextIndex - 1)];
  const duration = Math.max(0.001, next.hour - previous.hour);
  return {
    previous: previous.moment,
    next: next.moment,
    progress: Math.min(1, Math.max(0, (hour - previous.hour) / duration)),
  };
}

export function getVehicleTimeColor(
  type: TimeColoredVehicleType,
  date = new Date(),
) {
  const { previous, next, progress } = surroundingMoments(date);
  return interpolateHex(
    VEHICLE_PALETTES[type][previous],
    VEHICLE_PALETTES[type][next],
    progress,
  );
}

export function getVehicleLightIntensity(date = new Date()) {
  const { previous, next, progress } = surroundingMoments(date);
  const levels: Record<PaletteMoment, number> = {
    night: 1.35,
    dawn: 0.8,
    day: 0.35,
    dusk: 0.95,
  };
  return levels[previous] + (levels[next] - levels[previous]) * progress;
}

export function getVehicleShadowStyle(
  atmosphere?: VehicleShadowAtmosphere | null,
  date = new Date(),
): VehicleShadowStyle {
  if (atmosphere) {
    const base = SHADOW_PALETTES[atmosphere.period];
    return {
      color: base.color,
      opacity: base.opacity * SHADOW_WEATHER_FACTOR[atmosphere.condition],
    };
  }

  const { previous, next, progress } = surroundingMoments(date);
  const from = SHADOW_PALETTES[previous];
  const to = SHADOW_PALETTES[next];
  return {
    color: interpolateHex(from.color, to.color, progress),
    opacity: from.opacity + (to.opacity - from.opacity) * progress,
  };
}
