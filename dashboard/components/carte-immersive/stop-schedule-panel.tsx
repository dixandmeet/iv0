"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import {
  activeStopPassages,
  lineBadgeTextColor,
  nextDayScheduleIndex,
  serviceDayElapsedSeconds,
  stopPassageWaitMinutes,
} from "@/lib/carte-immersive/stop-schedule";

export type SelectedMapStop = {
  id: string;
  name: string;
  code: string;
  stationName?: string;
  lat?: number;
  lng?: number;
};

type RealtimeStopPassage = {
  id: string;
  line: string;
  direction: string;
  destination: string;
  expectedAt: string;
  waitMinutes: number;
  realtime: boolean;
  lineColor: string;
};

type StopSchedulePanelProps = {
  stop: SelectedMapStop;
  onClose: () => void;
  onTrackPassage: (passage: ScheduledPassageSelection) => Promise<void>;
};

type SelectedLineSchedule = {
  line: string;
  direction: string;
  lineColor: string;
};

type DayScheduleTime = {
  seconds: number;
  time: string;
  dayOffset: number;
  departureId: string;
  profileId: string;
  routeId: string;
  vehicleType: "bus" | "tram";
};

export type ScheduledPassageSelection = DayScheduleTime & {
  serviceDate: string;
  line: string;
  direction: string;
  lineColor: string;
};

type IndexedDayScheduleTime = DayScheduleTime & {
  scheduleIndex: number;
};

const parisDateFormatter = new Intl.DateTimeFormat("fr-CA", {
  timeZone: "Europe/Paris",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});
const longDateFormatter = new Intl.DateTimeFormat("fr-FR", {
  weekday: "long",
  day: "numeric",
  month: "long",
  year: "numeric",
  timeZone: "Europe/Paris",
});

function todayInParis(): string {
  return parisDateFormatter.format(new Date());
}

