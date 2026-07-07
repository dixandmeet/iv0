"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type {
  ImmersiveFleetResponse,
  MapVehicle,
  VehicleFeedMode,
} from "@/lib/carte-immersive/vehicles";

const POLL_INTERVAL_MS = 5_000;
const LIVE_HOLD_AFTER_ERROR_MS = 30_000;

export function useImmersiveFleet() {
  const [vehicles, setVehicles] = useState<MapVehicle[]>([]);
  const [mode, setMode] = useState<VehicleFeedMode>("preview");
  const [stale, setStale] = useState(false);
  const lastLiveAtRef = useRef(0);
  const vehiclesRef = useRef<MapVehicle[]>([]);

  useEffect(() => {
    vehiclesRef.current = vehicles;
  }, [vehicles]);

  const load = useCallback(async (signal?: AbortSignal) => {
    try {
      const response = await fetch("/api/carte-immersive/vehicles", {
        cache: "no-store",
        signal,
      });
      if (!response.ok) throw new Error("live fleet unavailable");

      const payload = (await response.json()) as ImmersiveFleetResponse;
      const live = Array.isArray(payload.vehicles)
        ? payload.vehicles.filter((vehicle) => vehicle.mode === "live")
        : [];

      if (live.length > 0) {
        lastLiveAtRef.current = Date.now();
        setVehicles(live);
        setMode("live");
        setStale(false);
        return;
      }

      setVehicles([]);
      setMode("preview");
      setStale(false);
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") return;

      const canHoldLastSnapshot =
        vehiclesRef.current.length > 0 &&
        Date.now() - lastLiveAtRef.current < LIVE_HOLD_AFTER_ERROR_MS;
      if (canHoldLastSnapshot) {
        setMode("live");
        setStale(true);
      } else {
        setVehicles([]);
        setMode("preview");
        setStale(false);
      }
    }
  }, []);

  useEffect(() => {
    let activeController: AbortController | null = null;

    const poll = () => {
      activeController?.abort();
      activeController = new AbortController();
      void load(activeController.signal);
    };

    poll();
    const interval = window.setInterval(poll, POLL_INTERVAL_MS);
    return () => {
      window.clearInterval(interval);
      activeController?.abort();
    };
  }, [load]);

  return { vehicles, mode, stale };
}
