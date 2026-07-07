export type LatLng = [number, number];

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
