#!/usr/bin/env python3
"""Précompile les horaires théoriques réels du GTFS Naolib en un index compact.

Entrée  : le GTFS statique officiel (zip, ~18 Mo compressé / 450 Mo décompressé)
          téléchargé depuis data.nantesmetropole.fr (dataset
          244400404_transports_commun_naolib_nantes_metropole_gtfs).
Sortie  : assets/data/naolib_schedules.json

Le `stop_times.txt` brut (~415 Mo) est inexploitable tel quel dans l'app : on
le réduit ici à, pour chaque (ligne × arrêt × direction × type de jour), la
liste dédoublonnée des minutes de passage. On garde aussi le quai GTFS et le
route_id GTFS pour le pont temps réel GTFS-RT.

Type de jour : 'd' = semaine (lun-ven), 's' = samedi, 'u' = dimanche/férié.
Les minutes peuvent dépasser 1440 (service après minuit, ex. 25:10).

Usage :
    python3 tool/build_schedules.py /chemin/vers/gtfs.zip
"""
import csv
import io
import json
import re
import sys
import zipfile
from collections import Counter, defaultdict
from datetime import date

ROOT = __file__.rsplit("/tool/", 1)[0]
OUT = f"{ROOT}/assets/data/naolib_schedules.json"

_ACCENTS = str.maketrans("àâäéèêëîïôöûüùç", "aaaeeeeiioouuuc")


