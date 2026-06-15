#!/usr/bin/env python3
"""OBSOLÈTE — remplacé par tool/fetch_osm_shapes.py (tracés fins issus d'OSM).
Conservé pour référence uniquement ; ne plus exécuter (écraserait les tracés
OSM par des interpolations grossières du GTFS).

Reconstruit les tracés (`g`) de assets/data/tan_routes.json.

Chaque segment = une variante GTFS de supabase/seed_tan.sql (déjà ordonnée
via shape_pt_sequence), dédupliquée par couple de terminus (arrêt le plus
proche du début / de la fin), puis densifiée par interpolation linéaire.

Les anciennes polylignes « fourre-tout » (tronc + branches + deux sens
mélangés) produisaient des zigzags à l'affichage ; l'approche par variantes
séparées garantit un tracé continu par direction.

Usage : python3 tool/rebuild_tan_shapes.py
"""
import json
import math
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
ROUTES_PATH = PROJECT / 'assets/data/tan_routes.json'
STOPS_PATH = PROJECT / 'assets/data/tan_stops.json'
SEED_PATH = PROJECT / 'supabase/seed_tan.sql'

# Espacement cible entre points (m). Sous le rayon de rattachement arrêt
# <-> tracé du graphe (130 m, gtfs_service.dart).
STEP_M = 55
# Distance max pour associer une extrémité de tracé à un arrêt (nom).
STOP_SNAP_M = 250

SHAPE_RE = re.compile(
    r"\('([^']+)',(\d+),ST_SetSRID\(ST_Point\((-?[0-9.]+), (-?[0-9.]+)\), 4326\)\)"
)


def dist(a, b):
    lat = math.radians((a[0] + b[0]) / 2)
    dx = (b[1] - a[1]) * 111320 * math.cos(lat)
    dy = (b[0] - a[0]) * 110540
    return math.hypot(dx, dy)


def length(pts):
    return sum(dist(pts[i - 1], pts[i]) for i in range(1, len(pts)))


def normalize_name(name):
    s = unicodedata.normalize('NFD', name.lower())
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    s = re.sub(r'\s*-\s*', '-', s)
    return re.sub(r'\s+', ' ', s).strip()


def load_stops():
    stops = json.loads(STOPS_PATH.read_text(encoding='utf-8'))
    return [(s['n'], float(s['la']), float(s['lo'])) for s in stops]


def nearest_stop_name(pt, stops):
    best, best_d = None, float('inf')
    for name, la, lo in stops:
        d = dist(pt, (la, lo))
        if d < best_d:
            best_d, best = d, name
    if best_d > STOP_SNAP_M:
        return None
    return normalize_name(best)


def interpolate(pts, step):
    """Points le long de la polyligne GTFS, espacés d'environ step mètres."""
    if len(pts) < 2:
        return pts
    out = [pts[0]]
    carry = 0.0
    for i in range(1, len(pts)):
        seg_len = dist(pts[i - 1], pts[i])
        if seg_len == 0:
            continue
        pos = carry
        while pos + step <= seg_len:
            pos += step
            t = pos / seg_len
            out.append((
                pts[i - 1][0] + (pts[i][0] - pts[i - 1][0]) * t,
                pts[i - 1][1] + (pts[i][1] - pts[i - 1][1]) * t,
            ))
        carry = seg_len - pos
        out.append(pts[i])
    # Déduplication des quasi-doublons.
    deduped = [out[0]]
    for p in out[1:]:
        if dist(deduped[-1], p) >= 8:
            deduped.append(p)
    return deduped


def dedupe_variants(variants, stops):
    """Une variante par couple (terminus départ, terminus arrivée), la plus longue."""
    best = {}
    for pts in variants:
        if len(pts) < 2:
            continue
        start = nearest_stop_name(pts[0], stops)
        end = nearest_stop_name(pts[-1], stops)
        if start is None or end is None:
            continue
        key = (start, end)
        if key not in best or length(pts) > length(best[key]):
            best[key] = pts
    return list(best.values())


def main():
    stops = load_stops()
    routes = json.loads(ROUTES_PATH.read_text(encoding='utf-8'))

    raw = defaultdict(list)
    for sid, seq, lon, lat in SHAPE_RE.findall(
            SEED_PATH.read_text(encoding='utf-8')):
        raw[sid].append((int(seq), float(lat), float(lon)))

    by_route = defaultdict(list)
    for sid, pts in raw.items():
        rid, _n = sid.rsplit('-', 1)
        pts.sort()
        ordered = [(la, lo) for _, la, lo in pts]
        if len(ordered) >= 2:
            by_route[rid].append(ordered)

    rebuilt = 0
    for route in routes:
        variants = by_route.get(route['i'], [])
        if not variants:
            continue
        segments = dedupe_variants(variants, stops)
        if not segments:
            continue
        route['g'] = [
            [[round(la, 5), round(lo, 5)] for la, lo in interpolate(seg, STEP_M)]
            for seg in segments
        ]
        rebuilt += 1
        npts = sum(len(s) for s in route['g'])
        print(f"ligne {route['s']:>4} ({route['t']:>7}): "
              f"{len(route['g'])} segment(s), {npts} points")

    ROUTES_PATH.write_text(
        json.dumps(routes, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8',
    )
    print(f'{rebuilt} ligne(s) reconstruite(s) -> {ROUTES_PATH.name}')


if __name__ == '__main__':
    main()
