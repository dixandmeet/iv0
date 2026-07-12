"use client";

import { useEffect, useMemo, useState } from "react";

export type SelectedMapStop = {
  id: string;
  name: string;
  code: string;
  stationName?: string;
};

type RealtimeStopPassage = {
  id: string;
  line: string;
  direction: string;
  destination: string;
  expectedAt: string;
  waitMinutes: number;
  realtime: boolean;
};

type StopSchedulePanelProps = {
  stop: SelectedMapStop;
  onClose: () => void;
};

export function StopSchedulePanel({ stop, onClose }: StopSchedulePanelProps) {
  const [passages, setPassages] = useState<RealtimeStopPassage[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    const stationName = stop.stationName || stop.name;

    const loadPassages = async () => {
      try {
        const response = await fetch(
          `/api/carte-immersive/stop-departures?name=${encodeURIComponent(stationName)}`,
          { cache: "no-store" },
        );
        const data = (await response.json()) as {
          passages?: RealtimeStopPassage[];
          error?: string;
        };
        if (cancelled) return;
        if (!response.ok || !data.passages) {
          setPassages([]);
          setError(data.error || "Horaires indisponibles");
        } else {
          setPassages(data.passages);
          setError(null);
        }
      } catch {
        if (!cancelled) {
          setPassages([]);
          setError("Horaires indisponibles");
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    void loadPassages();
    const interval = window.setInterval(() => void loadPassages(), 30_000);
    return () => {
      cancelled = true;
      window.clearInterval(interval);
    };
  }, [stop.name, stop.stationName]);

  const groups = useMemo(() => {
    const grouped = new Map<string, { line: string; direction: string; passages: RealtimeStopPassage[] }>();
    for (const passage of passages) {
      const key = `${passage.line}|${passage.direction}`;
      const group = grouped.get(key) ?? {
        line: passage.line,
        direction: passage.direction,
        passages: [],
      };
      if (group.passages.length < 3) group.passages.push(passage);
      grouped.set(key, group);
    }
    return [...grouped.values()];
  }, [passages]);

  return (
    <aside className="immersive-map-panel immersive-map-panel-anim absolute bottom-6 left-5 z-[399] w-[380px] max-w-[calc(100vw-40px)] rounded-[22px] p-5">
      <div className="mb-1 flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="text-[10px] font-semibold uppercase tracking-[0.14em] text-[#5fe0c4]">Prochains passages</div>
          <h2 className="mt-1 truncate text-base font-semibold text-white">{stop.stationName || stop.name}</h2>
          <p className="mt-0.5 text-xs text-white/50">Temps d’attente en temps réel</p>
        </div>
        <button type="button" onClick={onClose} className="immersive-map-icon-btn flex-none" aria-label="Fermer les horaires">×</button>
      </div>

      <div className="mt-4 max-h-[55vh] space-y-2 overflow-y-auto border-t border-white/[.08] pt-3">
        {loading && <p className="py-4 text-sm text-white/55">Chargement des passages en direct…</p>}
        {!loading && error && <p className="py-4 text-sm text-white/55">{error}</p>}
        {!loading && !error && groups.map((group) => (
          <section key={`${group.line}-${group.direction}`} className="rounded-2xl bg-white/[.05] p-3">
            <div className="mb-2.5 flex items-center gap-2">
              <span className="flex min-w-9 items-center justify-center rounded-lg bg-[#24ad5a] px-2 py-1 text-xs font-extrabold text-white">{group.line}</span>
              <span className="truncate text-sm font-medium text-white/90">→ {group.direction}</span>
            </div>
            <div className="space-y-1.5">
              {group.passages.map((passage) => (
                <div key={passage.id} className="flex items-center justify-between gap-3 text-sm">
                  <span className="truncate text-white/55">{passage.destination}</span>
                  <span className="font-bold tabular-nums text-white">
                    {passage.waitMinutes <= 0 ? "Imminent" : `${passage.waitMinutes} min`}
                    {passage.realtime && <span className="ml-1 text-[#5fe0c4]" aria-label="Temps réel">∿</span>}
                  </span>
                </div>
              ))}
            </div>
          </section>
        ))}
      </div>
      <p className="mb-0 mt-3 text-[11px] text-white/35">Source Naolib · actualisation toutes les 30 secondes</p>
    </aside>
  );
}
