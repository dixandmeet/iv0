type GeoJsonPoint = {
  type?: string;
  coordinates?: unknown;
};

/** Extrait [lng, lat] depuis un champ geom Supabase/PostGIS (GeoJSON ou string). */
export function pointCoordinates(geom: unknown): [number, number] | null {
  if (!geom) return null;

  let value: GeoJsonPoint = geom as GeoJsonPoint;

  if (typeof geom === "string") {
    try {
      value = JSON.parse(geom) as GeoJsonPoint;
    } catch {
      return null;
    }
  }

  const coords = value.coordinates;
  if (!Array.isArray(coords) || coords.length < 2) return null;

  const lng = Number(coords[0]);
  const lat = Number(coords[1]);
  if (!Number.isFinite(lng) || !Number.isFinite(lat)) return null;

  return [lng, lat];
}

/** Extrait les points [lng, lat] d'une LineString PostGIS renvoyée par Supabase. */
export function lineStringCoordinates(geom: unknown): [number, number][] {
  if (!geom) return [];

  let value: GeoJsonPoint = geom as GeoJsonPoint;
  if (typeof geom === "string") {
    try {
      value = JSON.parse(geom) as GeoJsonPoint;
    } catch {
      return [];
    }
  }

  if (value.type !== "LineString" || !Array.isArray(value.coordinates)) return [];
  return value.coordinates.flatMap((coordinate) => {
    if (!Array.isArray(coordinate) || coordinate.length < 2) return [];
    const lng = Number(coordinate[0]);
    const lat = Number(coordinate[1]);
    return Number.isFinite(lng) && Number.isFinite(lat)
      ? ([[lng, lat]] as [number, number][])
      : [];
  });
}
