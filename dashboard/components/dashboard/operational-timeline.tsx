"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { Ban, ChevronLeft, ChevronRight, Plus, TrainFront, Trash2, Undo2 } from "lucide-react";
import { motion } from "framer-motion";
import {
  type RegulationLine,
  type RegulationStop,
  delayColor,
  formatDelayMinutes,
  segmentColor,
} from "@/lib/regulation-mock-data";
import { deleteStopAt } from "@/lib/regulation-stop-edits";
import { getTimelineMinWidth } from "@/lib/regulation-data";

interface OperationalTimelineProps {
  line: RegulationLine;
  loading?: boolean;
  onStopsChange?: (stops: RegulationStop[]) => void;
}

function vehicleRailColor(delays: number[]): string {
  const max = Math.max(...delays);
  if (max >= 5) return "#EF4444";
  if (max >= 1) return "#F59E0B";
  if (delays.some((d) => d < 0)) return "#22C55E";
  return "rgba(255, 255, 255, 0.25)";
}

function vehiclePositionPercent(
  segmentIndex: number,
  segmentProgress: number,
  stopCount: number,
): number {
  if (stopCount <= 1) return 0;
  const maxSegment = stopCount - 1;
  const clamped = Math.min(Math.max(segmentIndex + segmentProgress, 0), maxSegment);
  return (clamped / maxSegment) * 100;
}

function segmentQualityForStop(
  segmentQuality: RegulationLine["segmentQuality"],
  index: number,
  stop: RegulationStop,
  nextStop: RegulationStop | undefined,
): "on-time" | "light-delay" | "major-delay" {
  if (stop.unavailable || nextStop?.unavailable) return "major-delay";
  return segmentQuality[index] ?? "on-time";
}

