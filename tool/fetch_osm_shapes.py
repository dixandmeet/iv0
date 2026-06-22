#!/usr/bin/env python3
"""Remplace les tracés (`g`) de assets/data/tan_routes.json par la géométrie
réelle des lignes issue d'OpenStreetMap.

Pourquoi OSM : les flux officiels Naolib (GTFS `shapes.txt`, NeTEx) ne
contiennent qu'un point tous les ~350-500 m (positions des arrêts), d'où des
tracés rectilignes coupant à travers les bâtiments. Les relations OSM
`type=route` du réseau TAN/Naolib portent la géométrie fine des rails et des
rues (un point tous les ~5-30 m).

Pipeline par ligne (clé `s` = ref OSM) :
  1. relations Overpass (une par direction/variante, géométrie incluse) ;
  2. assemblage des ways membres en polyligne continue (gestion des sens
     inversés et des anneaux type rond-point) ;
  3. les deux sens sont CONSERVÉS (rues à sens unique : le graphe de routage
     et shapeToward en ont besoin ; displayShapes déduplique à l'affichage) ;
  4. simplification Douglas-Peucker (4 m) puis densification à 55 m max —
     le graphe de routage (gtfs_service.dart) rattache les arrêts aux POINTS
     du tracé dans un rayon de 130 m, l'espacement doit rester en dessous.

Lignes sans relation OSM (périurbaines 1xx) : leur tracé grossier existant
est re-routé par A* sur le réseau des géométries OSM collectées (toutes
lignes confondues) ; les tronçons hors réseau restent en ligne droite.

NB : le GTFS officiel encode aussi les déviations temporaires (travaux,
bus relais) ; on affiche volontairement les tracés nominaux OSM.

Usage : python3 tool/fetch_osm_shapes.py [--cache /tmp/osm_naolib.json]
"""
import argparse
import json
import math
import sys
import time
import urllib.parse
import urllib.request
from collections import defaultdict
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
ROUTES_PATH = PROJECT / 'assets/data/tan_routes.json'

OVERPASS_URL = 'https://overpass-api.de/api/interpreter'
# Nantes Métropole élargie (les lignes périurbaines sortent de Nantes).
BBOX = '47.05,-1.85,47.42,-1.28'
QUERY = f"""
[out:json][timeout:180];
(
  relation["type"="route"]["route"~"^(tram|bus|trolleybus|ferry)$"]
          ["network"~"TAN|Naolib",i]({BBOX});
  relation["type"="route"]["route"~"^(tram|bus|trolleybus|ferry)$"]
          ["operator"~"SEMITAN",i]({BBOX});
);
out geom;
"""

# Simplification : 4 m conserve les courbes de rails tout en éliminant les
# points redondants des longues lignes droites.
SIMPLIFY_M = 4.0
# Espacement max entre points (cf. rayon d'accrochage arrêt<->tracé, 130 m).
STEP_M = 55.0
# Au-delà, deux ways consécutifs ne sont pas considérés comme connectés.
JOIN_M = 120.0


def dist(a, b):
    lat = math.radians((a[0] + b[0]) / 2)
    dx = (b[1] - a[1]) * 111320 * math.cos(lat)
    dy = (b[0] - a[0]) * 110540
    return math.hypot(dx, dy)


def length(pts):
    return sum(dist(pts[i - 1], pts[i]) for i in range(1, len(pts)))


def fetch_overpass(cache_path):
    cache = Path(cache_path)
    if cache.exists():
        print(f'Overpass : cache {cache}')
        return json.loads(cache.read_text(encoding='utf-8'))
    print('Overpass : téléchargement (peut prendre ~1 min)…')
    req = urllib.request.Request(
        OVERPASS_URL,
        data=('data=' + urllib.parse.quote(QUERY)).encode(),
        headers={'User-Agent': 'aule-shape-builder/1.0'},
    )
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.load(resp)
    cache.write_text(json.dumps(data), encoding='utf-8')
    print(f'Overpass : {len(data.get("elements", []))} relations '
          f'en {time.time() - t0:.0f}s (cache -> {cache})')
    return data


def way_points(member):
    return [(g['lat'], g['lon']) for g in member.get('geometry', [])]


def is_ring(pts):
    return len(pts) > 3 and dist(pts[0], pts[-1]) < 1.0


def ring_arc(ring, from_pt, to_pt):
    """Arc d'un anneau (rond-point) entre les points les plus proches de
    from_pt et to_pt, dans le sens du parcours le plus court."""
    ring = ring[:-1] if is_ring(ring) else ring
    n = len(ring)
    i0 = min(range(n), key=lambda i: dist(ring[i], from_pt))
    i1 = min(range(n), key=lambda i: dist(ring[i], to_pt))
    fwd = [ring[(i0 + k) % n] for k in range((i1 - i0) % n + 1)]
    bwd = [ring[(i0 - k) % n] for k in range((i0 - i1) % n + 1)]
    return fwd if length(fwd) <= length(bwd) else bwd