function moveDate(date: string, days: number): string {
  const value = new Date(`${date}T12:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

function longDate(date: string): string {
  return longDateFormatter.format(new Date(`${date}T12:00:00Z`));
}

export function StopSchedulePanel({
  stop,
  onClose,
  onTrackPassage,
}: StopSchedulePanelProps) {
  const [passages, setPassages] = useState<RealtimeStopPassage[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nowMs, setNowMs] = useState(() => Date.now());
  const [selectedLine, setSelectedLine] = useState<SelectedLineSchedule | null>(null);
  const [selectedDate, setSelectedDate] = useState(todayInParis);
  const [dayTimes, setDayTimes] = useState<DayScheduleTime[]>([]);
  const [dayLoading, setDayLoading] = useState(false);
  const [dayError, setDayError] = useState<string | null>(null);
  const nextPassageRef = useRef<HTMLButtonElement | null>(null);
  const [trackingPassageKey, setTrackingPassageKey] = useState<string | null>(null);
  const [trackingError, setTrackingError] = useState<string | null>(null);

  useEffect(() => {
    const interval = window.setInterval(() => setNowMs(Date.now()), 1_000);
    return () => window.clearInterval(interval);
  }, []);

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
          setNowMs(Date.now());
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

  useEffect(() => {
    if (!selectedLine) return;
    const controller = new AbortController();
    const params = new URLSearchParams({
      name: stop.stationName || stop.name,
      line: selectedLine.line,
      direction: selectedLine.direction,
      date: selectedDate,
    });
    queueMicrotask(() => {
      if (controller.signal.aborted) return;
      setDayLoading(true);
      setDayError(null);
    });

    void fetch(`/api/carte-immersive/stop-day-schedule?${params.toString()}`, {
      signal: controller.signal,
    })
      .then(async (response) => {
        const data = (await response.json()) as {
          times?: DayScheduleTime[];
          error?: string;
        };
        if (!response.ok) throw new Error(data.error || "Horaires indisponibles");
        setDayTimes(data.times ?? []);
      })
      .catch((reason: unknown) => {
        if (controller.signal.aborted) return;
        setDayTimes([]);
        setDayError(reason instanceof Error ? reason.message : "Horaires indisponibles");
      })
      .finally(() => {
        if (!controller.signal.aborted) setDayLoading(false);
      });

    return () => controller.abort();
  }, [selectedDate, selectedLine, stop.name, stop.stationName]);

  const groups = useMemo(() => {
    const grouped = new Map<string, {
      line: string;
      lineColor: string;
      direction: string;
      passages: RealtimeStopPassage[];
    }>();
    for (const passage of activeStopPassages(passages, nowMs)) {
      const key = `${passage.line}|${passage.direction}`;
      const group = grouped.get(key) ?? {
        line: passage.line,
        lineColor: passage.lineColor,
        direction: passage.direction,
        passages: [],
      };
      if (group.passages.length < 3) group.passages.push(passage);
      grouped.set(key, group);
    }
    return [...grouped.values()];
  }, [nowMs, passages]);

  const hours = useMemo(() => {
    const grouped = new Map<string, IndexedDayScheduleTime[]>();
    for (const [scheduleIndex, passage] of dayTimes.entries()) {
      const key = `${passage.dayOffset}-${passage.time.slice(0, 2)}`;
      const values = grouped.get(key) ?? [];
      values.push({ ...passage, scheduleIndex });
      grouped.set(key, values);
    }
    return [...grouped.entries()].map(([key, values]) => ({
      key,
      hour: values[0]?.time.slice(0, 2) ?? "--",
      dayOffset: values[0]?.dayOffset ?? 0,
      values,
    }));
  }, [dayTimes]);
  const elapsedServiceSeconds = useMemo(
    () => serviceDayElapsedSeconds(selectedDate, nowMs),
    [nowMs, selectedDate],
  );
  const nextPassageIndex = useMemo(
    () => nextDayScheduleIndex(dayTimes, selectedDate, nowMs),
    [dayTimes, nowMs, selectedDate],
  );
  const nextPassage = nextPassageIndex >= 0 ? dayTimes[nextPassageIndex] : null;

  useEffect(() => {
    if (!selectedLine || dayLoading || nextPassageIndex < 0) return;
    const frame = window.requestAnimationFrame(() => {
      nextPassageRef.current?.scrollIntoView({
        behavior: "smooth",
        block: "center",
      });
    });
    return () => window.cancelAnimationFrame(frame);
  }, [dayLoading, nextPassageIndex, selectedLine]);

  return (
    <aside className="immersive-map-panel immersive-map-panel-anim absolute bottom-6 left-5 z-[399] w-[380px] max-w-[calc(100vw-40px)] rounded-[22px] p-5">
      <div className="mb-1 flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex items-center gap-2">
            {selectedLine && (
              <button
                type="button"
                onClick={() => setSelectedLine(null)}
                className="rounded-lg bg-white/[.08] px-2 py-1 text-xs text-white/70 hover:bg-white/[.12]"
                aria-label="Revenir aux prochains passages"
              >
                ←
              </button>
            )}
            <div className="text-[10px] font-semibold uppercase tracking-[0.14em] text-[#5fe0c4]">
              {selectedLine ? "Horaires de la journée" : "Prochains passages"}
            </div>
          </div>
          <h2 className="mt-1 truncate text-base font-semibold text-white">{stop.stationName || stop.name}</h2>
          {selectedLine ? (
            <div className="mt-1 flex items-center gap-1.5 text-xs text-white/50">
              <span
                className="rounded-md px-1.5 py-0.5 text-[10px] font-extrabold"
                style={{
                  backgroundColor: selectedLine.lineColor,
                  color: lineBadgeTextColor(selectedLine.lineColor),
                }}
              >
                {selectedLine.line}
              </span>
              <span className="truncate">vers {selectedLine.direction}</span>
            </div>
          ) : (
            <p className="mt-0.5 text-xs text-white/50">Temps d’attente en temps réel</p>
          )}
        </div>
        <button type="button" onClick={onClose} className="immersive-map-icon-btn flex-none" aria-label="Fermer les horaires">×</button>
      </div>

      {selectedLine && (
        <div className="mt-4 flex items-center gap-2 border-t border-white/[.08] pt-3">
          <button
            type="button"
            onClick={() => setSelectedDate((date) => moveDate(date, -1))}
            className="rounded-lg bg-white/[.07] px-2.5 py-2 text-sm text-white/70 hover:bg-white/[.12]"
            aria-label="Jour précédent"
          >
            ‹
          </button>
          <label className="min-w-0 flex-1">
            <span className="sr-only">Choisir un jour</span>
            <input
              type="date"
              value={selectedDate}
              onChange={(event) => setSelectedDate(event.target.value)}
              className="w-full rounded-xl border border-white/[.1] bg-white/[.06] px-3 py-2 text-xs font-medium text-white [color-scheme:dark]"
            />
          </label>
          <button
            type="button"
            onClick={() => setSelectedDate((date) => moveDate(date, 1))}
            className="rounded-lg bg-white/[.07] px-2.5 py-2 text-sm text-white/70 hover:bg-white/[.12]"
            aria-label="Jour suivant"
          >
            ›
          </button>
        </div>
      )}

      <div className={`${selectedLine ? "mt-2" : "mt-4 border-t border-white/[.08] pt-3"} max-h-[55vh] space-y-2 overflow-y-auto`}>
        {selectedLine && (
          <p className="px-1 pb-1 text-xs capitalize text-white/50">{longDate(selectedDate)}</p>
        )}
        {selectedLine && !dayLoading && !dayError && nextPassage && (
          <div
            className="flex items-center justify-between gap-3 rounded-xl border border-[#5fe0c4]/35 bg-[#5fe0c4]/10 px-3 py-2"
            aria-live="polite"
          >
            <span className="text-[10px] font-semibold uppercase tracking-[0.12em] text-[#5fe0c4]">
              Prochain passage
            </span>
            <strong className="text-sm font-extrabold tabular-nums text-white">
              {nextPassage.time}{nextPassage.dayOffset > 0 ? " +1" : ""}
            </strong>
          </div>
        )}
        {selectedLine && trackingError && (
          <p className="rounded-xl border border-amber-300/20 bg-amber-300/[.08] px-3 py-2 text-xs text-amber-100/80">
            {trackingError}
          </p>
        )}
        {selectedLine && dayLoading && (
          <p className="py-4 text-sm text-white/55">Chargement de la journée…</p>
        )}
        {selectedLine && !dayLoading && dayError && (
          <p className="py-4 text-sm text-white/55">{dayError}</p>
        )}
        {selectedLine && !dayLoading && !dayError && hours.map((group) => {
          const containsNextPassage = group.values.some(
            (passage) => passage.scheduleIndex === nextPassageIndex,
          );
          return (
          <section
            key={group.key}
            className={`flex gap-3 rounded-xl px-3 py-2.5 ${containsNextPassage ? "bg-[#5fe0c4]/[.07] ring-1 ring-inset ring-[#5fe0c4]/20" : "bg-white/[.045]"}`}
          >
            <div className="w-12 flex-none pt-1 text-xs font-semibold text-white/45">
              {group.hour} h{group.dayOffset > 0 ? " +1" : ""}
            </div>
            <div className="flex flex-1 flex-wrap gap-1.5">
              {group.values.map((passage) => {
                const isPassed = elapsedServiceSeconds != null
                  && passage.seconds < elapsedServiceSeconds;
                const isNext = passage.scheduleIndex === nextPassageIndex;
                const passageKey = `${passage.departureId}-${passage.seconds}`;
                const isOpeningTracking = trackingPassageKey === passageKey;
                return (
                  <button
                    type="button"
                    key={`${passage.seconds}-${passage.time}`}
                    ref={isNext ? nextPassageRef : undefined}
                    disabled={isPassed || trackingPassageKey != null}
                    onClick={() => {
                      if (isPassed || !selectedLine) return;
                      setTrackingPassageKey(passageKey);
                      setTrackingError(null);
                      void onTrackPassage({
                        ...passage,
                        serviceDate: selectedDate,
                        line: selectedLine.line,
                        direction: selectedLine.direction,
                        lineColor: selectedLine.lineColor,
                      })
                        .catch((reason: unknown) => {
                          setTrackingError(
                            reason instanceof Error
                              ? reason.message
                              : "Ce véhicule ne peut pas être suivi pour le moment.",
                          );
                        })
                        .finally(() => setTrackingPassageKey(null));
                    }}
                    className={`inline-flex min-w-10 items-center justify-center gap-1.5 rounded-lg px-2 py-1 text-center text-xs font-semibold tabular-nums ${
                      isPassed
                        ? "cursor-default bg-white/[.025] text-white/25 line-through decoration-white/30"
                        : isNext
                          ? "cursor-pointer bg-[#5fe0c4] font-extrabold text-[#102018] shadow-[0_0_0_3px_rgba(95,224,196,0.13)] transition-transform hover:scale-[1.03] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white"
                          : "cursor-pointer bg-white/[.08] text-white/85 transition-colors hover:bg-white/[.14] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5fe0c4]"
                    }`}
                    aria-current={isNext ? "time" : undefined}
                    aria-label={`${passage.time}${passage.dayOffset > 0 ? " le lendemain" : ""}${isPassed ? ", passage effectué" : isNext ? ", prochain passage, suivre le véhicule" : ", suivre le véhicule"}`}
                    title={isPassed ? "Passage effectué" : "Suivre ce véhicule"}
                  >
                    {passage.time.slice(3)}
                    {isOpeningTracking ? (
                      <span className="text-[8px] font-black uppercase tracking-[0.08em]">
                        Ouverture…
                      </span>
                    ) : isNext && (
                      <span className="text-[8px] font-black uppercase tracking-[0.08em]">
                        Prochain
                      </span>
                    )}
                  </button>
                );
              })}
            </div>
          </section>
          );
        })}
        {selectedLine && !dayLoading && !dayError && dayTimes.length === 0 && (
          <p className="py-4 text-sm text-white/55">Aucun passage prévu ce jour-là.</p>
        )}
        {!selectedLine && (
          <>
        {loading && <p className="py-4 text-sm text-white/55">Chargement des passages en direct…</p>}
        {!loading && error && <p className="py-4 text-sm text-white/55">{error}</p>}
        {!loading && !error && groups.map((group) => (
          <button
            type="button"
            key={`${group.line}-${group.direction}`}
            onClick={() => {
              setSelectedDate(todayInParis());
              setSelectedLine({
                line: group.line,
                direction: group.direction,
                lineColor: group.lineColor,
              });
            }}
            className="block w-full rounded-2xl bg-white/[.05] p-3 text-left transition-colors hover:bg-white/[.09] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5fe0c4]"
            aria-label={`Voir les horaires de la ligne ${group.line} vers ${group.direction}`}
          >
            <div className="mb-2.5 flex items-center gap-2">
              <span
                className="flex min-w-9 items-center justify-center rounded-lg px-2 py-1 text-xs font-extrabold"
                style={{
                  backgroundColor: group.lineColor,
                  color: lineBadgeTextColor(group.lineColor),
                }}
              >
                {group.line}
              </span>
              <span className="truncate text-sm font-medium text-white/90">→ {group.direction}</span>
            </div>
            <div className="space-y-1.5">
              {group.passages.map((passage) => (
                <div key={passage.id} className="flex items-center justify-between gap-3 text-sm">
                  <span className="truncate text-white/55">{passage.destination}</span>
                  <span className="font-bold tabular-nums text-white">
                    {(() => {
                      const waitMinutes = stopPassageWaitMinutes(passage.expectedAt, nowMs);
                      const displayedWait = waitMinutes ?? passage.waitMinutes;
                      return displayedWait <= 0 ? "Imminent" : `${displayedWait} min`;
                    })()}
                    {passage.realtime && <span className="ml-1 text-[#5fe0c4]" aria-label="Temps réel">∿</span>}
                  </span>
                </div>
              ))}
            </div>
          </button>
        ))}
        {!loading && !error && groups.length === 0 && (
          <p className="py-4 text-sm text-white/55">Aucun autre passage prévu prochainement.</p>
        )}
          </>
        )}
      </div>
      <p className="mb-0 mt-3 text-[11px] text-white/35">
        {selectedLine
          ? "Source GTFS Naolib · horaires théoriques"
          : "Source Naolib · actualisation toutes les 30 secondes"}
      </p>
    </aside>
  );
}