export function OperationalTimeline({
  line,
  loading,
  onStopsChange,
}: OperationalTimelineProps) {
  const { stops, segmentQuality, vehicles } = line;
  const stopCount = stops.length;
  const gridColumns = `72px repeat(${stopCount}, 72px)`;
  const minWidth = getTimelineMinWidth(stopCount);

  const [addingAtIndex, setAddingAtIndex] = useState<number | null>(null);
  const [newStopName, setNewStopName] = useState("");
  const addInputRef = useRef<HTMLInputElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);

  const updateScrollState = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    setCanScrollLeft(el.scrollLeft > 4);
    setCanScrollRight(el.scrollLeft + el.clientWidth < el.scrollWidth - 4);
  }, []);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;

    updateScrollState();
    el.addEventListener("scroll", updateScrollState, { passive: true });

    const observer = new ResizeObserver(updateScrollState);
    observer.observe(el);

    return () => {
      el.removeEventListener("scroll", updateScrollState);
      observer.disconnect();
    };
  }, [stopCount, updateScrollState]);

  const scrollTimeline = useCallback((direction: "left" | "right") => {
    const el = scrollRef.current;
    if (!el) return;
    const amount = Math.max(el.clientWidth * 0.55, 240);
    el.scrollBy({
      left: direction === "left" ? -amount : amount,
      behavior: "smooth",
    });
  }, []);

  const commitAdd = useCallback(
    (afterIndex: number) => {
      const trimmed = newStopName.trim();
      if (!trimmed || !onStopsChange) return;

      const next = [...stops];
      next.splice(afterIndex + 1, 0, {
        stopId: `custom-${Date.now()}`,
        name: trimmed,
        theoreticalTime: "—",
        unavailable: false,
      });

      if (next.length >= 2) {
        next[0] = { ...next[0], isTerminus: true };
        next[next.length - 1] = { ...next[next.length - 1], isTerminus: true };
        for (let i = 1; i < next.length - 1; i++) {
          next[i] = { ...next[i], isTerminus: false };
        }
      }

      onStopsChange(next);
      setNewStopName("");
      setAddingAtIndex(null);
    },
    [newStopName, onStopsChange, stops],
  );

  const startAdd = (index: number) => {
    setAddingAtIndex(index);
    setNewStopName("");
    requestAnimationFrame(() => addInputRef.current?.focus());
  };

  return (
    <div className="regulation-timeline">
      {loading && (
        <p className="mb-2 text-[11px] text-[#64748B]">Actualisation de la frise…</p>
      )}

      <div className="regulation-timeline-toolbar">
        <p className="regulation-timeline-label mb-0">
          Frise des arrêts · {stopCount} arrêts
        </p>
        <div className="regulation-timeline-toolbar-actions">
          {(canScrollLeft || canScrollRight) && (
            <div className="regulation-timeline-nav">
              <button
                type="button"
                className="regulation-timeline-nav-btn"
                onClick={() => scrollTimeline("left")}
                disabled={!canScrollLeft}
                aria-label="Défiler vers la gauche"
              >
                <ChevronLeft className="h-4 w-4" strokeWidth={1.5} />
              </button>
              <button
                type="button"
                className="regulation-timeline-nav-btn"
                onClick={() => scrollTimeline("right")}
                disabled={!canScrollRight}
                aria-label="Défiler vers la droite"
              >
                <ChevronRight className="h-4 w-4" strokeWidth={1.5} />
              </button>
            </div>
          )}
          {onStopsChange && (
            <p className="regulation-timeline-hint">
              Cliquez sur un arrêt pour le gérer
            </p>
          )}
        </div>
      </div>

      <div className="regulation-timeline-scroll-wrap">
        {canScrollLeft && (
          <button
            type="button"
            className="regulation-timeline-scroll-overlay left"
            onClick={() => scrollTimeline("left")}
            aria-label="Défiler vers la gauche"
          >
            <ChevronLeft className="h-4 w-4" strokeWidth={2} />
          </button>
        )}
        {canScrollRight && (
          <button
            type="button"
            className="regulation-timeline-scroll-overlay right"
            onClick={() => scrollTimeline("right")}
            aria-label="Défiler vers la droite"
          >
            <ChevronRight className="h-4 w-4" strokeWidth={2} />
          </button>
        )}
        <div
          ref={scrollRef}
          className="regulation-timeline-scroll flex-1 min-h-0"
        >
        <div className="regulation-timeline-inner" style={{ minWidth }}>
          <div className="regulation-stops-grid" style={{ gridTemplateColumns: gridColumns }}>
            <div className="regulation-sticky-col" />
            {stops.map((stop, index) => (
              <div
                key={`${stop.stopId ?? index}-${stop.name}`}
                className={`regulation-stop-label${stop.unavailable ? " unavailable" : ""}`}
              >
                <span className="text-[11px] font-medium leading-tight text-white">
                  {stop.name}
                </span>
                {stop.unavailable && (
                  <span className="regulation-stop-unavailable-badge">Indisponible</span>
                )}
                {stop.isTerminus && !stop.unavailable && (
                  <span className="text-[9px] uppercase tracking-wide text-[#94A3B8]">
                    Terminus
                  </span>
                )}
                <span className="text-[10px] text-[#64748B]">{stop.theoreticalTime}</span>

                {onStopsChange && (
                  <div className="regulation-stop-actions">
                    <button
                      type="button"
                      className="regulation-stop-action-btn"
                      title={
                        stop.unavailable
                          ? "Rendre disponible"
                          : "Marquer indisponible"
                      }
                      onClick={() =>
                        onStopsChange(
                          stops.map((s, i) =>
                            i === index ? { ...s, unavailable: !s.unavailable } : s,
                          ),
                        )
                      }
                    >
                      {stop.unavailable ? (
                        <Undo2 className="h-3 w-3" />
                      ) : (
                        <Ban className="h-3 w-3" />
                      )}
                    </button>
                    <button
                      type="button"
                      className="regulation-stop-action-btn"
                      title="Ajouter un arrêt après"
                      onClick={() => startAdd(index)}
                    >
                      <Plus className="h-3 w-3" />
                    </button>
                    <button
                      type="button"
                      className="regulation-stop-action-btn danger"
                      title="Supprimer l'arrêt"
                      disabled={stopCount <= 2}
                      onClick={() => {
                        const next = deleteStopAt(stops, index);
                        if (next) onStopsChange(next);
                      }}
                    >
                      <Trash2 className="h-3 w-3" />
                    </button>
                  </div>
                )}

                {addingAtIndex === index && onStopsChange && (
                  <div className="regulation-stop-add-form">
                    <input
                      ref={addInputRef}
                      type="text"
                      placeholder="Nom de l'arrêt"
                      value={newStopName}
                      onChange={(e) => setNewStopName(e.target.value)}
                      onKeyDown={(e) => {
                        if (e.key === "Enter") commitAdd(index);
                        if (e.key === "Escape") {
                          setAddingAtIndex(null);
                          setNewStopName("");
                        }
                      }}
                    />
                    <button
                      type="button"
                      className="regulation-stop-add-confirm"
                      onClick={() => commitAdd(index)}
                    >
                      Ajouter
                    </button>
                  </div>
                )}
              </div>
            ))}
          </div>

          <div className="regulation-stops-track" style={{ gridTemplateColumns: gridColumns }}>
            <div className="regulation-sticky-col" />
            <div
              className="regulation-stop-nodes"
              style={{ gridColumn: `2 / ${stopCount + 2}` }}
            >
              {stops.map((stop, index) => (
                <div key={`${stop.stopId ?? index}-${stop.name}`} className="regulation-stop-node-wrap">
                  {index < stops.length - 1 && (
                    <div
                      className={`regulation-segment-line${
                        stop.unavailable || stops[index + 1]?.unavailable
                          ? " unavailable"
                          : ""
                      }`}
                      style={{
                        backgroundColor: segmentColor(
                          segmentQualityForStop(
                            segmentQuality,
                            index,
                            stop,
                            stops[index + 1],
                          ),
                        ),
                      }}
                    />
                  )}
                  <div
                    className={[
                      "regulation-stop-node",
                      stop.isTerminus ? "terminus" : "",
                      stop.unavailable ? "unavailable" : "",
                    ]
                      .filter(Boolean)
                      .join(" ")}
                  />
                </div>
              ))}
            </div>
          </div>

          <p className="regulation-timeline-label mt-4 mb-2">Véhicules en ligne</p>

          <div className="regulation-vehicles-list">
            {vehicles.map((vehicle, rowIndex) => {
              const position = vehiclePositionPercent(
                vehicle.segmentIndex,
                vehicle.segmentProgress,
                stopCount,
              );

              return (
                <motion.div
                  key={vehicle.id}
                  className="regulation-vehicle-row"
                  style={{ gridTemplateColumns: gridColumns }}
                  initial={{ opacity: 0, x: -12 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: rowIndex * 0.04, duration: 0.25 }}
                >
                  <span className="regulation-vehicle-id regulation-sticky-col">
                    {vehicle.id}
                  </span>
                  <div
                    className="regulation-vehicle-track"
                    style={{ gridColumn: `2 / ${stopCount + 2}` }}
                  >
                    <div
                      className="regulation-vehicle-rail"
                      style={{ background: vehicleRailColor(vehicle.delays) }}
                    />

                    {vehicle.delays.map((delay, stopIndex) => (
                      <span
                        key={`${vehicle.id}-${stopIndex}`}
                        className="regulation-delay-marker"
                        style={{
                          left: `${(stopIndex / (stopCount - 1)) * 100}%`,
                          color: delayColor(delay),
                        }}
                      >
                        {formatDelayMinutes(delay)}
                      </span>
                    ))}

                    <motion.div
                      className="regulation-tram-marker"
                      style={{ left: `${position}%` }}
                      animate={{ left: `${position}%` }}
                      transition={{ type: "spring", stiffness: 120, damping: 20 }}
                    >
                      <TrainFront className="h-4 w-4 text-white" strokeWidth={1.5} />
                    </motion.div>
                  </div>
                </motion.div>
              );
            })}
          </div>
        </div>
        </div>
      </div>
    </div>
  );
}
