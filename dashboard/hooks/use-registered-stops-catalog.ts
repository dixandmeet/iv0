"use client";

import { useEffect, useMemo, useState } from "react";
import { registeredStopsFromEditorDrafts } from "@/lib/line-editor-persistence";
import {
  fetchRegisteredStopsFromDatabase,
  mergeRegisteredStops,
  registeredStopsFromPoints,
  type RegisteredStop,
} from "@/lib/registered-stops";
import type { RoutePoint } from "@/lib/line-editor-types";

let cachedCatalog: RegisteredStop[] | null = null;
let catalogPromise: Promise<RegisteredStop[]> | null = null;

async function loadCatalog(): Promise<RegisteredStop[]> {
  if (cachedCatalog) return cachedCatalog;
  if (!catalogPromise) {
    catalogPromise = fetchRegisteredStopsFromDatabase()
      .then((databaseStops) => {
        const draftStops = registeredStopsFromEditorDrafts();
        cachedCatalog = mergeRegisteredStops(databaseStops, draftStops);
        return cachedCatalog;
      })
      .catch(() => {
        const draftStops = registeredStopsFromEditorDrafts();
        cachedCatalog = draftStops;
        return cachedCatalog;
      });
  }
  return catalogPromise;
}

export function refreshRegisteredStopsCatalog(): void {
  cachedCatalog = null;
  catalogPromise = null;
}

export function useRegisteredStopsCatalog(extraPoints: RoutePoint[] = []) {
  const [catalog, setCatalog] = useState<RegisteredStop[]>(cachedCatalog ?? []);
  const [loading, setLoading] = useState(!cachedCatalog);

  useEffect(() => {
    let cancelled = false;

    loadCatalog().then((loaded) => {
      if (cancelled) return;
      setCatalog(loaded);
      setLoading(false);
    });

    return () => {
      cancelled = true;
    };
  }, []);

  const mergedCatalog = useMemo(() => {
    const extraStops = registeredStopsFromPoints(extraPoints);
    if (extraStops.length === 0) return catalog;
    return mergeRegisteredStops(catalog, extraStops);
  }, [catalog, extraPoints]);

  return { catalog: mergedCatalog, loading };
}
