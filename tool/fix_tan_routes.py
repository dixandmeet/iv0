#!/usr/bin/env python3
"""OBSOLÈTE — remplacé par tool/fetch_osm_shapes.py (tracés fins issus d'OSM,
déjà correctement ordonnés). Conservé pour référence uniquement.

Répare l'ordre des points des tracés de assets/data/tan_routes.json.

Certains segments ont des points mal ordonnés (zigzags : la polyline fait
des allers-retours de plusieurs centaines de mètres), ce qui casse le rendu
des itinéraires sur la carte. Ce script réordonne les points de chaque
segment (plus proche voisin + amélioration 2-opt) et ne remplace l'ordre
d'origine que si la longueur totale du tracé diminue nettement (> 5 %),
afin de ne jamais dégrader un segment déjà sain (boucles de terminus, etc.).

Usage : python3 tool/fix_tan_routes.py
"""
import json
import math
from pathlib import Path

ROUTES_PATH = Path(__file__).resolve().parent.parent / 'assets/data/tan_routes.json'
# Gain minimal de longueur pour accepter le réordonnancement.
MIN_GAIN = 0.05


def dist(a, b):
    """Distance approchée en mètres (équirectangulaire, suffisant à Nantes)."""
    lat = math.radians((a[0] + b[0]) / 2)
    dx = (b[1] - a[1]) * 111320 * math.cos(lat)
    dy = (b[0] - a[0]) * 110540
    return math.hypot(dx, dy)


def total_length(pts):
    return sum(dist(pts[i - 1], pts[i]) for i in range(1, len(pts)))


def nearest_neighbor(pts, start_index):
    remaining = list(range(len(pts)))
    order = [remaining.pop(start_index)]
    while remaining:
        last = pts[order[-1]]
        k = min(range(len(remaining)), key=lambda j: dist(last, pts[remaining[j]]))
        order.append(remaining.pop(k))
    return [pts[i] for i in order]


def two_opt(pts):
    """Amélioration 2-opt d'un chemin ouvert, jusqu'à stabilité."""
    pts = pts[:]
    n = len(pts)
    improved = True
    while improved:
        improved = False
        for i in range(n - 2):
            a, b = pts[i], pts[i + 1]
            d_ab = dist(a, b)
            for j in range(i + 2, n - 1):
                c, d = pts[j], pts[j + 1]
                # Remplace (a-b ... c-d) par (a-c ... b-d) si plus court.
                if dist(a, c) + dist(b, d) < d_ab + dist(c, d) - 1e-9:
                    pts[i + 1:j + 1] = reversed(pts[i + 1:j + 1])
                    improved = True
                    a, b = pts[i], pts[i + 1]
                    d_ab = dist(a, b)
    return pts


def repair_segment(seg):
    """Retourne (segment réparé, gain relatif) ou (seg, 0) si rien à faire."""
    if len(seg) < 4:
        return seg, 0.0
    before = total_length(seg)
    if before == 0:
        return seg, 0.0
    best = seg
    best_len = before
    # Le départ d'origine est conservé en priorité pour préserver le sens de
    # circulation ; l'autre extrémité sert de candidat de secours.
    for start in (0, len(seg) - 1):
        candidate = two_opt(nearest_neighbor(seg, start))
        if start != 0:
            candidate.reverse()
        length = total_length(candidate)
        if length < best_len:
            best, best_len = candidate, length
    gain = (before - best_len) / before
    if gain < MIN_GAIN:
        return seg, 0.0
    return best, gain


def main():
    routes = json.loads(ROUTES_PATH.read_text(encoding='utf-8'))
    repaired = []
    for route in routes:
        segments = route.get('g') or []
        for si, seg in enumerate(segments):
            fixed, gain = repair_segment(seg)
            if gain > 0:
                segments[si] = fixed
                repaired.append((route.get('i'), si, gain))

    if not repaired:
        print('Aucun segment à réparer.')
        return

    ROUTES_PATH.write_text(
        json.dumps(routes, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8',
    )
    print(f'{len(repaired)} segment(s) réordonné(s) :')
    for rid, si, gain in repaired:
        print(f'  ligne {rid} seg{si} : -{gain * 100:.0f} % de longueur')


if __name__ == '__main__':
    main()
