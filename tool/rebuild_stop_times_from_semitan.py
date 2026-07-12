#!/usr/bin/env python3
"""Régénère supabase/migrations/030_gtfs_stop_times_rebuild.sql depuis le GTFS Semitan.

    python3 tool/rebuild_stop_times_from_semitan.py "/chemin/vers/gtfs_lumidata_id"

Contexte
--------
L'ancien tool/generate_stop_times_migration.py fabriquait UN trip `T-<route>-0`
par ligne en fusionnant les arrêts de tous les trajets réels (dédup par
(stop_id, route_id)), avec un stop_sequence = compteur « premier vu » et des
horaires mélangés → table `gtfs_stop_times` non monotone (ETA absurdes côté SAE
et prev/next faux côté dashboard).

Ce script produit une VRAIE grille horaire : pour chaque (ligne, sens), il prend
les *journey patterns* réels de la source, mappe les arrêts source
(FR_NAOLIB:Quay:*) sur les arrêts de la base (exact par géométrie) et écrit un
itinéraire ordonné (stop_sequence réel + horaires réels) dans un trip de la base.
Le pattern le plus long va sur le trip dont le shape colle le mieux (utilisé par
SAE) ; les patterns plus courts remplissent d'autres trips du même sens (pour la
couverture arrêt↔ligne du dashboard).

Le GTFS source et la base n'ont pas la même nomenclature d'id ; le lien se fait
uniquement par coordonnées (les arrêts de la base ont les mêmes lat/lon que la
source, écart médian 0 m).
"""
from __future__ import annotations

import csv
import json
import math
import sys
import unicodedata
import urllib.request
from collections import defaultdict
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
OUT = PROJECT / "supabase/migrations/030_gtfs_stop_times_rebuild.sql"
SUPABASE_URL = "https://rllcdvuqduuyhdcifiwp.supabase.co"
PUBLISHABLE_KEY = "sb_publishable_SoVrtwgKHm3lkFaW8r5fmA_HEH7VpL6"
BATCH = 500
SKIP_DISTANCE_M = 120  # au-delà + nom différent = arrêt absent de la base


def rest(path: str) -> list[dict]:
    """Lit une table via PostgREST, en paginant."""
    out: list[dict] = []
    offset = 0
    while True:
        req = urllib.request.Request(
            f"{SUPABASE_URL}/rest/v1/{path}&limit=1000&offset={offset}",
            headers={
                "apikey": PUBLISHABLE_KEY,
                "Authorization": f"Bearer {PUBLISHABLE_KEY}",
                "User-Agent": "curl/8",
            },
        )
        page = json.load(urllib.request.urlopen(req))
        out.extend(page)
        if len(page) < 1000:
            return out
        offset += 1000


def load_csv(gtfs: Path, name: str):
    return list(csv.DictReader(open(gtfs / name, encoding="utf-8-sig")))


def hav(a, b):
    r = 6371000
    la1, la2 = math.radians(a[0]), math.radians(b[0])
    dla, dlo = math.radians(b[0] - a[0]), math.radians(b[1] - a[1])
    h = math.sin(dla / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin(dlo / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def norm(s: str) -> str:
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    return "".join(c for c in s if c.isalnum())


def seg_lengths(pts):
    return [
        math.hypot(
            pts[i + 1][0] - pts[i][0],
            (pts[i + 1][1] - pts[i][1]) * math.cos(pts[i][0] * math.pi / 180),
        )
        for i in range(len(pts) - 1)
    ]


def project_t(pts, seglen, total, p):
    cl = math.cos(p[0] * math.pi / 180)
    px, py = p[1] * cl, p[0]
    best, bi, bf, ba, acc = 1e18, 0, 0.0, 0.0, 0.0
    for i in range(len(pts) - 1):
        ax, ay = pts[i][1] * cl, pts[i][0]
        bx, by = pts[i + 1][1] * cl, pts[i + 1][0]
        dx, dy = bx - ax, by - ay
        ln = dx * dx + dy * dy
        f = 0.0 if ln == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / ln))
        cx, cy = ax + dx * f, ay + dy * f
        d = (px - cx) ** 2 + (py - cy) ** 2
        if d < best:
            best, bi, bf, ba = d, i, f, acc
        acc += seglen[i]
    return (ba + seglen[bi] * bf) / total if total else 0.0