def norm(s: str) -> str:
    s = s.lower().translate(_ACCENTS)
    s = re.sub(r"[^a-z0-9 ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def reader(zf: zipfile.ZipFile, name: str):
    """Itère les lignes d'un membre CSV en streaming (sans extraction disque)."""
    with zf.open(name) as raw:
        text = io.TextIOWrapper(raw, encoding="utf-8-sig", newline="")
        yield from csv.DictReader(text)


def to_minutes(hms: str):
    parts = hms.split(":")
    if len(parts) < 2:
        return None
    try:
        return int(parts[0]) * 60 + int(parts[1])
    except ValueError:
        return None


def median_from_counter(counter):
    """Médiane d'un histogramme {valeur: effectif}. None si vide."""
    total = sum(counter.values())
    if total == 0:
        return None
    target = total / 2
    cum = 0
    for val, cnt in sorted(counter.items()):
        cum += cnt
        if cum >= target:
            return val
    return None


def service_buckets(zf):
    """service_id -> set de types de jour ('d','s','u'), calendrier + exceptions."""
    buckets = defaultdict(set)
    weekday_cols = ["monday", "tuesday", "wednesday", "thursday", "friday"]
    for row in reader(zf, "calendar.txt"):
        sid = row["service_id"]
        if any(row[c] == "1" for c in weekday_cols):
            buckets[sid].add("d")
        if row["saturday"] == "1":
            buckets[sid].add("s")
        if row["sunday"] == "1":
            buckets[sid].add("u")
    # Exceptions ajoutées (jours fériés, services scolaires ponctuels).
    try:
        for row in reader(zf, "calendar_dates.txt"):
            if row.get("exception_type") != "1":
                continue
            d = row["date"]
            try:
                dow = date(int(d[:4]), int(d[4:6]), int(d[6:8])).weekday()
            except ValueError:
                continue
            b = "d" if dow < 5 else ("s" if dow == 5 else "u")
            buckets[row["service_id"]].add(b)
    except KeyError:
        pass
    return buckets


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: build_schedules.py <gtfs.zip>")
    zip_path = sys.argv[1]
    zf = zipfile.ZipFile(zip_path)

    print("• routes.txt"); route_id_by_short = {}
    short_by_route = {}
    for row in reader(zf, "routes.txt"):
        short = row["route_short_name"].strip()
        if short:
            route_id_by_short[short] = row["route_id"]
            short_by_route[row["route_id"]] = short

    print("• stops.txt"); name_by_stop = {}
    for row in reader(zf, "stops.txt"):
        name_by_stop[row["stop_id"]] = row["stop_name"]

    print("• calendar"); buckets_by_service = service_buckets(zf)

    print("• trips.txt"); trip_info = {}
    for row in reader(zf, "trips.txt"):
        short = short_by_route.get(row["route_id"])
        if short is None:
            continue
        buckets = buckets_by_service.get(row["service_id"])
        if not buckets:
            continue
        # trip_headsign = libellé officiel de direction (« François Mitterrand /
        # Jamet »). On le préfère au nom du dernier arrêt, qui surreprésente les
        # services partiels et terminus intermédiaires (cf. tram 1 « Commerce »).
        disp = (row.get("trip_headsign", "") or "").strip()
        trip_info[row["trip_id"]] = (short, buckets, norm(disp), disp)

    # sched[short][stopNorm][terminusNorm] = {'q': quay, 'd':set, 's':set, 'u':set}
    sched = defaultdict(lambda: defaultdict(dict))
    # Temps de parcours réel : histogramme du temps restant jusqu'au terminus
    # par (ligne, arrêt, terminus). rem[short][sname][terminus] = Counter(min).
    # En véhicule A->B (même sens) = reste[A] - reste[B], robuste aux services
    # partiels qui partagent le terminus.
    rem = defaultdict(lambda: defaultdict(lambda: defaultdict(Counter)))

    def flush(trip_id, rows):
        info = trip_info.get(trip_id)
        if not info or not rows:
            return
        short, tbuckets, headsign, disp = info
        # rows triées par stop_sequence ; direction = trip_headsign officiel,
        # avec repli sur le dernier arrêt si le headsign manque.
        rows.sort(key=lambda r: r[0])
        last_name = name_by_stop.get(rows[-1][1], "")
        terminus = headsign or norm(last_name)
        if not terminus:
            return
        term_disp = disp or last_name
        term_mins = rows[-1][2]
        for _, stop_id, mins in rows:
            sname = norm(name_by_stop.get(stop_id, ""))
            if not sname or mins is None:
                continue
            dirmap = sched[short][sname]
            cell = dirmap.get(terminus)
            if cell is None:
                cell = {"q": stop_id, "t": term_disp,
                        "d": set(), "s": set(), "u": set()}
                dirmap[terminus] = cell
            for b in tbuckets:
                cell[b].add(mins)
            if term_mins is not None and term_mins >= mins:
                rem[short][sname][terminus][term_mins - mins] += 1

    print("• stop_times.txt (streaming)…")
    cur_trip = None
    cur_rows = []
    n = 0
    for row in reader(zf, "stop_times.txt"):
        n += 1
        if n % 1_000_000 == 0:
            print(f"  … {n:,} lignes")
        tid = row["trip_id"]
        if tid != cur_trip:
            flush(cur_trip, cur_rows)
            cur_trip = tid
            cur_rows = []
        try:
            seq = int(row["stop_sequence"])
        except ValueError:
            continue
        cur_rows.append(
            (seq, row["stop_id"], to_minutes(row["departure_time"] or row["arrival_time"]))
        )
    flush(cur_trip, cur_rows)
    print(f"  total {n:,} lignes")

    # Sérialisation : listes triées dédoublonnées, on omet les buckets vides.
    out_sched = {}
    n_cells = 0
    for short, stops in sched.items():
        out_stops = {}
        for sname, dirs in stops.items():
            out_dirs = {}
            for term, cell in dirs.items():
                entry = {"q": cell["q"]}
                if cell.get("t"):
                    entry["t"] = cell["t"]
                for b in ("d", "s", "u"):
                    if cell[b]:
                        entry[b] = sorted(cell[b])
                # Temps médian restant jusqu'au terminus (minutes en véhicule).
                r = median_from_counter(rem[short][sname][term])
                if r is not None:
                    entry["r"] = r
                out_dirs[term] = entry
                n_cells += 1
            out_stops[sname] = out_dirs
        out_sched[short] = out_stops

    payload = {
        "routes": route_id_by_short,
        "sched": out_sched,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))

    import os
    size = os.path.getsize(OUT)
    print(f"✓ {OUT}")
    print(f"  lignes={len(out_sched)}  cellules(ligne×arrêt×dir)={n_cells:,}")
    print(f"  taille={size/1_048_576:.1f} Mo")


if __name__ == "__main__":
    main()
