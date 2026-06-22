"use client";

import { useCallback, useRef, useState } from "react";
import { ChevronLeft, ChevronRight, GripVertical, Plus } from "lucide-react";
import {
  POINT_TYPE_COLORS,
  type RoutePoint,
} from "@/lib/line-editor-types";

interface LineStopTimelineProps {
  stops: RoutePoint[];
  allPoints: RoutePoint[];
  selectedPointId: string | null;
  lineColor: string;
  onSelectStop: (pointId: string) => void;
  onReorder: (fromIndex: number, toIndex: number) => void;
  onAddStop: (stopIndex: number) => void;
  onAddStopAfterSelected: () => void;
}

export function LineStopTimeline({
  stops,
  allPoints,
  selectedPointId,
  lineColor,
  onSelectStop,
  onReorder,
  onAddStop,
  onAddStopAfterSelected,
}: LineStopTimelineProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const [dragIndex, setDragIndex] = useState<number | null>(null);
  const [overIndex, setOverIndex] = useState<number | null>(null);

  const scroll = useCallback((dir: "left" | "right") => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollBy({ left: dir === "left" ? -280 : 280, behavior: "smooth" });
  }, []);

  const travelTimeBetween = useCallback(
    (stop: RoutePoint, stopIndex: number): number | null => {
      if (stopIndex === 0) return null;
      const prevStop = stops[stopIndex - 1];
      const prevIdx = allPoints.findIndex((p) => p.id === prevStop.id);
      const currIdx = allPoints.findIndex((p) => p.id === stop.id);
      if (prevIdx < 0 || currIdx < 0) return stop.stop?.travelTimeMinutes ?? null;

      let minutes = 0;
      for (let i = prevIdx + 1; i <= currIdx; i++) {
        const pt = allPoints[i];
        if (pt.stop?.travelTimeMinutes) {
          minutes += pt.stop.travelTimeMinutes;
        } else if (i === currIdx && stop.stop) {
          minutes += stop.stop.travelTimeMinutes;
        } else {
          minutes += 1;
        }
      }
      return minutes || stop.stop?.travelTimeMinutes || null;
    },
    [allPoints, stops],
  );

  const handleDrop = useCallback(
    (toIndex: number) => {
      if (dragIndex != null && dragIndex !== toIndex) {
        onReorder(dragIndex, toIndex);
      }
      setDragIndex(null);
      setOverIndex(null);
    },
    [dragIndex, onReorder],
  );

  if (stops.length === 0) {
    return (
      <footer className="line-editor-timeline line-editor-timeline--empty">
        <p>Aucun arrêt défini sur cette ligne.</p>
        <button
          type="button"
          className="line-editor-timeline-add-btn"
          onClick={() => onAddStop(0)}
        >
          <Plus className="h-4 w-4" />
          Ajouter un arrêt
        </button>
      </footer>
    );
  }

  return (
    <footer className="line-editor-timeline">
      <div className="line-editor-timeline-header">
        <span className="line-editor-timeline-title">Plan de ligne</span>
        <span className="line-editor-timeline-count">{stops.length} arrêts</span>
        <button
          type="button"
          className="line-editor-timeline-add-btn line-editor-timeline-add-btn--header"
          onClick={onAddStopAfterSelected}
        >
          <Plus className="h-3.5 w-3.5" />
          Ajouter un arrêt
        </button>
      </div>

      <div className="line-editor-timeline-scroll-wrap">
        <button
          type="button"
          className="line-editor-timeline-nav"
          onClick={() => scroll("left")}
          aria-label="Défiler vers la gauche"
        >
          <ChevronLeft className="h-4 w-4" />
        </button>

        <div className="line-editor-timeline-scroll" ref={scrollRef}>
          <div
            className="line-editor-timeline-track"
            style={{ "--line-color": lineColor } as React.CSSProperties}
          >
            {stops.map((stop, index) => {
              const isSelected = stop.id === selectedPointId;
              const isTerminusStart = stop.type === "terminus_start";
              const isTerminusEnd = stop.type === "terminus_end";
              const isHub = stop.type === "hub";
              const travel = travelTimeBetween(stop, index);
              const color = POINT_TYPE_COLORS[stop.type];

              return (
                <div key={stop.id} className="line-editor-timeline-segment">
                  {index > 0 && (
                    <div className="line-editor-timeline-travel">
                      <button
                        type="button"
                        className="line-editor-timeline-insert-btn"
                        onClick={() => onAddStop(index)}
                        title="Insérer un arrêt ici"
                        aria-label={`Insérer un arrêt avant ${stop.stop?.name || `arrêt ${index + 1}`}`}
                      >
                        <Plus className="h-3 w-3" />
                      </button>
                      {travel != null && <span>{travel} min</span>}
                    </div>
                  )}
                  <div
                    className={`line-editor-timeline-stop${isSelected ? " selected" : ""}${isTerminusStart ? " terminus-start" : ""}${isTerminusEnd ? " terminus-end" : ""}${isHub ? " hub" : ""}${dragIndex === index ? " dragging" : ""}${overIndex === index ? " drop-target" : ""}`}
                    draggable
                    onDragStart={() => setDragIndex(index)}
                    onDragOver={(e) => {
                      e.preventDefault();
                      setOverIndex(index);
                    }}
                    onDragLeave={() => setOverIndex(null)}
                    onDrop={() => handleDrop(index)}
                    onDragEnd={() => {
                      setDragIndex(null);
                      setOverIndex(null);
                    }}
                    onClick={() => onSelectStop(stop.id)}
                    role="button"
                    tabIndex={0}
                    onKeyDown={(e) => {
                      if (e.key === "Enter" || e.key === " ") {
                        e.preventDefault();
                        onSelectStop(stop.id);
                      }
                    }}
                  >
                    <GripVertical className="line-editor-timeline-grip h-3 w-3" />
                    <span
                      className="line-editor-timeline-dot"
                      style={{
                        background: color,
                        boxShadow: isSelected ? `0 0 0 3px ${color}40` : undefined,
                      }}
                    />
                    <div className="line-editor-timeline-stop-info">
                      <span className="line-editor-timeline-stop-name">
                        {stop.stop?.name || `Arrêt ${index + 1}`}
                      </span>
                      {stop.stop?.code && (
                        <span className="line-editor-timeline-stop-code">
                          {stop.stop.code}
                        </span>
                      )}
                    </div>
                    {isTerminusStart && (
                      <span className="line-editor-timeline-terminus-badge line-editor-timeline-terminus-badge--start">
                        Départ
                      </span>
                    )}
                    {isTerminusEnd && (
                      <span className="line-editor-timeline-terminus-badge line-editor-timeline-terminus-badge--end">
                        Arrivée
                      </span>
                    )}
                    {isHub && (
                      <span className="line-editor-timeline-hub-badge">
                        Correspondance
                      </span>
                    )}
                  </div>
                </div>
              );
            })}
            <div className="line-editor-timeline-segment">
              <div className="line-editor-timeline-travel">
                <button
                  type="button"
                  className="line-editor-timeline-insert-btn"
                  onClick={() => onAddStop(stops.length)}
                  title="Ajouter un arrêt en fin de ligne"
                  aria-label="Ajouter un arrêt en fin de ligne"
                >
                  <Plus className="h-3 w-3" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <button
          type="button"
          className="line-editor-timeline-nav"
          onClick={() => scroll("right")}
          aria-label="Défiler vers la droite"
        >
          <ChevronRight className="h-4 w-4" />
        </button>
      </div>
    </footer>
  );
}
