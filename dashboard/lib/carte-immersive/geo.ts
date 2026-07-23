export type LatLng = [number, number];

const EARTH_RADIUS_METERS = 6_371_000;

/** Distance à vol d'oiseau entre deux coordonnées GPS, en mètres. */
export function distanceMeters(from: LatLng, to: LatLng): number {
  const toRadians = (degrees: number) => (degrees * Math.PI) / 180;
  const fromLat = toRadians(from[0]);
  const toLat = toRadians(to[0]);
  const deltaLat = toRadians(to[0] - from[0]);
  const deltaLng = toRadians(to[1] - from[1]);
  const haversine =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(fromLat) * Math.cos(toLat) * Math.sin(deltaLng / 2) ** 2;

  return 2 * EARTH_RADIUS_METERS * Math.asin(Math.sqrt(haversine));
}

export function pathLen(pts: LatLng[]): number {
  let total = 0;
  for (let i = 1; i < pts.length; i++) {
    total += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
  }
  return total;
}

export function pointAt(pts: LatLng[], dist: number): { lat: number; lng: number } {
  let remaining = dist;
  for (let i = 1; i < pts.length; i++) {
    const [x1, y1] = pts[i - 1];
    const [x2, y2] = pts[i];
    const seg = Math.hypot(x2 - x1, y2 - y1);
    if (remaining <= seg || i === pts.length - 1) {
      const t = seg === 0 ? 0 : remaining / seg;
      return { lat: x1 + (x2 - x1) * t, lng: y1 + (y2 - y1) * t };
    }
    remaining -= seg;
  }
  const last = pts[pts.length - 1];
  return { lat: last[0], lng: last[1] };
}
