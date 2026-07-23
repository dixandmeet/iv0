"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import {
  Ban,
  ChevronLeft,
  ChevronRight,
  Maximize2,
  Minimize2,
  Plus,
  TrainFront,
  Trash2,
  Undo2,
} from "lucide-react";
import type { LiveFleetPosition } from "@/lib/types";
import {
  type RegulationLine,
  type RegulationStop,
  delayColor,
  formatDelayMinutes,
  formatDelayLabel,
  segmentColor,
} from "@/lib/regulation-mock-data";
import { getTimelineMinWidth } from "@/lib/regulation-data";
import type { RouteTimelinePoint } from "@/lib/regulation-data";
import { useLineFleetTracking } from "@/hooks/use-line-fleet-tracking";
import { deleteStopAt } from "@/lib/regulation-stop-edits";
import { vehicleDetailHref } from "@/lib/vehicle-routes";
import { LinePlanDiagram, variantTabsSummary } from "@/components/dashboard/line-plan-diagram";
import {
  resolveActiveVariant,
  variantForTripId,
  type LineTopology,
} from "@/lib/line-topology";

interface OperationalTimelineProps {
  line: RegulationLine;
  fleet: LiveFleetPosition[];
  timelineStops: RouteTimelinePoint[];
  topology?: LineTopology | null;
  activeVariantId?: string | null;
  onVariantChange?: (variantId: string) => void;
  loading?: boolean;
  onStopsChange?: (stops: RegulationStop[]) => void;
  /** Affiche uniquement le véhicule ciblé sur la frise. */
  focusVehicleId?: string | null;
  /** Variante compacte pour la fiche véhicule. */
  embedded?: boolean;
  /** Autorise des positions fictives uniquement sur une fiche explicitement ouverte en démo. */
  allowDemo?: boolean;
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

function assignVehicleLanes(
  vehicles: RegulationLine["vehicles"],
  stopCount: number,
): Array<{ vehicle: RegulationLine["vehicles"][number]; position: number; lane: number }> {
  const threshold = 5;
  const sorted = vehicles
    .map((vehicle) => ({
      vehicle,
      position: vehiclePositionPercent(
        vehicle.segmentIndex,
        vehicle.segmentProgress,
        stopCount,
      ),
    }))
    .sort((a, b) => a.position - b.position);

  const placed: Array<{ position: number; lane: number }> = [];

  return sorted.map(({ vehicle, position }) => {
    let lane = 0;
    while (
      placed.some(
        (entry) => entry.lane === lane && Math.abs(entry.position - position) < threshold,
      )
    ) {
      lane += 1;
    }
    placed.push({ position, lane });
    return { vehicle, position, lane };
  });
}

export function OperationalTimeline({
  line,
  fleet,
  timelineStops,
  topology,
  activeVariantId,
  onVariantChange,
  loading,
  onStopsChange,
  focusVehicleId,
  embedded = false,
  allowDemo = false,
}: OperationalTimelineProps) {
  const { stops, segmentQuality } = line;
  const stopCount = stops.length;
  const useBranchingLayout = Boolean(topology?.isComplex && topology.laneCount > 0);

  const resolvedVariantId = useMemo(() => {
    if (!topology) return null;
    return resolveActiveVariant(
      topology,
      activeVariantId,
      fleet.find((v) => v.trip_id)?.trip_id,
    ).id;
  }, [topology, activeVariantId, fleet]);

  const vehicleVariants = useMemo(() => {
    const map = new Map<string, string>();
    if (!topology) return map;
    for (const vehicle of line.vehicles) {
      const fleetVehicle = fleet.find((v) => v.id === vehicle.id);
      const variant = variantForTripId(topology, fleetVehicle?.trip_id);
      if (variant) map.set(vehicle.id, variant.id);
    }
    return map;
  }, [topology, line.vehicles, fleet]);
  const stopColumnPx = embedded ? 84 : 72;
  const gridColumns = `72px repeat(${stopCount}, ${stopColumnPx}px)`;
  const minWidth = getTimelineMinWidth(stopCount, stopColumnPx);

  const { vehicles, isLive } = useLineFleetTracking(
    fleet,
    timelineStops,
    line.shortName,
    stopCount,
    focusVehicleId,
    allowDemo,
  );

  const vehiclesOnLine = useMemo(() => {
    const assigned = assignVehicleLanes(vehicles, stopCount);
    if (!focusVehicleId) return assigned;
    return assigned.filter(({ vehicle }) => vehicle.id === focusVehicleId);
  }, [vehicles, stopCount, focusVehicleId]);

  const containerRef = useRef<HTMLDivElement>(null);
  const [addingAtIndex, setAddingAtIndex] = useState<number | null>(null);
  const [newStopName, setNewStopName] = useState("");
  const addInputRef = useRef<HTMLInputElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);

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

  useEffect(() => {
    const onFullscreenChange = () => {
      setIsFullscreen(document.fullscreenElement === containerRef.current);
    };
    document.addEventListener("fullscreenchange", onFullscreenChange);
    return () => document.removeEventListener("fullscreenchange", onFullscreenChange);
  }, []);

  const toggleFullscreen = useCallback(() => {
    if (document.fullscreenElement) {
      void document.exitFullscreen();
      return;
    }
    void containerRef.current?.requestFullscreen();
  }, []);

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

