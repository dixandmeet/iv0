"use client";

import { useState } from "react";

export type RouteVehicleTracking = {
  departureId: string;
  profileId: string;
  serviceDate: string;
  line: string;
  routeId: string;
  direction: string;
  vehicleType: "bus" | "tram";
};
export type RouteStep = {
  icon: string;
  label: string;
  detail: string;
  duration: string;
  tracking?: RouteVehicleTracking;
};
export type RouteMode = "car" | "transit";
export type RoutePreferences = {
  accessible: boolean;
  avoidDisruptions: boolean;
  maxTransfers: number;
};
export type RouteAlternativeOption = {
  id: string;
  duration: number;
  departure: string;
  arrival: string;
  summary: string;
  accessible: boolean;
  alertCount: number;
};
export type RouteDepartureOption = RouteAlternativeOption;
export type RouteProvisionalOption = {
  id: string;
  routeIds: string[];
  summary: string;
};

type RouteModeOption = { key: RouteMode; icon: string; label: string };

const MODE_OPTIONS: RouteModeOption[] = [
  { key: "transit", icon: "🚋", label: "Bus · Tram · Navibus" },
  { key: "car", icon: "🚗", label: "Voiture" },
];

function formatDurationMinutes(duration: number): string {
  const minutes = Math.max(0, Math.round(duration));
  if (minutes < 60) return `${minutes} min`;
  const hours = Math.floor(minutes / 60);
  return `${hours}h${String(minutes % 60).padStart(2, "0")}`;
}

function formatDurationLabel(duration: string): string {
  const minutes = duration.trim().match(/^(\d+)\s*min$/i)?.[1];
  return minutes ? formatDurationMinutes(Number(minutes)) : duration;
}

type RoutePanelProps = {
  destName: string;
  duration: number;
  departure: string;
  arrival: string;
  steps: RouteStep[];
  loading?: boolean;
  error?: string | null;
  mode: RouteMode;
  alternatives?: RouteAlternativeOption[];
  departures?: RouteDepartureOption[];
  provisionalAlternatives?: RouteProvisionalOption[];
  selectedAlternativeId?: string | null;
  preferences: RoutePreferences;
  advancedAvailable: boolean;
  onModeChange: (mode: RouteMode) => void;
  onAlternativeChange: (id: string) => void;
  onDepartureChange: (id: string) => void;
  onTrackVehicle: (tracking: RouteVehicleTracking) => Promise<void>;
  onPreferencesChange: (preferences: RoutePreferences) => void;
  onClose: () => void;
};

