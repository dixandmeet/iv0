"use client";

import { useEffect, useRef, useState } from "react";
import type { LiveFleetPosition } from "@/lib/types";
import type { RegulationVehicle } from "@/lib/regulation-mock-data";
import { buildDemoVehicles } from "@/lib/regulation-data";
import {
  buildVehiclesFromFleet,
  computeRouteLengthMeters,
  DEMO_VEHICLE_SPEED_MS,
  lineProgressFromSegment,
  regulationVehicleFromLineProgress,
} from "@/lib/regulation-fleet-tracking";
import type { RouteTimelinePoint } from "@/lib/regulation-data";

interface AnimState {
  fleetId: string;
  lineProgress: number;
  targetProgress: number;
  speedMs: number;
  currentDelay: number;
  targetDelay: number;
  service: string;
  stopCount: number;
}

const FOLLOW_RATE = 5;
const DEMO_SPEED_MS = DEMO_VEHICLE_SPEED_MS;

function fleetSpeedMs(speedKmh: number | null | undefined): number {
  if (speedKmh == null || speedKmh <= 0) return 0;
  return speedKmh / 3.6;
}

export function useLineFleetTracking(
  fleet: LiveFleetPosition[],
  timelineStops: RouteTimelinePoint[],
  lineShortName: string,
  stopCount: number,
  focusVehicleId?: string | null,
): { vehicles: RegulationVehicle[]; isLive: boolean } {
  const animRef = useRef<Map<string, AnimState>>(new Map());
  const demoRef = useRef<Map<string, AnimState>>(new Map());
  const routeLengthRef = useRef(1);
  const [vehicles, setVehicles] = useState<RegulationVehicle[]>([]);
  const [isLive, setIsLive] = useState(false);

  useEffect(() => {
    routeLengthRef.current = computeRouteLengthMeters(timelineStops);
  }, [timelineStops]);

  useEffect(() => {
    if (fleet.length === 0 || timelineStops.length < 2 || stopCount < 2) {
      animRef.current.clear();
      setIsLive(false);
      return;
    }

    setIsLive(true);
    const built = buildVehiclesFromFleet(fleet, timelineStops, lineShortName);
    const seen = new Set<string>();

    for (const vehicle of built) {
      seen.add(vehicle.id);
      const fleetVehicle = fleet.find((v) => v.id === vehicle.id);
      const targetProgress = lineProgressFromSegment(
        vehicle.segmentIndex,
        vehicle.segmentProgress,
        stopCount,
      );
      const speedMs = fleetSpeedMs(fleetVehicle?.speed);

      const existing = animRef.current.get(vehicle.id);
      if (existing) {
        existing.targetProgress = targetProgress;
        existing.targetDelay = vehicle.currentDelay;
        existing.speedMs = speedMs;
        existing.service = vehicle.service;
        existing.stopCount = stopCount;
      } else {
        animRef.current.set(vehicle.id, {
          fleetId: vehicle.id,
          lineProgress: targetProgress,
          targetProgress,
          speedMs,
          currentDelay: vehicle.currentDelay,
          targetDelay: vehicle.currentDelay,
          service: vehicle.service,
          stopCount,
        });
      }
    }

    for (const id of animRef.current.keys()) {
      if (!seen.has(id)) animRef.current.delete(id);
    }
  }, [fleet, timelineStops, lineShortName, stopCount]);

  useEffect(() => {
    if (stopCount < 2) {
      setVehicles([]);
      return;
    }

    let raf = 0;
    let lastTs = performance.now();

    const tick = (ts: number) => {
      const dt = Math.min((ts - lastTs) / 1000, 0.12);
      lastTs = ts;
      const routeLength = routeLengthRef.current;
      const next: RegulationVehicle[] = [];

      if (animRef.current.size > 0) {
        animRef.current.forEach((state) => {
          if (state.speedMs > 0.3) {
            state.targetProgress = Math.min(
              1,
              state.targetProgress + (state.speedMs * dt) / routeLength,
            );
          }

          state.lineProgress +=
            (state.targetProgress - state.lineProgress) *
            Math.min(1, FOLLOW_RATE * dt);
          state.currentDelay +=
            (state.targetDelay - state.currentDelay) *
            Math.min(1, FOLLOW_RATE * dt);

          next.push(regulationVehicleFromLineProgress(state));
        });
      } else {
        if (demoRef.current.size === 0) {
          const demo = buildDemoVehicles(stopCount, lineShortName).filter(
            (vehicle) => !focusVehicleId || vehicle.id === focusVehicleId,
          );
          for (const vehicle of demo) {
            demoRef.current.set(vehicle.id, {
              fleetId: vehicle.id,
              lineProgress: lineProgressFromSegment(
                vehicle.segmentIndex,
                vehicle.segmentProgress,
                stopCount,
              ),
              targetProgress: lineProgressFromSegment(
                vehicle.segmentIndex,
                vehicle.segmentProgress,
                stopCount,
              ),
              speedMs: DEMO_SPEED_MS,
              currentDelay: vehicle.currentDelay,
              targetDelay: vehicle.currentDelay,
              service: vehicle.service,
              stopCount,
            });
          }
        }

        demoRef.current.forEach((state) => {
          state.targetProgress = Math.min(
            1,
            state.targetProgress + (DEMO_SPEED_MS * dt) / routeLength,
          );
          if (state.targetProgress >= 1) {
            state.targetProgress = 0;
            state.lineProgress = 0;
          }

          state.lineProgress +=
            (state.targetProgress - state.lineProgress) *
            Math.min(1, FOLLOW_RATE * dt);

          next.push(regulationVehicleFromLineProgress(state));
        });
      }

      next.sort((a, b) => a.service.localeCompare(b.service, "fr", { numeric: true }));
      setVehicles(next);
      raf = requestAnimationFrame(tick);
    };

    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [stopCount, lineShortName, fleet.length, focusVehicleId]);

  useEffect(() => {
    if (fleet.length > 0) demoRef.current.clear();
  }, [fleet.length]);

  useEffect(() => {
    demoRef.current.clear();
  }, [lineShortName, stopCount, focusVehicleId]);

  return { vehicles, isLive };
}