def main(gtfs: Path) -> None:
    print("Lecture de la base…")
    db_stops = rest("gtfs_stops?select=stop_id,stop_name,geom")
    for x in db_stops:
        x["lon"], x["lat"] = x["geom"]["coordinates"]
    db_trips = rest("gtfs_trips?select=trip_id,route_id,direction_id,shape_id")
    shape_rows = rest("gtfs_shapes?select=shape_id,shape_pt_sequence,geom")

    # Index géographique des arrêts de la base.
    grid: dict = defaultdict(list)
    cell = lambda la, lo: (round(la * 500), round(lo * 500))
    for x in db_stops:
        grid[cell(x["lat"], x["lon"])].append(x)

    def nearest(la, lo):
        best, bd = None, 1e18
        c = cell(la, lo)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                for x in grid.get((c[0] + dy, c[1] + dx), ()):
                    d = (x["lat"] - la) ** 2 + ((x["lon"] - lo) * math.cos(la * math.pi / 180)) ** 2
                    if d < bd:
                        bd, best = d, x
        return best, (math.sqrt(bd) * 111320 if best else 9e9)

    # Shapes de la base : shape_id -> points ordonnés (lat, lon).
    shp = defaultdict(list)
    for r in shape_rows:
        shp[r["shape_id"]].append((r["shape_pt_sequence"], r["geom"]["coordinates"]))
    shape_pts = {s: [(c[1], c[0]) for _, c in sorted(v)] for s, v in shp.items()}
    db_coord = {x["stop_id"]: (x["lat"], x["lon"]) for x in db_stops}

    print("Lecture du GTFS source…")
    routes = {r["route_id"]: r["route_short_name"] for r in load_csv(gtfs, "routes.txt")}
    src_stops = {
        s["stop_id"]: (float(s["stop_lat"]), float(s["stop_lon"]), s["stop_name"])
        for s in load_csv(gtfs, "stops.txt")
    }
    # Un trip représentatif par pattern (route_short, direction, shape_id).
    rep, trip_pat = {}, {}
    for t in load_csv(gtfs, "trips.txt"):
        short = routes.get(t["route_id"])
        if short is None:
            continue
        key = (short, t["direction_id"], t["shape_id"])
        if key not in rep:
            rep[key] = t["trip_id"]
            trip_pat[t["trip_id"]] = key
    rep_ids = set(rep.values())

    print("Balayage des horaires source (une passe)…")
    pat_rows = defaultdict(list)
    for line in open(gtfs / "stop_times.txt", encoding="utf-8-sig"):
        tid = line.split(",", 1)[0].strip('"')
        if tid not in rep_ids:
            continue
        row = next(csv.reader([line]))
        pat_rows[trip_pat[tid]].append((int(row[4]), row[3], row[1]))
    for p in pat_rows:
        pat_rows[p].sort()

    # Mapping arrêt source -> arrêt base (géométrie, avec garde-fou).
    src_map, skipped = {}, 0
    used = {sid for rows in pat_rows.values() for _, sid, _ in rows}
    for sid in used:
        la, lo, nm = src_stops[sid]
        m, d = nearest(la, lo)
        if d > SKIP_DISTANCE_M and norm(nm) != norm(m["stop_name"]):
            src_map[sid] = None
            skipped += 1
        else:
            src_map[sid] = m["stop_id"]
    print(f"  {len(used)} arrêts source, {skipped} ignorés (absents de la base)")

    def to_dbstops(rows):
        out = []
        for _, sid, arr in rows:
            ds = src_map.get(sid)
            if ds is None or (out and out[-1][0] == ds):
                continue
            p = arr.split(":")
            out.append((ds, int(p[0]) * 3600 + int(p[1]) * 60 + int(p[2])))
        return out

    def shape_ends(sid):
        p = shape_pts.get(sid)
        return (p[0], p[-1]) if p and len(p) >= 2 else None

    route_trips = defaultdict(list)
    for t in db_trips:
        route_trips[t["route_id"]].append(t)
    pat_by_rd = defaultdict(list)
    for k in rep:
        pat_by_rd[(k[0], k[1])].append(k)

    # Affectation pattern -> trip de la base (endpoints, plus long d'abord).
    assign, mono_bad = [], 0
    for route_id, tlist in route_trips.items():
        for d in ("0", "1"):
            pats = [(k, to_dbstops(pat_rows[k])) for k in pat_by_rd.get((route_id, d), [])]
            pats = [(k, s) for k, s in pats if len(s) >= 2]
            pats.sort(key=lambda x: -len(x[1]))
            avail = [t for t in tlist if str(t["direction_id"]) == d] or list(tlist)
            for _, dbs in pats:
                pf, pl = db_coord[dbs[0][0]], db_coord[dbs[-1][0]]
                best, bd = None, 1e18
                for t in avail:
                    se = shape_ends(t["shape_id"])
                    if se and (dd := hav(pf, se[0]) + hav(pl, se[1])) < bd:
                        bd, best = dd, t
                if best is None:
                    continue
                avail.remove(best)
                assign.append((best["trip_id"], dbs))
                pts = shape_pts.get(best["shape_id"])
                if pts and len(pts) >= 2:
                    sl = seg_lengths(pts)
                    ts = [project_t(pts, sl, sum(sl), db_coord[s]) for s, _ in dbs]
                    if sum(1 for i in range(1, len(ts)) if ts[i] < ts[i - 1] - 0.02) > max(1, len(ts) // 10):
                        mono_bad += 1

    rows = [
        f"  ('{tid}','{sid}',make_interval(secs => {sc}),make_interval(secs => {sc}),{i})"
        for tid, dbs in assign
        for i, (sid, sc) in enumerate(dbs, 1)
    ]
    lines = [
        "-- Rebuild gtfs_stop_times : un itinéraire réel par trip (ordre + horaires GTFS Semitan)",
        "-- Généré par tool/rebuild_stop_times_from_semitan.py (source lumidata)",
        "-- Remplace 018 : chaque trip = un journey pattern réel (arrêts ordonnés, temps monotones).",
        "BEGIN;",
        "",
        "TRUNCATE gtfs_stop_times;",
        "",
        f"-- {len(rows)} arrêts sur {len(assign)} trips",
    ]
    for i in range(0, len(rows), BATCH):
        lines.append(
            "INSERT INTO gtfs_stop_times "
            "(trip_id, stop_id, arrival_time, departure_time, stop_sequence) VALUES"
        )
        lines.append(",\n".join(rows[i : i + BATCH]) + ";")
        lines.append("")
    lines += ["COMMIT;", ""]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"{OUT.name}: {len(rows)} lignes, {len(assign)} trips, {mono_bad} non-monotones")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
