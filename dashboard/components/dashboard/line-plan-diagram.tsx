"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { TrainFront } from "lucide-react";
import type { RegulationLine, RegulationStop } from "@/lib/regulation-mock-data";
import {
  delayColor,
  formatDelayLabel,
  formatDelayMinutes,
  segmentColor,
} from "@/lib/regulation-mock-data";
import {
  nodesForVariant,
  fitTopologyColumnWidth,
  topologyMinWidth,
  vehicleLayoutPosition,
  type LineTopology,
  type LineVariant,
} from "@/lib/line-topology";

interface LinePlanDiagramProps {
  topology: LineTopology;
  line: RegulationLine;
  activeVariantId: string;
  stopColumnPx?: number;
  embedded?: boolean;
  vehicles: RegulationLine["vehicles"];
  vehicleVariants: Map<string, string>;
  isLive: boolean;
  onVariantChange?: (variantId: string) => void;
}

function segmentQualityForEdge(
  line: RegulationLine,
  fromCol: number,
  toCol: number,
): "on-time" | "light-delay" | "major-delay" {
  const idx = Math.min(fromCol, line.segmentQuality.length - 1);
  return line.segmentQuality[idx] ?? "on-time";
}

export function LinePlanDiagram({
  topology,
  line,
  activeVariantId,
  stopColumnPx: preferredStopColumnPx = 72,
  embedded = false,
  vehicles,
  vehicleVariants,
  isLive,
  onVariantChange,
}: LinePlanDiagramProps) {
  const { nodes, edges, variants, columnCount, laneCount } = topology;
  const scrollRef = useRef<HTMLDivElement>(null);
  const [availableWidth, setAvailableWidth] = useState(0);

  useEffect(() => {
    const element = scrollRef.current;
    if (!element) return;

    const updateWidth = () => setAvailableWidth(element.clientWidth);
    updateWidth();

    const observer = new ResizeObserver(updateWidth);
    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  const stopColumnPx = useMemo(() => {
    if (embedded || availableWidth === 0) return preferredStopColumnPx;
    return fitTopologyColumnWidth(
      columnCount,
      availableWidth,
      preferredStopColumnPx,
    );
  }, [availableWidth, columnCount, embedded, preferredStopColumnPx]);
  const minWidth = topologyMinWidth(columnCount, stopColumnPx);
  const compact = stopColumnPx < 60;
  const laneHeight = embedded ? 88 : 96;
  const trackHeight = laneCount * laneHeight;
  const activeNodes = useMemo(
    () => nodesForVariant(topology, activeVariantId),
    [topology, activeVariantId],
  );

  const activeVariant = variants.find((v) => v.id === activeVariantId) ?? variants[0];

  const stopsByKey = useMemo(() => {
    const map = new Map<string, RegulationStop>();
    for (const stop of line.stops) {
      if (stop.stopId) map.set(stop.stopId, stop);
    }
    return map;
  }, [line.stops]);

  const nodeStops = useMemo(() => {
    return nodes.map((node) => {
      const reg = stopsByKey.get(node.stopId);
      return {
        ...node,
        unavailable: reg?.unavailable ?? false,
        theoreticalTime: reg?.theoreticalTime ?? node.theoreticalTime,
        stationId: reg?.stationId ?? node.stationId,
      };
    });
  }, [nodes, stopsByKey]);

  return (
    <div className={`line-plan-diagram${embedded ? " line-plan-diagram--embedded" : ""}${compact ? " line-plan-diagram--compact" : ""}`}>
      {!embedded && variants.length > 1 && (
        <div className="line-plan-variant-tabs" role="tablist" aria-label="Variantes de la ligne">
          {variants.map((variant) => (
            <button
              key={variant.id}
              type="button"
              role="tab"
              aria-selected={variant.id === activeVariantId}
              className={`line-plan-variant-tab${variant.id === activeVariantId ? " active" : ""}${variant.kind === "partial" ? " partial" : ""}${variant.kind === "branch" ? " branch" : ""}`}
              onClick={() => onVariantChange?.(variant.id)}
              title={variant.label}
            >
              <span className="line-plan-variant-tab-label">{variant.label}</span>
              {variant.kind === "partial" && (
                <span className="line-plan-variant-tab-badge">Partiel</span>
              )}
              {variant.kind === "branch" && (
                <span className="line-plan-variant-tab-badge">Branche</span>
              )}
            </button>
          ))}
        </div>
      )}

      <div ref={scrollRef} className="line-plan-diagram-scroll">
        <div className="line-plan-diagram-inner" style={{ minWidth, width: minWidth }}>
          {/* Labels par voie */}
          {Array.from({ length: laneCount }, (_, lane) => {
            const laneNodes = nodeStops.filter((n) => n.lane === lane);
            if (laneNodes.length === 0) return null;

            return (
              <div
                key={`labels-${lane}`}
                className="line-plan-lane-labels"
                style={{
                  gridTemplateColumns: `72px repeat(${columnCount}, ${stopColumnPx}px)`,
                }}
              >
                <div className="regulation-sticky-col" />
                {Array.from({ length: columnCount }, (_, col) => {
                  const node = laneNodes.find((n) => n.column === col);
                  if (!node) {
                    return <div key={`empty-${lane}-${col}`} className="line-plan-empty-cell" />;
                  }

                  const isActive = activeNodes.has(node.id);

                  return (
                    <div
                      key={node.id}
                      className={`regulation-stop-label line-plan-stop-label${node.unavailable ? " unavailable" : ""}${!isActive ? " dimmed" : ""}`}
                      style={{ maxWidth: stopColumnPx, minWidth: stopColumnPx }}
                    >
                      {node.stationId ? (
                        <Link
                          href={`/stations/${node.stationId}`}
                          className="regulation-stop-name regulation-stop-name-link text-[11px] font-medium leading-tight"
                          title={node.name}
                        >
                          {node.name}
                        </Link>
                      ) : (
                        <span
                          className="regulation-stop-name text-[11px] font-medium leading-tight text-white"
                          title={node.name}
                        >
                          {node.name}
                        </span>
                      )}
                      {node.role === "terminus" && (
                        <span className="text-[9px] uppercase tracking-wide text-[#94A3B8]">
                          Terminus
                        </span>
                      )}
                      {node.role === "hub" && (
                        <span className="line-plan-hub-badge">Bifurcation</span>
                      )}
                      {!embedded && (
                        <span className="text-[10px] text-[#64748B]">{node.theoreticalTime}</span>
                      )}
                    </div>
                  );
                })}
              </div>
            );
          })}

          {/* Piste avec segments et nœuds */}
          <div
            className="line-plan-track"
            style={{
              height: trackHeight,
              width: columnCount * stopColumnPx,
              minWidth: columnCount * stopColumnPx,
            }}
          >
            <div className="regulation-sticky-col line-plan-track-sticky" />

            <svg
              className="line-plan-edges"
              width={columnCount * stopColumnPx}
              height={trackHeight}
              aria-hidden
            >
              {edges.map((edge) => {
                const x1 = edge.fromColumn * stopColumnPx + stopColumnPx / 2;
                const y1 = edge.fromLane * laneHeight + laneHeight / 2;
                const x2 = edge.toColumn * stopColumnPx + stopColumnPx / 2;
                const y2 = edge.toLane * laneHeight + laneHeight / 2;
                const quality = segmentQualityForEdge(line, edge.fromColumn, edge.toColumn);
                const color = segmentColor(quality);
                const isActive = edge.variantIds.includes(activeVariantId);

                if (edge.fromLane === edge.toLane) {
                  return (
                    <line
                      key={`${edge.fromId}-${edge.toId}`}
                      x1={x1}
                      y1={y1}
                      x2={x2}
                      y2={y2}
                      stroke={color}
                      strokeWidth={3}
                      strokeLinecap="round"
                      opacity={isActive ? 1 : 0.28}
                    />
                  );
                }

                const midX = x1 + (x2 - x1) * 0.45;
                return (
                  <path
                    key={`${edge.fromId}-${edge.toId}`}
                    d={`M ${x1} ${y1} L ${midX} ${y1} L ${midX} ${y2} L ${x2} ${y2}`}
                    fill="none"
                    stroke={color}
                    strokeWidth={3}
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    opacity={isActive ? 1 : 0.28}
                  />
                );
              })}
            </svg>

            {nodeStops.map((node) => {
              const isActive = activeNodes.has(node.id);
              return (
                <div
                  key={node.id}
                  className={`line-plan-node-wrap${isActive ? "" : " inactive"}`}
                  style={{
                    left: node.column * stopColumnPx + stopColumnPx / 2,
                    top: node.lane * laneHeight + laneHeight / 2,
                  }}
                >
                  <div
                    className={[
                      "regulation-stop-node",
                      node.role === "terminus" ? "terminus" : "",
                      node.role === "hub" ? "hub" : "",
                      node.unavailable ? "unavailable" : "",
                    ]
                      .filter(Boolean)
                      .join(" ")}
                  />
                </div>
              );
            })}

            {vehicles.map((vehicle) => {
              const variantId = vehicleVariants.get(vehicle.id) ?? activeVariantId;
              const variant = variants.find((v) => v.id === variantId) ?? activeVariant;
              const pos = vehicleLayoutPosition(
                topology,
                variant,
                vehicle.segmentIndex,
                vehicle.segmentProgress,
              );
              if (!pos) return null;

              const left = pos.column * stopColumnPx + stopColumnPx / 2;
              const top = pos.lane * laneHeight + laneHeight / 2 - 40;

              return (
                <div
                  key={vehicle.id}
                  className="regulation-line-vehicle line-plan-vehicle"
                  style={{ left, top }}
                  aria-label={`Véhicule ${vehicle.service}`}
                >
                  <div className="regulation-line-vehicle-info">
                    <span className="regulation-line-vehicle-service">{vehicle.service}</span>
                    <span
                      className="regulation-line-vehicle-delay"
                      style={{ color: delayColor(vehicle.currentDelay) }}
                    >
                      {embedded
                        ? formatDelayLabel(vehicle.currentDelay)
                        : formatDelayMinutes(vehicle.currentDelay)}
                    </span>
                  </div>
                  <div className="regulation-tram-marker">
                    <TrainFront className="h-4 w-4 text-white" strokeWidth={1.5} />
                  </div>
                </div>
              );
            })}
          </div>

          {!embedded && topology.isComplex && (
            <p className="line-plan-topology-hint">
              Toutes les branches restent visibles · parcours sélectionné vers{" "}
              {activeVariant.destination}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}

export function variantTabsSummary(variants: LineVariant[]): string {
  const branches = variants.filter((variant) => variant.kind === "branch").length;
  const partials = variants.filter((variant) => variant.kind === "partial").length;
  const details = [`${variants.length} parcours`];
  if (branches > 0) details.push(`${branches} branche${branches > 1 ? "s" : ""}`);
  if (partials > 0) details.push(`${partials} partiel${partials > 1 ? "s" : ""}`);
  return details.join(" · ");
}