export function RoutePanel({
  destName,
  duration,
  departure,
  arrival,
  steps,
  loading,
  error,
  mode,
  alternatives = [],
  departures = [],
  provisionalAlternatives = [],
  selectedAlternativeId,
  preferences,
  advancedAvailable,
  onModeChange,
  onAlternativeChange,
  onDepartureChange,
  onTrackVehicle,
  onPreferencesChange,
  onClose,
}: RoutePanelProps) {
  const [trackingKey, setTrackingKey] = useState<string | null>(null);
  const [trackingError, setTrackingError] = useState<string | null>(null);
  const firstTrackedStep = steps.find((step) => step.tracking);

  const trackVehicle = async (tracking: RouteVehicleTracking) => {
    const key = `${tracking.serviceDate}:${tracking.departureId}`;
    setTrackingKey(key);
    setTrackingError(null);
    try {
      await onTrackVehicle(tracking);
    } catch (error) {
      setTrackingError(
        error instanceof Error
          ? error.message
          : "Le suivi de ce véhicule est momentanément indisponible.",
      );
      setTrackingKey(null);
    }
  };

  return (
    <aside className="immersive-map-route-panel immersive-map-panel immersive-map-panel-anim absolute bottom-6 left-5 z-[399] max-h-[calc(100vh-190px)] w-[380px] max-w-[calc(100vw-40px)] overflow-y-auto rounded-[22px] p-[22px]" aria-label="Détail de l’itinéraire">
      <div className="mb-3 flex items-center justify-between">
        <div className="text-[15px] font-semibold">→ {destName}</div>
        <button type="button" onClick={onClose} className="immersive-map-icon-btn" aria-label="Fermer">
          ×
        </button>
      </div>
      {mode === "transit" && (
        <div className="mb-3 flex flex-wrap gap-1.5" aria-label="Préférences d’itinéraire">
          <button
            type="button"
            disabled={!advancedAvailable}
            aria-pressed={preferences.accessible}
            onClick={() => onPreferencesChange({ ...preferences, accessible: !preferences.accessible })}
            className={`rounded-full px-2.5 py-1 text-[11px] transition-colors disabled:cursor-not-allowed disabled:opacity-40 ${
              preferences.accessible ? "bg-[#33bfa3] text-[#04211c]" : "bg-white/[.07] text-white/65"
            }`}
          >
            ♿ Accessible
          </button>
          <button
            type="button"
            disabled={!advancedAvailable}
            aria-pressed={preferences.avoidDisruptions}
            onClick={() =>
              onPreferencesChange({
                ...preferences,
                avoidDisruptions: !preferences.avoidDisruptions,
              })
            }
            className={`rounded-full px-2.5 py-1 text-[11px] transition-colors disabled:cursor-not-allowed disabled:opacity-40 ${
              preferences.avoidDisruptions ? "bg-[#33bfa3] text-[#04211c]" : "bg-white/[.07] text-white/65"
            }`}
          >
            ⚠ Éviter perturbations
          </button>
          <button
            type="button"
            disabled={!advancedAvailable}
            onClick={() =>
              onPreferencesChange({
                ...preferences,
                maxTransfers: preferences.maxTransfers >= 2 ? 0 : preferences.maxTransfers + 1,
              })
            }
            className="rounded-full bg-white/[.07] px-2.5 py-1 text-[11px] text-white/65 disabled:cursor-not-allowed disabled:opacity-40"
            aria-label="Nombre maximal de correspondances"
          >
            ↔ {preferences.maxTransfers} corresp. max
          </button>
          {!advancedAvailable && !loading && !error && (
            <span className="w-full text-[10px] text-amber-200/70">
              Horaires détaillés indisponibles pour cet itinéraire.
            </span>
          )}
        </div>
      )}
      <div className="mb-3 flex gap-1.5">
        {MODE_OPTIONS.map((opt) => (
          <button
            key={opt.key}
            type="button"
            onClick={() => onModeChange(opt.key)}
            className={`flex flex-1 items-center justify-center gap-1.5 rounded-[12px] border-none py-2 text-[12.5px] font-medium transition-colors ${
              mode === opt.key ? "bg-[#33bfa3] text-[#04211c]" : "bg-white/[.06] text-white/70"
            }`}
          >
            <span>{opt.icon}</span>
            <span>{opt.label}</span>
          </button>
        ))}
      </div>
      {loading && (
        <div className="py-2 text-sm text-white/60" aria-live="polite">
          {steps.length || provisionalAlternatives.length
            ? "Vérification des horaires et recherche d’autres itinéraires…"
            : "Calcul de l’itinéraire…"}
        </div>
      )}
      {error && !steps.length && <div className="py-2 text-sm text-red-300">{error}</div>}
      {!error && steps.length > 0 && (
        <div className="mb-4 flex gap-5">
          <div>
            <div className="text-[22px] font-bold text-[#33bfa3]">
              {formatDurationMinutes(duration)}
            </div>
            <div className="text-xs text-white/50">durée totale</div>
          </div>
          <div>
            <div className="text-[22px] font-bold">{departure}</div>
            <div className="text-xs text-white/50">départ</div>
          </div>
          <div>
            <div className="text-[22px] font-bold">{arrival}</div>
            <div className="text-xs text-white/50">arrivée</div>
          </div>
        </div>
      )}
      {!error && mode === "transit" && firstTrackedStep?.tracking && (
        <button
          type="button"
          disabled={trackingKey != null}
          onClick={() => void trackVehicle(firstTrackedStep.tracking!)}
          className="mb-3 flex w-full items-center justify-center gap-2 rounded-xl bg-[#33bfa3] px-3 py-2.5 text-xs font-bold text-[#04211c] transition-colors hover:bg-[#55d8be] disabled:cursor-wait disabled:opacity-60"
        >
          <span>◎</span>
          {trackingKey ===
          `${firstTrackedStep.tracking.serviceDate}:${firstTrackedStep.tracking.departureId}`
            ? "Localisation du véhicule…"
            : `Suivre le prochain véhicule · ${firstTrackedStep.tracking.line}`}
        </button>
      )}
      {!error && alternatives.length > 1 && (
        <div className="mb-3 grid gap-1.5" aria-label="Itinéraires alternatifs">
          {alternatives.map((alternative) => {
            const selected = alternative.id === selectedAlternativeId;
            return (
              <button
                key={alternative.id}
                type="button"
                onClick={() => onAlternativeChange(alternative.id)}
                aria-pressed={selected}
                className={`flex items-center justify-between rounded-xl px-3 py-2 text-left transition-colors ${
                  selected
                    ? "bg-[#33bfa3]/20 text-white ring-1 ring-[#33bfa3]/60"
                    : "bg-white/[.05] text-white/70"
                }`}
              >
                <span>
                  <span className="block text-xs font-medium">{alternative.summary}</span>
                  <span className="block text-[10px] text-white/45">
                    {alternative.departure} → {alternative.arrival}
                    {alternative.accessible ? " · ♿" : ""}
                    {alternative.alertCount ? ` · ⚠ ${alternative.alertCount}` : ""}
                  </span>
                </span>
                <span className="text-sm font-semibold">
                  {formatDurationMinutes(alternative.duration)}
                </span>
              </button>
            );
          })}
        </div>
      )}
      {!error && mode === "transit" && departures.length > 1 && (
        <div className="mb-3" aria-label="Prochains départs">
          <div className="mb-1.5 text-[10px] font-medium uppercase tracking-[.12em] text-[#55dac2]">
            Prochains départs
          </div>
          <div className="flex gap-1.5 overflow-x-auto pb-1">
            {departures.map((option) => {
              const selected = option.id === selectedAlternativeId;
              return (
                <button
                  key={option.id}
                  type="button"
                  onClick={() => onDepartureChange(option.id)}
                  aria-pressed={selected}
                  className={`min-w-[104px] rounded-xl px-2.5 py-2 text-left transition-colors ${
                    selected
                      ? "bg-[#33bfa3] text-[#04211c]"
                      : "bg-white/[.07] text-white/75"
                  }`}
                >
                  <span className="block text-sm font-bold">{option.departure}</span>
                  <span className={`block text-[10px] ${selected ? "text-[#083c33]/75" : "text-white/45"}`}>
                    arrivée {option.arrival}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      )}
      {!error && !steps.length && provisionalAlternatives.length > 0 && (
        <div
          className="mb-3 max-h-52 space-y-1.5 overflow-y-auto"
          aria-label="Possibilités d’itinéraires en cours de vérification"
        >
          <div className="text-[10px] uppercase tracking-wide text-white/40">
            Possibilités trouvées · horaires en cours
          </div>
          {provisionalAlternatives.map((alternative) => (
            <div
              key={alternative.id}
              className="flex items-center justify-between rounded-xl bg-white/[.05] px-3 py-2 text-white/70"
            >
              <span className="text-xs font-medium">{alternative.summary}</span>
              <span className="text-[10px] text-[#33bfa3]">Vérification…</span>
            </div>
          ))}
        </div>
      )}
      {steps.map((step, i) => {
        const stepTrackingKey = step.tracking
          ? `${step.tracking.serviceDate}:${step.tracking.departureId}`
          : null;
        return (
        <div key={i} className="flex items-start gap-3 border-t border-white/[.08] py-2.5">
          <span className="flex-none text-lg">{step.icon}</span>
          <div className="flex-1">
            <div className="text-sm text-white/[.92]">{step.label}</div>
            <div className="text-xs text-white/50">{step.detail}</div>
            {step.tracking && (
              <button
                type="button"
                disabled={trackingKey != null}
                onClick={() => void trackVehicle(step.tracking!)}
                className="mt-2 rounded-lg bg-[#33bfa3]/15 px-2.5 py-1.5 text-[11px] font-semibold text-[#65e1ca] ring-1 ring-inset ring-[#33bfa3]/35 transition-colors hover:bg-[#33bfa3]/25 disabled:cursor-wait disabled:opacity-60"
              >
                {trackingKey === stepTrackingKey ? "Localisation…" : "Suivre ce véhicule"}
              </button>
            )}
          </div>
          <span className="flex-none text-[12.5px] text-white/55">
            {formatDurationLabel(step.duration)}
          </span>
        </div>
        );
      })}
      {trackingError && (
        <div className="mt-2 text-xs text-red-300" role="alert">
          {trackingError}
        </div>
      )}
    </aside>
  );
}
