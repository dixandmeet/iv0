import type { HeroWeather } from "@/components/landing/use-hero-weather";

export function MapWeatherScene({ weather }: { weather: HeroWeather }) {
  return (
    <div
      className="immersive-map-weather"
      data-period={weather.period}
      data-weather={weather.condition}
      aria-hidden="true"
    >
      <span className="immersive-map-weather-sun" />
      <span className="immersive-map-weather-cloud immersive-map-weather-cloud--one" />
      <span className="immersive-map-weather-cloud immersive-map-weather-cloud--two" />
      <span className="immersive-map-weather-rain" />
      <span className="immersive-map-weather-snow" />
      <span className="immersive-map-weather-lightning" />
    </div>
  );
}
