#!/usr/bin/env python3
"""Met à jour les données réseau TAN / Naolib du projet depuis un export GTFS.

Usage :
    python3 tool/update_tan_data.py /chemin/vers/gtfs-tan

Produit :
  - assets/data/tan_stops.json   ({i,n,la,lo,lt,w} — w = wheelchair_boarding GTFS)
  - supabase/seed_tan.sql        (routes, arrêts + accessibilité, tracés, trips)

Note : assets/data/tan_routes.json n'est PAS régénéré. Ses tracés (`g`)
proviennent d'une source plus dense (~60 m entre points) que shapes.txt
des exports GTFS récents (~290 m, quasi un point par arrêt) ; les
remplacer dégraderait la carte et le graphe de routage hors-ligne. Le
script vérifie en revanche que lignes et métadonnées n'ont pas dérivé.
"""
import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
BATCH = 500  # lignes par INSERT multi-valeurs


def sql_str(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def num(s: str) -> float:
    # Conserve la précision source (pas de re-formatage float).
    return json.loads(s)


def load(gtfs: Path, name: str):
    with open(gtfs / name, newline="", encoding="utf-8-sig") as f:
        yield from csv.DictReader(f)


def main(gtfs: Path) -> None:
    routes = list(load(gtfs, "routes.txt"))
    stops = list(load(gtfs, "stops.txt"))

    # Tracés : points groupés par shape_id, ordonnés par séquence.
    shape_pts = defaultdict(list)
    for r in load(gtfs, "shapes.txt"):
        shape_pts[r["shape_id"]].append(
            (int(r["shape_pt_sequence"]), num(r["shape_pt_lon"]), num(r["shape_pt_lat"]))
        )
    for pts in shape_pts.values():
        pts.sort()

    # Usage réel des tracés : nb de courses et sens par shape_id.
    shape_trips = Counter()
    shape_dir = {}
    for r in load(gtfs, "trips.txt"):
        shape_trips[r["shape_id"]] += 1
        shape_dir[r["shape_id"]] = int(r["direction_id"] or 0)

    # Garde-fou : le jeu d'assets (tan_routes.json) doit couvrir les mêmes lignes.
    assets_routes = {
        r["i"]: r
        for r in json.loads((PROJECT / "assets/data/tan_routes.json").read_text())
    }
    gtfs_route_ids = {r["route_id"] for r in routes}
    drift = []
    if set(assets_routes) != gtfs_route_ids:
        drift.append(f"lignes: assets={sorted(set(assets_routes) - gtfs_route_ids)} "
                     f"gtfs={sorted(gtfs_route_ids - set(assets_routes))}")
    for r in routes:
        a = assets_routes.get(r["route_id"])
        if a and (a["l"] != r["route_long_name"] or a["c"] != r["route_color"]):
            drift.append(f"ligne {r['route_id']}: nom/couleur modifiés")
    if drift:
        print("ATTENTION — tan_routes.json a dérivé du GTFS, à régénérer à la main :")
        for d in drift:
            print("  -", d)

    # ------------------------------------------------------------------
    # 1. assets/data/tan_stops.json
    # ------------------------------------------------------------------
    stops_json = [
        {
            "i": s["stop_id"],
            "n": s["stop_name"],
            "la": num(s["stop_lat"]),
            "lo": num(s["stop_lon"]),
            "lt": s["location_type"] or "0",
            "w": int(s["wheelchair_boarding"] or 0),
        }
        for s in stops
    ]
    out_stops = PROJECT / "assets/data/tan_stops.json"
    out_stops.write_text(
        json.dumps(stops_json, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(f"{out_stops.name}: {len(stops_json)} arrêts")

    # ------------------------------------------------------------------
    # 2. supabase/seed_tan.sql
    # ------------------------------------------------------------------
    # Segments par ligne : tous les tracés GTFS de la ligne, ordonnés par
    # (sens, usage décroissant) -> shape_id stable "ROUTE-n".
    segments = defaultdict(list)  # route_id -> [(seed_shape_id, direction, pts)]
    for route in routes:
        rid = route["route_id"]
        sids = [s for s in shape_pts if s.split("_")[0] == rid]
        sids.sort(key=lambda s: (shape_dir.get(s, 0), -shape_trips[s], s))
        for n, sid in enumerate(sids):
            segments[rid].append((f"{rid}-{n}", shape_dir.get(sid, 0), shape_pts[sid]))

    lines = [
        "-- Seed des donnees GTFS reelles du reseau TAN / Naolib (SIREN 244400404)",
        "-- Genere par tool/update_tan_data.py depuis l'export GTFS Naolib.",
        "-- A executer APRES supabase/schema.sql.",
        "BEGIN;",
        "",
        "-- Idempotence : on repart de zero pour les donnees theoriques GTFS.",
        "TRUNCATE gtfs_stop_times, gtfs_trips, gtfs_shapes, gtfs_stops, gtfs_routes CASCADE;",
        "",
        "-- 1. Lignes",
        "INSERT INTO gtfs_routes (route_id, route_short_name, route_long_name, route_type, route_color) VALUES",
    ]
    rows = [
        f"  ({sql_str(r['route_id'])},{sql_str(r['route_short_name'])},"
        f"{sql_str(r['route_long_name'])},{int(r['route_type'])},{sql_str(r['route_color'])})"
        for r in routes
    ]
    lines.append(",\n".join(rows) + ";")

    lines += ["", f"-- 2. Arrets ({len(stops)} arrets, wheelchair: 0 inconnu / 1 accessible / 2 non)"]
    rows = [
        f"  ({sql_str(s['stop_id'])},{sql_str(s['stop_name'])},{int(s['wheelchair_boarding'] or 0)},"
        f"ST_SetSRID(ST_Point({s['stop_lon']}, {s['stop_lat']}), 4326))"
        for s in stops
    ]
    for i in range(0, len(rows), BATCH):
        lines.append("INSERT INTO gtfs_stops (stop_id, stop_name, wheelchair_boarding, geom) VALUES")
        lines.append(",\n".join(rows[i : i + BATCH]) + ";")

    lines += ["", "-- 3. Traces (un shape_id par variante de tracé GTFS)"]
    rows = []
    for rid in (r["route_id"] for r in routes):
        for seed_sid, _d, pts in segments[rid]:
            for seq, lon, lat in pts:
                rows.append(
                    f"  ({sql_str(seed_sid)},{seq},ST_SetSRID(ST_Point({lon}, {lat}), 4326))"
                )
    for i in range(0, len(rows), BATCH):
        lines.append("INSERT INTO gtfs_shapes (shape_id, shape_pt_sequence, geom) VALUES")
        lines.append(",\n".join(rows[i : i + BATCH]) + ";")

    lines += [
        "",
        "-- 4. Trips minimaux (1 par variante de tracé, direction_id reel)",
        "-- pour la detection temps reel (detect_probable_route).",
        "INSERT INTO gtfs_trips (trip_id, route_id, service_id, shape_id, direction_id) VALUES",
    ]
    rows = [
        f"  ({sql_str('T-' + seed_sid)},{sql_str(rid)},'ALL',{sql_str(seed_sid)},{d})"
        for rid in (r["route_id"] for r in routes)
        for seed_sid, d, _pts in segments[rid]
    ]
    lines.append(",\n".join(rows) + ";")
    lines += ["", "COMMIT;", ""]

    out_seed = PROJECT / "supabase/seed_tan.sql"
    out_seed.write_text("\n".join(lines), encoding="utf-8")
    nshapes = sum(len(v) for v in segments.values())
    print(f"{out_seed.name}: {len(routes)} lignes, {len(stops)} arrets, "
          f"{nshapes} traces, {nshapes} trips")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
