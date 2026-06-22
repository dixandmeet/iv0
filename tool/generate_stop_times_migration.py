#!/usr/bin/env python3
"""Génère supabase/migrations/018_gtfs_stop_times.sql depuis un export GTFS legacy.

Usage :
    python3 tool/generate_stop_times_migration.py /chemin/vers/gtfs-legacy

Le GTFS doit utiliser les mêmes stop_id que la base (ex. RLON1, RLO71…).
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent
BATCH = 500


def sql_str(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def sql_interval(gtfs_time: str) -> str:
    parts = gtfs_time.strip().split(":")
    if len(parts) != 3:
        return "make_interval(secs => 0)"
    hours, minutes, seconds = (int(p) for p in parts)
    total = hours * 3600 + minutes * 60 + seconds
    return f"make_interval(secs => {total})"


def load_csv(gtfs: Path, name: str):
    with open(gtfs / name, newline="", encoding="utf-8-sig") as f:
        yield from csv.DictReader(f)


def seed_trip_ids(seed_path: Path) -> dict[str, str]:
    """route_id (ex. '71') -> trip_id seed (ex. 'T-71-0')."""
    text = seed_path.read_text(encoding="utf-8")
    mapping: dict[str, str] = {}
    for trip_id, route_id, *_rest in re.findall(
        r"\('(T-[^']+)','([^']+)','ALL'", text
    ):
        mapping.setdefault(route_id, trip_id)
    return mapping


def seed_stop_ids(seed_path: Path) -> set[str]:
    """stop_id présents dans gtfs_stops du seed (donc en base)."""
    text = seed_path.read_text(encoding="utf-8")
    return set(
        re.findall(
            r"^\s+\('([^']+)','[^']*',\d+,ST_SetSRID",
            text,
            flags=re.MULTILINE,
        )
    )


def main(gtfs: Path) -> None:
    seed_path = PROJECT / "supabase/seed_tan.sql"
    route_to_trip = seed_trip_ids(seed_path)
    if not route_to_trip:
        sys.exit("Impossible de lire les trips depuis seed_tan.sql")

    valid_stops = seed_stop_ids(seed_path)
    if not valid_stops:
        sys.exit("Impossible de lire les arrêts depuis seed_tan.sql")
    trip_route = {r["trip_id"]: r["route_id"] for r in load_csv(gtfs, "trips.txt")}

    seen: set[tuple[str, str]] = set()
    trip_sequence: dict[str, int] = {}
    rows: list[tuple[str, str, str, str, int]] = []
    for row in load_csv(gtfs, "stop_times.txt"):
        stop_id = row["stop_id"]
        if stop_id not in valid_stops:
            continue
        route_id = trip_route.get(row["trip_id"])
        if not route_id:
            continue
        seed_trip = route_to_trip.get(route_id)
        if not seed_trip:
            continue
        key = (stop_id, route_id)
        if key in seen:
            continue
        seen.add(key)
        trip_sequence[seed_trip] = trip_sequence.get(seed_trip, 0) + 1
        rows.append(
            (
                seed_trip,
                stop_id,
                sql_interval(row["arrival_time"]),
                sql_interval(row["departure_time"]),
                trip_sequence[seed_trip],
            )
        )

    out = PROJECT / "supabase/migrations/018_gtfs_stop_times.sql"
    lines = [
        "-- Horaires GTFS théoriques (couples arrêt/ligne pour lignes desservies)",
        "-- Genere par tool/generate_stop_times_migration.py",
        "BEGIN;",
        "",
        "TRUNCATE gtfs_stop_times;",
        "",
        f"-- {len(rows)} couples arrêt/ligne",
    ]
    sql_rows = [
        f"  ({sql_str(trip_id)},{sql_str(stop_id)},{arr},{dep},{seq})"
        for trip_id, stop_id, arr, dep, seq in rows
    ]
    for i in range(0, len(sql_rows), BATCH):
        lines.append(
            "INSERT INTO gtfs_stop_times "
            "(trip_id, stop_id, arrival_time, departure_time, stop_sequence) VALUES"
        )
        lines.append(",\n".join(sql_rows[i : i + BATCH]) + ";")
        lines.append("")
    lines.extend(["COMMIT;", ""])
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"{out.name}: {len(rows)} stop_times ({len(route_to_trip)} lignes seed)")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