def stitch(ways):
    """Assemble les géométries de ways (ordonnées comme dans la relation) en
    chaînes continues ; retourne la liste des chaînes obtenues."""
    chains = []
    current = []
    for idx, pts in enumerate(ways):
        if len(pts) < 2:
            continue
        if not current:
            current = list(pts)
            continue
        end = current[-1]
        if is_ring(pts):
            nxt = None
            for later in ways[idx + 1:]:
                if later and not is_ring(later):
                    # point de sortie : extrémité du prochain way la plus
                    # proche de l'anneau
                    nxt = min((later[0], later[-1]),
                              key=lambda p: min(dist(p, q) for q in pts))
                    break
            arc = ring_arc(pts, end, nxt if nxt is not None else end)
            if arc and dist(end, arc[0]) <= JOIN_M:
                current.extend(arc)
                continue
            # anneau isolé : ignoré
            continue
        d_start, d_end = dist(end, pts[0]), dist(end, pts[-1])
        if min(d_start, d_end) > JOIN_M:
            chains.append(current)
            current = list(pts)
            continue
        seg = pts if d_start <= d_end else list(reversed(pts))
        if dist(end, seg[0]) < 1.0:
            current.extend(seg[1:])
        else:
            current.extend(seg)
    if current:
        chains.append(current)
    return chains


def assemble(relation):
    """Polyligne d'une relation : assemblage dans l'ordre des membres, puis
    re-tentative par recollement des chaînes si la relation est mal ordonnée."""
    ways = [way_points(m) for m in relation.get('members', [])
            if m.get('type') == 'way'
            and m.get('role', '') in ('', 'forward', 'backward', 'route')]
    chains = stitch(ways)
    if not chains:
        return []
    if len(chains) == 1:
        return chains[0]
    # Recollage glouton des chaînes par extrémités les plus proches.
    merged = chains[0]
    rest = chains[1:]
    while rest:
        best_i, best_rev, best_d = None, False, float('inf')
        for i, c in enumerate(rest):
            for rev in (False, True):
                p = c[-1] if rev else c[0]
                d = dist(merged[-1], p)
                if d < best_d:
                    best_i, best_rev, best_d = i, rev, d
        if best_d > JOIN_M:
            break
        c = rest.pop(best_i)
        merged.extend(reversed(c) if best_rev else c)
    return merged


def simplify(pts, tol_m):
    """Douglas-Peucker itératif (distance perpendiculaire approchée)."""
    if len(pts) < 3:
        return pts
    keep = [False] * len(pts)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        lo, hi = stack.pop()
        if hi - lo < 2:
            continue
        a, b = pts[lo], pts[hi]
        ab = dist(a, b)
        best_d, best_i = -1.0, None
        for i in range(lo + 1, hi):
            if ab < 1e-9:
                d = dist(pts[i], a)
            else:
                # aire du triangle / base = hauteur
                d = abs((b[0] - a[0]) * (a[1] - pts[i][1])
                        - (a[0] - pts[i][0]) * (b[1] - a[1]))
                d = d * 110540 * 111320 * math.cos(
                    math.radians(a[0])) / (ab or 1)
            if d > best_d:
                best_d, best_i = d, i
        if best_d > tol_m and best_i is not None:
            keep[best_i] = True
            stack.append((lo, best_i))
            stack.append((best_i, hi))
    return [p for p, k in zip(pts, keep) if k]


