#!/usr/bin/env python3
"""Complète les tracés de assets/data/tan_routes.json avec les branches
manquantes issues des variantes GTFS de supabase/seed_tan.sql.

Les tracés embarqués (denses, ~60 m entre points) ne couvrent qu'une
variante aller/retour par ligne : les branches (ex. tram 1 vers Jamet ou
Babinière, ligne NC vers Chantrerie) n'apparaissent ni sur la carte ni
dans le graphe de routage hors-ligne. Ce script extrait des variantes
GTFS les portions situées à plus de FAR_M de la géométrie existante et
les ajoute comme segments supplémentaires (points GTFS plus espacés que
la source d'origine, mais réseau complet).

Usage : python3 tool/merge_gtfs_branches.py
"""
import json
import math
import re
from collections import defaultdict
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
ROUTES_PATH = PROJECT / 'assets/data/tan_routes.json'
SEED_PATH = PROJECT / 'supabase/seed_tan.sql'

# Distance au-delà de laquelle un point GTFS est considéré hors de la
# géométrie déjà couverte. Légèrement sous le rayon de rattachement
# arrêt <-> tracé du graphe (130 m, gtfs_service.dart).
FAR_M = 120
# Longueur minimale d'une portion manquante pour être ajoutée (évite les
# micro-écarts de boucles de terminus).
MIN_RUN_M = 250

SHAPE_RE = re.compile(
    r"\('([^']+)',(\d+),ST_SetSRID\(ST_Point\((-?[0-9.]+), (-?[0-9.]+)\), 4326\)\)"
)


def dist(a, b):
    """Distance approchée en mètres (équirectangulaire, suffisant à Nantes)."""
    lat = math.radians((a[0] + b[0]) / 2)
    dx = (b[1] - a[1]) * 111320 * math.cos(lat)
    dy = (b[0] - a[0]) * 110540
    return math.hypot(dx, dy)


def length(pts):
    return sum(dist(pts[i - 1], pts[i]) for i in range(1, len(pts)))


class Coverage:
    """Index spatial (grille ~110 m) des points déjà couverts d'une ligne."""

    CELL = 0.001

    def __init__(self):
        self.grid = defaultdict(list)

    def add(self, pt):
        self.grid[(int(pt[0] // self.CELL), int(pt[1] // self.CELL))].append(pt)

    def near(self, pt, radius):
        gx, gy = int(pt[0] // self.CELL), int(pt[1] // self.CELL)
        reach = int(radius / 110) + 1
        for dx in range(-reach, reach + 1):
            for dy in range(-reach, reach + 1):
                for other in self.grid.get((gx + dx, gy + dy), ()):
                    if dist(pt, other) <= radius:
                        return True
        return False


def main():
    routes = json.loads(ROUTES_PATH.read_text(encoding='utf-8'))

    # Variantes GTFS : shape_id ("ROUTE-n") -> points ordonnés [lat, lon].
    variants = defaultdict(list)
    for sid, seq, lon, lat in SHAPE_RE.findall(SEED_PATH.read_text(encoding='utf-8')):
        variants[sid].append((int(seq), float(lat), float(lon)))
    by_route = defaultdict(list)
    for sid, pts in variants.items():
        rid, n = sid.rsplit('-', 1)
        pts.sort()
        by_route[rid].append((int(n), [(la, lo) for _, la, lo in pts]))
    for sids in by_route.values():
        sids.sort()  # les variantes les plus utilisées d'abord (cf. update_tan_data)

    added_total = 0
    for route in routes:
        segments = route.get('g') or []
        coverage = Coverage()
        for seg in segments:
            for pt in seg:
                coverage.add(tuple(pt))

        added = []
        for _, pts in by_route.get(route['i'], ()):
            far = [not coverage.near(p, FAR_M) for p in pts]
            i = 0
            while i < len(pts):
                if not far[i]:
                    i += 1
                    continue
                j = i
                while j + 1 < len(pts) and far[j + 1]:
                    j += 1
                # Étend d'un point de chaque côté pour raccorder au tronc.
                run = pts[max(0, i - 1):min(len(pts), j + 2)]
                if len(run) >= 2 and length(run) >= MIN_RUN_M:
                    added.append(run)
                    for p in run:
                        coverage.add(p)
                i = j + 1

        if added:
            segments.extend([[round(la, 5), round(lo, 5)] for la, lo in run]
                            for run in added)
            route['g'] = segments
            added_total += len(added)
            print(f"ligne {route['s']:>4} ({route['t']}): "
                  f"{len(added)} branche(s) ajoutée(s), "
                  f"{sum(len(r) for r in added)} points")

    if not added_total:
        print('Aucune branche manquante.')
        return
    ROUTES_PATH.write_text(
        json.dumps(routes, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8',
    )
    print(f'{added_total} segment(s) ajouté(s) -> {ROUTES_PATH.name}')


if __name__ == '__main__':
    main()
