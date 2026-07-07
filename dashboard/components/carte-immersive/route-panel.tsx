"use client";

export type RouteStep = { icon: string; label: string; detail: string; duration: string };
export type RouteMode = "foot" | "car" | "transit";

type RouteModeOption = { key: RouteMode; icon: string; label: string };

const MODE_OPTIONS: RouteModeOption[] = [
  { key: "foot", icon: "🚶", label: "À pied" },
  { key: "transit", icon: "🚋", label: "Transport" },
  { key: "car", icon: "🚗", label: "Voiture" },
];

type RoutePanelProps = {
  destName: string;
  duration: number;
  arrival: string;
  steps: RouteStep[];
  loading?: boolean;
  error?: string | null;
  mode: RouteMode;
  onModeChange: (mode: RouteMode) => void;
  onClose: () => void;
};

export function RoutePanel({
  destName,
  duration,
  arrival,
  steps,
  loading,
  error,
  mode,
  onModeChange,
  onClose,
}: RoutePanelProps) {
  return (
    <div className="immersive-map-panel immersive-map-panel-anim absolute bottom-6 left-5 z-[399] w-80 rounded-[22px] p-[22px]">
      <div className="mb-3 flex items-center justify-between">
        <div className="text-[15px] font-semibold">→ {destName}</div>
        <button type="button" onClick={onClose} className="immersive-map-icon-btn" aria-label="Fermer">
          ×
        </button>
      </div>
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
      {loading && <div className="py-2 text-sm text-white/60">Calcul de l&apos;itinéraire…</div>}
      {!loading && error && <div className="py-2 text-sm text-red-300">{error}</div>}
      {!loading && !error && (
        <div className="mb-4 flex gap-5">
          <div>
            <div className="text-[22px] font-bold text-[#33bfa3]">{duration} min</div>
            <div className="text-xs text-white/50">durée totale</div>
          </div>
          <div>
            <div className="text-[22px] font-bold">{arrival}</div>
            <div className="text-xs text-white/50">arrivée estimée</div>
          </div>
        </div>
      )}
      {steps.map((step, i) => (
        <div key={i} className="flex items-center gap-3 border-t border-white/[.08] py-2.5">
          <span className="flex-none text-lg">{step.icon}</span>
          <div className="flex-1">
            <div className="text-sm text-white/[.92]">{step.label}</div>
            <div className="text-xs text-white/50">{step.detail}</div>
          </div>
          <span className="flex-none text-[12.5px] text-white/55">{step.duration}</span>
        </div>
      ))}
    </div>
  );
}
