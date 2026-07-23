"use client";

import { lineBadgeTextColor } from "@/lib/carte-immersive/stop-schedule";

type StopLine = {
  shortName: string;
  color?: string;
  mode: "bus" | "tram" | "navibus";
};

export type StopCorrespondance = {
  id: string;
  name: string;
  code: string;
  lat?: number;
  lng?: number;
  distanceMeters: number;
  lines: StopLine[];
};

type CorrespondancesPanelProps = {
  stops: StopCorrespondance[];
  locating: boolean;
  onSelect: (stop: StopCorrespondance) => void;
  onClose: () => void;
};

const MODE_FALLBACK_COLOR: Record<StopLine["mode"], string> = {
  bus: "#2f6df6",
  tram: "#e0483d",
  navibus: "#1f9ec9",
};

function formatDistance(distance: number): string {
  if (distance < 1_000) return `${Math.max(10, Math.round(distance / 10) * 10)} m`;
  return `${(distance / 1_000).toFixed(1).replace(".", ",")} km`;
}

export function CorrespondancesPanel({
  stops,
  locating,
  onSelect,
  onClose,
}: CorrespondancesPanelProps) {
  return (
    <aside
      className="immersive-map-correspondances-panel immersive-map-panel immersive-map-panel-anim absolute inset-x-2.5 bottom-3 z-[420] flex max-h-[calc(100dvh-94px)] flex-col overflow-hidden rounded-[20px]"
      aria-label="Correspondances à proximité"
    >
      <header className="flex items-center justify-between gap-2 px-4 pb-2 pt-4">
        <div className="min-w-0">
          <div className="text-[15px] font-semibold text-white">Correspondances</div>
          <div className="mt-0.5 text-[11px] text-white/48">
            Arrêts à proximité, du plus proche au plus lointain
          </div>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="immersive-map-icon-btn flex-none"
          aria-label="Fermer"
        >
          ×
        </button>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto px-2.5 pb-3">
        {stops.length > 0 ? (
          <ul className="flex flex-col gap-1.5">
            {stops.map((stop) => (
              <li key={stop.id}>
                <button
                  type="button"
                  onClick={() => onSelect(stop)}
                  className="immersive-map-global-result flex w-full items-start gap-3 rounded-[14px] px-2.5 py-2 text-left"
                >
                  <span
                    className="immersive-map-global-result-icon immersive-map-global-result-icon--stop mt-0.5 flex-none"
                    aria-hidden="true"
                  >
                    🚏
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-[13px] font-semibold text-white">
                      {stop.name}
                    </span>
                    {stop.lines.length > 0 ? (
                      <span className="mt-1.5 flex flex-wrap gap-1">
                        {stop.lines.map((line) => {
                          const background = line.color ?? MODE_FALLBACK_COLOR[line.mode];
                          return (
                            <span
                              key={`${stop.id}-${line.shortName}`}
                              className="inline-flex min-w-[22px] items-center justify-center rounded-md px-1.5 py-0.5 text-[11px] font-bold leading-none"
                              style={{
                                backgroundColor: background,
                                color: lineBadgeTextColor(background),
                              }}
                            >
                              {line.shortName}
                            </span>
                          );
                        })}
                      </span>
                    ) : (
                      <span className="mt-0.5 block text-[11px] text-white/38">
                        Lignes en cours de chargement…
                      </span>
                    )}
                  </span>
                  <span className="mt-0.5 flex-none rounded-full bg-white/[.07] px-2 py-1 text-[11px] font-semibold text-[#8cf0da]">
                    {formatDistance(stop.distanceMeters)}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        ) : (
          <div className="px-4 py-8 text-center">
            <div className="text-sm font-semibold text-white/75">
              {locating ? "Localisation en cours…" : "Aucun arrêt à proximité"}
            </div>
            <div className="mt-1 text-xs text-white/40">
              {locating
                ? "Autorisez la géolocalisation pour voir les arrêts autour de vous."
                : "Aucun arrêt desservi n’a été trouvé près de votre position."}
            </div>
          </div>
        )}
      </div>
    </aside>
  );
}
