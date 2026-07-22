"use client";

import { useEffect, useMemo, useState } from "react";
import {
  fetchRegisteredStopsFromDatabase,
  mergeRegisteredStops,
  registeredStopsFromPoints,
  type RegisteredStop,
} from "@/lib/registered-stops";
import type { RoutePoint } from "@/lib/line-editor-types";
import { useNetwork } from "@/components/network/network-provider";

const cachedCatalog = new Map<string, RegisteredStop[]>();
const catalogPromises = new Map<string, Promise<RegisteredStop[]>>();

async function loadCatalog(networkId: string): Promise<RegisteredStop[]> {
  const cached = cachedCatalog.get(networkId);
  if (cached) return cached;
  if (!catalogPromises.has(networkId)) {
    catalogPromises.set(networkId, fetchRegisteredStopsFromDatabase(networkId)
      .then((databaseStops) => {
        cachedCatalog.set(networkId, databaseStops);
        return databaseStops;
      })
      .catch(() => {
        cachedCatalog.set(networkId, []);
        return [];
      }));
  }
  return catalogPromises.get(networkId)!;
}

export function refreshRegisteredStopsCatalog(): void {
  cachedCatalog.clear();
  catalogPromises.clear();
}

export function useRegisteredStopsCatalog(extraPoints: RoutePoint[] = []) {
  const { network } = useNetwork();
  const [catalog, setCatalog] = useState<RegisteredStop[]>(cachedCatalog.get(network.id) ?? []);
  const [loading, setLoading] = useState(!cachedCatalog.has(network.id));

  useEffect(() => {
    let cancelled = false;

    loadCatalog(network.id).then((loaded) => {
      if (cancelled) return;
      setCatalog(loaded);
      setLoading(false);
    });

    return () => {
      cancelled = true;
    };
  }, [network.id]);

  const mergedCatalog = useMemo(() => {
    const extraStops = registeredStopsFromPoints(extraPoints);
    if (extraStops.length === 0) return catalog;
    return mergeRegisteredStops(catalog, extraStops);
  }, [catalog, extraPoints]);

  return { catalog: mergedCatalog, loading };
}
