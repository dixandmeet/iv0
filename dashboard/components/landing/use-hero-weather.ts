"use client";

import { useEffect, useMemo, useState } from "react";

export type HeroDayPeriod = "dawn" | "day" | "dusk" | "night";
export type HeroWeatherCondition = "clear" | "cloudy" | "fog" | "rain" | "snow" | "storm";

export type HeroWeather = {
  period: HeroDayPeriod;
  condition: HeroWeatherCondition;
  label: string;
  temperature?: number;
  live: boolean;
};

type WeatherResponse = {
  current?: {
    time?: string;
    temperature_2m?: number;
    weather_code?: number;
    precipitation?: number;
    rain?: number;
    showers?: number;
    snowfall?: number;
  };
  daily?: {
    sunrise?: string[];
    sunset?: string[];
  };
};

const DEFAULT_LOCATION = { lat: 47.2184, lng: -1.5536 };
const REFRESH_INTERVAL = 15 * 60 * 1000;

function minutesFromIsoLocal(value?: string) {
  if (!value) return null;
  const match = value.match(/T(\d{2}):(\d{2})/);
  return match ? Number(match[1]) * 60 + Number(match[2]) : null;
}

function fallbackPeriod(): HeroDayPeriod {
  const parts = new Intl.DateTimeFormat("fr-FR", {
    timeZone: "Europe/Paris",
    hour: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date());
  const hour = Number(parts.find((part) => part.type === "hour")?.value ?? 12);
  if (hour < 6 || hour >= 22) return "night";
  if (hour < 9) return "dawn";
  if (hour < 19) return "day";
  return "dusk";
}

function resolvePeriod(current?: string, sunrise?: string, sunset?: string): HeroDayPeriod {
  const now = minutesFromIsoLocal(current);
  const sunriseAt = minutesFromIsoLocal(sunrise);
  const sunsetAt = minutesFromIsoLocal(sunset);
  if (now == null || sunriseAt == null || sunsetAt == null) return fallbackPeriod();

  if (now < sunriseAt - 50 || now > sunsetAt + 70) return "night";
  if (now <= sunriseAt + 80) return "dawn";
  if (now >= sunsetAt - 70) return "dusk";
  return "day";
}

function resolveCondition(current?: WeatherResponse["current"]): HeroWeatherCondition {
  const code = current?.weather_code ?? 0;
  const precipitation = current?.precipitation ?? 0;
  if (code === 95 || code === 96 || code === 99) return "storm";
  if (code >= 71 && code <= 86) return "snow";
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || precipitation > 0) return "rain";
  if (code === 45 || code === 48) return "fog";
  if (code === 1 || code === 2 || code === 3) return "cloudy";
  return "clear";
}

function weatherLabel(condition: HeroWeatherCondition, period: HeroDayPeriod) {
  const periodLabels: Record<HeroDayPeriod, string> = {
    dawn: "lever du jour",
    day: "journée",
    dusk: "soirée",
    night: "nuit",
  };
  const conditionLabels: Record<HeroWeatherCondition, string> = {
    clear: "ciel dégagé",
    cloudy: "ciel nuageux",
    fog: "brume",
    rain: "pluie",
    snow: "neige",
    storm: "orage",
  };
  return `${conditionLabels[condition]} · ${periodLabels[period]}`;
}

export function useHeroWeather(location?: { lat: number; lng: number }): HeroWeather {
  const latitude = location?.lat ?? DEFAULT_LOCATION.lat;
  const longitude = location?.lng ?? DEFAULT_LOCATION.lng;
  const fallback = useMemo<HeroWeather>(() => {
    const period = fallbackPeriod();
    return { period, condition: "clear", label: weatherLabel("clear", period), live: false };
  }, []);
  const [weather, setWeather] = useState(fallback);

  useEffect(() => {
    const controller = new AbortController();
    let timeoutId: ReturnType<typeof setTimeout> | undefined;

    const refresh = async () => {
      try {
        const params = new URLSearchParams({
          latitude: latitude.toFixed(4),
          longitude: longitude.toFixed(4),
          current: "temperature_2m,weather_code,precipitation,rain,showers,snowfall",
          daily: "sunrise,sunset",
          timezone: "auto",
          forecast_days: "1",
        });
        const response = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`, {
          signal: controller.signal,
        });
        if (!response.ok) throw new Error(`Weather request failed: ${response.status}`);
        const data = (await response.json()) as WeatherResponse;
        const period = resolvePeriod(
          data.current?.time,
          data.daily?.sunrise?.[0],
          data.daily?.sunset?.[0],
        );
        const condition = resolveCondition(data.current);
        setWeather({
          period,
          condition,
          label: weatherLabel(condition, period),
          temperature: data.current?.temperature_2m,
          live: true,
        });
      } catch (error) {
        if (!(error instanceof DOMException && error.name === "AbortError")) {
          setWeather((current) => {
            const period = fallbackPeriod();
            return { ...current, period, label: weatherLabel(current.condition, period), live: false };
          });
        }
      } finally {
        if (!controller.signal.aborted) timeoutId = setTimeout(refresh, REFRESH_INTERVAL);
      }
    };

    void refresh();
    return () => {
      controller.abort();
      if (timeoutId) clearTimeout(timeoutId);
    };
  }, [latitude, longitude]);

  return weather;
}