  if (useBranchingLayout && topology && resolvedVariantId) {
    return (
      <div
        ref={containerRef}
        className={`regulation-timeline${isFullscreen ? " regulation-timeline--fullscreen" : ""}${embedded ? " regulation-timeline--embedded" : ""}`}
      >
        {loading && (
          <p className="mb-2 text-[11px] text-[#64748B]">Actualisation de la frise…</p>
        )}

        <div className="regulation-timeline-toolbar">
          <div className="flex items-center gap-2">
            <p className="regulation-timeline-label mb-0">
              {embedded
                ? "Position sur la ligne"
                : `Plan de ligne · ${variantTabsSummary(topology.variants)}`}
            </p>
            {!embedded && isLive && (
              <span className="regulation-live-badge">Temps réel</span>
            )}
          </div>
          <div className="regulation-timeline-toolbar-actions">
            {!embedded && (
              <button
                type="button"
                className="regulation-timeline-nav-btn"
                onClick={toggleFullscreen}
                aria-label={isFullscreen ? "Quitter le plein écran" : "Afficher en plein écran"}
              >
                {isFullscreen ? (
                  <Minimize2 className="h-4 w-4" strokeWidth={1.5} />
                ) : (
                  <Maximize2 className="h-4 w-4" strokeWidth={1.5} />
                )}
              </button>
            )}
          </div>
        </div>

        <LinePlanDiagram
          topology={topology}
          line={line}
          activeVariantId={resolvedVariantId}
          embedded={embedded}
          vehicles={vehiclesOnLine.map((v) => v.vehicle)}
          vehicleVariants={vehicleVariants}
          isLive={isLive}
          onVariantChange={onVariantChange}
        />
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      className={`regulation-timeline${isFullscreen ? " regulation-timeline--fullscreen" : ""}${embedded ? " regulation-timeline--embedded" : ""}`}
    >
      {loading && (
        <p className="mb-2 text-[11px] text-[#64748B]">Actualisation de la frise…</p>
      )}

      <div className="regulation-timeline-toolbar">
        <div className="flex items-center gap-2">
          <p className="regulation-timeline-label mb-0">
            {embedded ? "Position sur la ligne" : `Plan de ligne - ${stopCount} arrêts`}
          </p>
          {!embedded && isLive && (
            <span className="regulation-live-badge">Temps réel</span>
          )}
        </div>
        <div className="regulation-timeline-toolbar-actions">
          {!embedded && (
            <>
              <button
                type="button"
                className="regulation-timeline-nav-btn"
                onClick={toggleFullscreen}
                aria-label={isFullscreen ? "Quitter le plein écran" : "Afficher en plein écran"}
                title={isFullscreen ? "Quitter le plein écran" : "Plein écran"}
              >
                {isFullscreen ? (
                  <Minimize2 className="h-4 w-4" strokeWidth={1.5} />
                ) : (
                  <Maximize2 className="h-4 w-4" strokeWidth={1.5} />
                )}
              </button>
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
            </>
          )}
          {onStopsChange && !embedded && (
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
                {stop.stationId ? (
                  <Link
                    href={`/stations/${stop.stationId}`}
                    className="regulation-stop-name regulation-stop-name-link text-[11px] font-medium leading-tight"
                  >
                    {stop.name}
                  </Link>
                ) : (
                  <span className="regulation-stop-name text-[11px] font-medium leading-tight text-white">
                    {stop.name}
                  </span>
                )}
                {stop.unavailable && (
                  <span className="regulation-stop-unavailable-badge">Indisponible</span>
                )}
                {stop.isTerminus && !stop.unavailable && (
                  <span className="text-[9px] uppercase tracking-wide text-[#94A3B8]">
                    Terminus
                  </span>
                )}
                {!embedded && (
                  <span className="text-[10px] text-[#64748B]">{stop.theoreticalTime}</span>
                )}

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

              {vehiclesOnLine.map(({ vehicle, position, lane }) =>
                embedded ? (
                  <div
                    key={vehicle.id}
                    className="regulation-line-vehicle regulation-line-vehicle--focused"
                    style={{
                      left: `${position}%`,
                      bottom: `calc(50% + ${lane * 52}px)`,
                    }}
                    aria-label={`Véhicule ${vehicle.service}`}
                  >
                    <div className="regulation-line-vehicle-info">
                      <span className="regulation-line-vehicle-service">
                        {vehicle.service}
                      </span>
                    <span
                      className="regulation-line-vehicle-delay"
                      style={{ color: delayColor(vehicle.currentDelay) }}
                    >
                      {embedded ? formatDelayLabel(vehicle.currentDelay) : formatDelayMinutes(vehicle.currentDelay)}
                    </span>
                    </div>
                    <div className="regulation-tram-marker regulation-tram-marker--focused">
                      <TrainFront className="h-4 w-4 text-white" strokeWidth={1.5} />
                    </div>
                  </div>
                ) : (
                  <Link
                    key={vehicle.id}
                    href={vehicleDetailHref(vehicle.id, {
                      service: vehicle.service,
                      line: line.shortName,
                      delay: vehicle.currentDelay,
                      demo: !isLive,
                    })}
                    className="regulation-line-vehicle"
                    style={{
                      left: `${position}%`,
                      bottom: `calc(50% + ${lane * 52}px)`,
                    }}
                    title={`Voir la fiche véhicule ${vehicle.service}`}
                    aria-label={`Voir la fiche véhicule ${vehicle.service}`}
                  >
                    <div className="regulation-line-vehicle-info">
                      <span className="regulation-line-vehicle-service">
                        {vehicle.service}
                      </span>
                    <span
                      className="regulation-line-vehicle-delay"
                      style={{ color: delayColor(vehicle.currentDelay) }}
                    >
                      {embedded ? formatDelayLabel(vehicle.currentDelay) : formatDelayMinutes(vehicle.currentDelay)}
                    </span>
                    </div>
                    <div className="regulation-tram-marker">
                      <TrainFront className="h-4 w-4 text-white" strokeWidth={1.5} />
                    </div>
                  </Link>
                ),
              )}
            </div>
          </div>
        </div>
        </div>
      </div>
    </div>
  );
}