def densify(pts, step):
    """Insère des points sur les segments > step (graphe de routage)."""
    if len(pts) < 2:
        return pts
    out = [pts[0]]
    for i in range(1, len(pts)):
        a, b = pts[i - 1], pts[i]
        seg = dist(a, b)
        n = int(seg // step)
        for k in range(1, n + 1):
            t = k / (n + 1)
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
        out.append(b)
    return out


class Network:
    """Graphe des géométries OSM (toutes lignes) pour re-router les variantes
    de service absentes d'OSM le long des vraies rues/rails (A*)."""

    CONNECT_M = 30.0
    SNAP_M = 100.0
    CELL = 0.0005  # ~55 m

    def __init__(self, polylines):
        self.pts = []
        self.adj = defaultdict(list)
        grid = defaultdict(list)
        for line in polylines:
            prev = None
            for p in line:
                i = len(self.pts)
                self.pts.append(p)
                grid[self._cell(p)].append(i)
                if prev is not None:
                    d = dist(self.pts[prev], p)
                    self.adj[prev].append((i, d))
                    self.adj[i].append((prev, d))
                prev = i
        # Connecteurs entre lignes proches (croisements, troncs communs).
        for i, p in enumerate(self.pts):
            cx, cy = self._cell(p)
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    for j in grid[(cx + dx, cy + dy)]:
                        if j <= i:
                            continue
                        d = dist(p, self.pts[j])
                        if d <= self.CONNECT_M:
                            w = d * 1.2 + 5  # légère pénalité de changement
                            self.adj[i].append((j, w))
                            self.adj[j].append((i, w))
        self.grid = grid

    def _cell(self, p):
        return (int(p[0] / self.CELL), int(p[1] / self.CELL))

    def snap(self, p):
        cx, cy = self._cell(p)
        best, best_d = None, self.SNAP_M
        r = 2
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                for i in self.grid.get((cx + dx, cy + dy), ()):
                    d = dist(p, self.pts[i])
                    if d < best_d:
                        best, best_d = i, d
        return best

    def path(self, a, b):
        """A* entre les noeuds a et b ; None si introuvable/déraisonnable."""
        import heapq
        target = self.pts[b]
        gscore = {a: 0.0}
        came = {}
        heap = [(dist(self.pts[a], target), a)]
        limit = max(2.5 * dist(self.pts[a], target),
                    dist(self.pts[a], target) + 600)
        while heap:
            _, u = heapq.heappop(heap)
            if u == b:
                path = [b]
                while path[-1] in came:
                    path.append(came[path[-1]])
                return [self.pts[i] for i in reversed(path)]
            gu = gscore[u]
            if gu > limit:
                return None
            for v, w in self.adj[u]:
                g = gu + w
                if g < gscore.get(v, float('inf')):
                    gscore[v] = g
                    came[v] = u
                    heapq.heappush(heap, (g + dist(self.pts[v], target), v))
        return None


def reroute(coarse, network):
    """Re-route une polyligne grossière (points ~500 m) sur le réseau OSM.
    Les tronçons non couverts restent des lignes droites."""
    out = [coarse[0]]
    matched = 0.0
    for i in range(1, len(coarse)):
        a, b = coarse[i - 1], coarse[i]
        na, nb = network.snap(a), network.snap(b)
        leg = None
        if na is not None and nb is not None and na != nb:
            leg = network.path(na, nb)
        if leg:
            matched += dist(a, b)
            if dist(out[-1], leg[0]) > 1.0:
                out.append(leg[0])
            out.extend(leg[1:])
            if dist(out[-1], b) > Network.SNAP_M:
                out.append(b)
        else:
            out.append(b)
    return out, (matched / max(length(coarse), 1))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--cache', default='/tmp/osm_naolib.json')
    ap.add_argument('--source', default=None,
                    help='tan_routes.json source (def: fichier en place)')
    args = ap.parse_args()

    data = fetch_overpass(args.cache)
    by_ref = defaultdict(list)
    for rel in data.get('elements', []):
        tags = rel.get('tags', {})
        if tags.get('state') in ('proposed', 'construction'):
            continue
        ref = tags.get('ref')
        if ref:
            by_ref[ref].append(rel)

    source = Path(args.source) if args.source else ROUTES_PATH
    routes = json.loads(source.read_text(encoding='utf-8'))

    # 1. Assemblage des variantes OSM par ligne (les deux sens conservés).
    osm_variants = {}
    for route in routes:
        rels = by_ref.get(route['s']) or by_ref.get(route['i']) or []
        variants = []
        for rel in rels:
            pts = assemble(rel)
            if len(pts) >= 2 and length(pts) > 800:
                variants.append(simplify(pts, SIMPLIFY_M))
        if variants:
            osm_variants[route['i']] = variants

    # 2. Réseau global pour re-router les variantes sans relation OSM.
    network = Network([v for vs in osm_variants.values() for v in vs])
    print(f'réseau OSM : {len(network.pts)} points, '
          f'{len(osm_variants)} lignes couvertes')

    rebuilt, rerouted, kept_coarse = 0, 0, []
    for route in routes:
        variants = list(osm_variants.get(route['i'], []))
        extra = 0
        if not variants:
            # Ligne absente d'OSM : on re-route son tracé grossier existant
            # sur le réseau des autres lignes (mieux que des lignes droites).
            for old_seg in route.get('g', []):
                coarse = [(p[0], p[1]) for p in old_seg]
                if len(coarse) < 2:
                    continue
                synth, ratio = reroute(coarse, network)
                variants.append(synth)
                extra += 1
                rerouted += 1
                if ratio < 0.5:
                    kept_coarse.append(f"{route['s']} ({ratio:.0%} sur réseau)")

        if not variants:
            continue
        route['g'] = [
            [[round(la, 5), round(lo, 5)] for la, lo in densify(seg, STEP_M)]
            for seg in variants
        ]
        rebuilt += 1
        npts = sum(len(s) for s in route['g'])
        n_osm = len(osm_variants.get(route['i'], []))
        print(f"ligne {route['s']:>4} ({route['t']:>7}): "
              f"{n_osm} variante(s) OSM + {extra} re-routée(s), {npts} pts")

    ROUTES_PATH.write_text(
        json.dumps(routes, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8',
    )
    size_mb = ROUTES_PATH.stat().st_size / 1e6
    print(f'\n{rebuilt} ligne(s) reconstruite(s) ({rerouted} variante(s) '
          f're-routée(s)) -> {ROUTES_PATH.name} ({size_mb:.1f} Mo)')
    if kept_coarse:
        print('variantes restées majoritairement en ligne droite : '
              + ', '.join(kept_coarse))
    return 0


if __name__ == '__main__':
    sys.exit(main())
