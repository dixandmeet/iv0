import type maplibregl from "maplibre-gl";

type MapLibreAjaxError = Error & { status?: number };

/** Requêtes annulées (zoom, démontage React, Strict Mode) — bruit attendu, pas une panne réseau. */
export function isBenignMapLibreError(error: unknown): boolean {
  if (!(error instanceof Error)) return false;

  const status = (error as MapLibreAjaxError).status;
  if (status === 0) return true;

  const message = error.message;
  return (
    message.includes("Failed to fetch (0)") ||
    /\(0\):\s*https?:\/\//.test(message)
  );
}

export function attachMapLibreErrorHandler(
  map: maplibregl.Map,
  label = "MapLibre",
): () => void {
  const onError = (event: maplibregl.ErrorEvent) => {
    if (isBenignMapLibreError(event.error)) return;
    console.error(`[${label}]`, event.error);
  };

  map.on("error", onError);
  return () => map.off("error", onError);
}
