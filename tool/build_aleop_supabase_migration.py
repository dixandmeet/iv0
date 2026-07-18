#!/usr/bin/env python3
"""Génère la migration SQL d'import du réseau Aléop dans Supabase (carte immersive).

La carte immersive du dashboard route via la base : RPC get_nearby_stops /
get_stop_serving_lines sur `stations`/`stops`/`gtfs_stop_mapping` et les tables
GTFS partagées (`gtfs_routes` — scopée réseau depuis 066 —, `gtfs_stops`,
`gtfs_trips`, `gtfs_stop_times`, `gtfs_shapes`, globales/texte).

Ce script produit UNE migration idempotente qui :
  1. crée le réseau `aleop-pdl` ;
  2. charge les données Aléop (agence filtrée) dans les tables GTFS, ids
     préfixés `ALEOP:` (disjoints du TAN, filtrables) ;
  3. réduit à UNE course représentative par (ligne, sens) — suffisant pour le
     routage immersif (lignes desservantes + tracé), migration compacte ;
  4. matérialise stations/stops/gtfs_stop_mapping (bloc adapté de la
     migration 012, scopé `ALEOP:%`) ;
  5. vérifie la cohérence (scopée au réseau Aléop).

Rien n'est appliqué : le fichier est écrit pour relecture puis application
manuelle.

Usage :
    python3 tool/build_aleop_supabase_migration.py <gtfs.zip> \
        --agency ALEOP_44 --out supabase/migrations/073_aleop_pdl_import.sql
"""
import csv
import io
import sys
import zipfile
from collections import defaultdict

PREFIX = "ALEOP:"
NETWORK_ID = "a1e0b000-0000-4000-8000-000000000001"
NETWORK_CODE = "aleop-pdl"
NETWORK_NAME = "Aléop Pays de la Loire"
BATCH = 400


def reader(zf, name):
    with zf.open(name) as raw:
        yield from csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8-sig", newline=""))


def q(s):
    """Littéral SQL texte (échappe les apostrophes)."""
    return "'" + (s or "").replace("'", "''") + "'"


def secs(hms):
    parts = (hms or "").split(":")
    if len(parts) < 2:
        return None
    try:
        return int(parts[0]) * 3600 + int(parts[1]) * 60 + (int(parts[2]) if len(parts) > 2 else 0)
    except ValueError:
        return None


def parse_args(argv):
    agency, out = None, None
    pos = []
    i = 0
    while i < len(argv):
        if argv[i] == "--agency":
            agency = argv[i + 1]; i += 2
        elif argv[i] == "--out":
            out = argv[i + 1]; i += 2
        else:
            pos.append(argv[i]); i += 1
    if not pos or not out:
        sys.exit("usage: build_aleop_supabase_migration.py <gtfs.zip> --agency ID --out fichier.sql")
    return pos[0], agency, out


def emit_insert(f, table, cols, rows):
    """Écrit des INSERT multi-valeurs par lots de BATCH lignes."""
    header = f"INSERT INTO {table} ({', '.join(cols)}) VALUES\n"
    for i in range(0, len(rows), BATCH):
        chunk = rows[i:i + BATCH]
        f.write(header)
        f.write(",\n".join("  " + r for r in chunk))
        f.write(";\n")


def main():
    zip_path, agency, out = parse_args(sys.argv[1:])
    zf = zipfile.ZipFile(zip_path)

    # 1. routes de l'agence
    routes = {}
    for r in reader(zf, "routes.txt"):
        if agency and r.get("agency_id") != agency:
            continue
        routes[r["route_id"]] = r
    print(f"routes: {len(routes)}")

    # 2. trips → une course représentative par (route, direction)
    #    (celle dont la shape est la plus fréquente dans le groupe)
    group_trips = defaultdict(list)  # (route,dir) -> [(trip_id, shape_id)]
    agency_trips = set()  # toutes les courses de l'agence (couverture arrêts)
    for t in reader(zf, "trips.txt"):
        if t["route_id"] not in routes:
            continue
        agency_trips.add(t["trip_id"])
        did = (t.get("direction_id") or "0").strip() or "0"
        group_trips[(t["route_id"], did)].append((t["trip_id"], (t.get("shape_id") or "").strip()))

    repr_trip = {}   # trip_id -> (route_id, dir, shape_id)
    for (rid, did), lst in group_trips.items():
        shape_freq = defaultdict(int)
        for _, sid in lst:
            if sid:
                shape_freq[sid] += 1
        best_shape = max(shape_freq, key=shape_freq.get) if shape_freq else ""
        # course représentative : une portant la shape retenue, sinon la 1re
        chosen = next((tid for tid, sid in lst if sid == best_shape), lst[0][0])
        repr_trip[chosen] = (rid, did, best_shape)
    print(f"courses représentatives: {len(repr_trip)}")

    # 3. stop_times des courses représentatives (forward-fill des horaires).
    #    En parallèle, on recense TOUS les arrêts desservis par l'agence (pas
    #    seulement les courses représentatives) pour les importer comme
    #    marqueurs/arrêts recherchables ; ceux sans horaire retomberont sur le
    #    repli géométrique (80 m) de get_stop_serving_lines.
    st_by_trip = defaultdict(list)  # trip_id -> [(seq, stop_id, arr_s, dep_s)]
    used_stops = set()
    for st in reader(zf, "stop_times.txt"):
        tid = st["trip_id"]
        if tid in agency_trips:
            used_stops.add(st["stop_id"])
        if tid not in repr_trip:
            continue
        try:
            seq = int(st["stop_sequence"])
        except ValueError:
            continue
        a = secs(st.get("arrival_time"))
        d = secs(st.get("departure_time"))
        st_by_trip[tid].append((seq, st["stop_id"], a, d))

    st_rows = []
    for tid, rows in st_by_trip.items():
        rows.sort()
        last = 0
        for seq, sid, a, d in rows:
            a = a if a is not None else (d if d is not None else last)
            d = d if d is not None else a
            last = a
            used_stops.add(sid)
            st_rows.append(
                f"({q(PREFIX+tid)},{q(PREFIX+sid)},make_interval(secs => {a}),"
                f"make_interval(secs => {d}),{seq})")
    print(f"stop_times: {len(st_rows)}  stops utilisés: {len(used_stops)}")

    # 4. stops (uniquement ceux desservis par une course représentative)
    stop_rows = []
    for s in reader(zf, "stops.txt"):
        if s["stop_id"] not in used_stops:
            continue
        try:
            la = float(s["stop_lat"]); lo = float(s["stop_lon"])
        except (ValueError, KeyError):
            continue
        wb = (s.get("wheelchair_boarding") or "0").strip() or "0"
        stop_rows.append(
            f"({q(PREFIX+s['stop_id'])},{q(s.get('stop_name'))},{int(wb) if wb.isdigit() else 0},"
            f"ST_SetSRID(ST_Point({lo}, {la}), 4326),0,ARRAY['bus']::TEXT[])")

    # 5. shapes des courses représentatives
    keep_shapes = {sid for (_, _, sid) in repr_trip.values() if sid}
    shape_pts = defaultdict(list)
    try:
        for sh in reader(zf, "shapes.txt"):
            if sh["shape_id"] in keep_shapes:
                shape_pts[sh["shape_id"]].append(
                    (int(sh["shape_pt_sequence"]), float(sh["shape_pt_lat"]), float(sh["shape_pt_lon"])))
    except KeyError:
        pass
    shape_rows = []
    for sid, pts in shape_pts.items():
        pts.sort()
        for seq, la, lo in pts:
            shape_rows.append(
                f"({q(PREFIX+sid)},{seq},ST_SetSRID(ST_Point({lo}, {la}), 4326))")
    print(f"shapes: {len(keep_shapes)}  points: {len(shape_rows)}")

    # rows routes / trips
    route_rows = []
    for rid, r in routes.items():
        rtype = (r.get("route_type") or "3").strip() or "3"
        color = (r.get("route_color") or "").strip()
        route_rows.append(
            f"({q(PREFIX+rid)},{q((r.get('route_short_name') or rid).strip())},"
            f"{q((r.get('route_long_name') or '').strip())},{int(rtype)},"
            f"{q(color) if color else 'NULL'},{q(NETWORK_ID)}::uuid)")

    trip_rows = []
    for tid, (rid, did, sid) in repr_trip.items():
        trip_rows.append(
            f"({q(PREFIX+tid)},{q(PREFIX+rid)},{q(PREFIX+'svc')},"
            f"{q(PREFIX+sid) if sid else 'NULL'},{int(did)})")

    # -----------------------------------------------------------------------
    # Écriture du fichier SQL
    # -----------------------------------------------------------------------
    with open(out, "w", encoding="utf-8") as f:
        f.write(f"""-- Import du réseau Aléop (interurbain régional Pays de la Loire) — {agency}
-- Généré par tool/build_aleop_supabase_migration.py (NE PAS éditer à la main).
-- Alimente la carte immersive (RPC get_nearby_stops / get_stop_serving_lines).
-- Idempotent : purge d'abord les données Aléop existantes puis recharge.
-- Périmètre réduit : une course représentative par (ligne, sens).

BEGIN;

-- 0. Réseau
INSERT INTO public.networks (id, name, code)
VALUES ({q(NETWORK_ID)}::uuid, {q(NETWORK_NAME)}, {q(NETWORK_CODE)})
ON CONFLICT (code) DO NOTHING;

-- Purge ré-exécution (les stops/mapping tombent en cascade via network_id ;
-- les tables GTFS globales sont filtrées par le préfixe ALEOP:).
DELETE FROM public.stops    WHERE network_id = {q(NETWORK_ID)}::uuid;
DELETE FROM public.stations WHERE network_id = {q(NETWORK_ID)}::uuid;
DELETE FROM gtfs_stop_times WHERE trip_id  LIKE 'ALEOP:%';
DELETE FROM gtfs_trips      WHERE trip_id  LIKE 'ALEOP:%';
DELETE FROM gtfs_shapes     WHERE shape_id LIKE 'ALEOP:%';
DELETE FROM gtfs_stops      WHERE stop_id  LIKE 'ALEOP:%';
DELETE FROM gtfs_routes     WHERE network_id = {q(NETWORK_ID)}::uuid;

""")
        f.write("-- 1. gtfs_routes\n")
        emit_insert(f, "gtfs_routes",
                    ["route_id", "route_short_name", "route_long_name",
                     "route_type", "route_color", "network_id"], route_rows)
        f.write("\n-- 2. gtfs_stops (arrêts physiques, mode bus)\n")
        emit_insert(f, "gtfs_stops",
                    ["stop_id", "stop_name", "wheelchair_boarding", "geom",
                     "location_type", "transport_modes"], stop_rows)
        f.write("\n-- 3. gtfs_trips (courses représentatives)\n")
        emit_insert(f, "gtfs_trips",
                    ["trip_id", "route_id", "service_id", "shape_id", "direction_id"], trip_rows)
        f.write("\n-- 4. gtfs_shapes\n")
        emit_insert(f, "gtfs_shapes", ["shape_id", "shape_pt_sequence", "geom"], shape_rows)
        f.write("\n-- 5. gtfs_stop_times\n")
        emit_insert(f, "gtfs_stop_times",
                    ["trip_id", "stop_id", "arrival_time", "departure_time", "stop_sequence"], st_rows)

        # 6. Matérialisation stations/stops/mapping (adapté de 012, scopé ALEOP:%)
        f.write(f"""
-- 6. Matérialisation stations / stops / gtfs_stop_mapping (scopé ALEOP:%)
DO $$
DECLARE v_network_id UUID;
BEGIN
    SELECT id INTO v_network_id FROM public.networks WHERE code = {q(NETWORK_CODE)} LIMIT 1;

    -- Stations : une par nom normalisé (parmi les arrêts physiques Aléop)
    INSERT INTO public.stations (network_id, name, commune, latitude_center, longitude_center, status)
    SELECT DISTINCT ON (public.normalize_station_name(gs.stop_name))
        v_network_id, gs.stop_name, gs.commune,
        ST_Y(gs.geom::geometry), ST_X(gs.geom::geometry), 'active'
    FROM public.gtfs_stops gs
    WHERE gs.stop_id LIKE 'ALEOP:%' AND COALESCE(gs.location_type, 0) = 0
    ORDER BY public.normalize_station_name(gs.stop_name), gs.stop_id
    ON CONFLICT (network_id, name_normalized) DO NOTHING;

    -- Recentrer chaque station sur le centroïde de ses arrêts physiques
    UPDATE public.stations st
    SET latitude_center = sub.clat, longitude_center = sub.clng
    FROM (
        SELECT public.normalize_station_name(gs.stop_name) AS nn,
               AVG(ST_Y(gs.geom::geometry)) AS clat, AVG(ST_X(gs.geom::geometry)) AS clng
        FROM public.gtfs_stops gs
        WHERE gs.stop_id LIKE 'ALEOP:%' AND COALESCE(gs.location_type, 0) = 0
        GROUP BY public.normalize_station_name(gs.stop_name)
    ) sub
    WHERE st.network_id = v_network_id AND st.name_normalized = sub.nn;

    -- Stops : arrêts physiques Aléop, rattachés à leur station
    INSERT INTO public.stops (
        network_id, station_id, code, source, gtfs_source_id, name,
        latitude, longitude, geom, transport_mode, is_accessible, status)
    SELECT
        v_network_id, st.id, gs.stop_id, 'gtfs'::public.stop_source, gs.stop_id, gs.stop_name,
        ST_Y(gs.geom::geometry), ST_X(gs.geom::geometry), gs.geom,
        'bus'::public.stop_transport_mode, COALESCE(gs.wheelchair_boarding, 0) = 1, 'active'
    FROM public.gtfs_stops gs
    JOIN public.stations st
        ON st.network_id = v_network_id
       AND st.name_normalized = public.normalize_station_name(gs.stop_name)
    WHERE gs.stop_id LIKE 'ALEOP:%' AND COALESCE(gs.location_type, 0) = 0
    ON CONFLICT (network_id, code) DO NOTHING;

    -- Mapping GTFS → stops.id
    INSERT INTO public.gtfs_stop_mapping (network_id, gtfs_stop_id, stop_id)
    SELECT v_network_id, s.code, s.id
    FROM public.stops s
    WHERE s.network_id = v_network_id AND s.source = 'gtfs'
    ON CONFLICT DO NOTHING;
END $$;

-- 7. Vérifications (scopées au réseau Aléop)
DO $$
DECLARE v_network_id UUID; v_dup INT; v_orphan INT; v_map INT; v_stops INT;
BEGIN
    SELECT id INTO v_network_id FROM public.networks WHERE code = {q(NETWORK_CODE)} LIMIT 1;

    SELECT COUNT(*) INTO v_dup FROM (
        SELECT 1 FROM public.stations WHERE network_id = v_network_id
        GROUP BY name_normalized HAVING COUNT(*) > 1) x;
    IF v_dup > 0 THEN RAISE EXCEPTION 'Aléop : % doublons de station', v_dup; END IF;

    SELECT COUNT(*) INTO v_orphan FROM public.stops
        WHERE network_id = v_network_id AND station_id IS NULL;
    IF v_orphan > 0 THEN RAISE EXCEPTION 'Aléop : % arrêts sans station', v_orphan; END IF;

    SELECT COUNT(*) INTO v_map FROM public.gtfs_stop_mapping WHERE network_id = v_network_id;
    SELECT COUNT(*) INTO v_stops FROM public.stops WHERE network_id = v_network_id AND source = 'gtfs';
    IF v_map <> v_stops THEN RAISE EXCEPTION 'Aléop : mapping % != stops %', v_map, v_stops; END IF;

    RAISE NOTICE 'Aléop importé : % stops, % mapping', v_stops, v_map;
END $$;

-- 8. Visibilité publique (anon) : la carte immersive est publique et
--    get_nearby_stops tourne en SECURITY INVOKER. Les politiques
--    *_select_pilot_public limitaient l'anon au seul réseau naolib ; on les
--    étend au réseau Aléop (les tables gtfs_* sont déjà en lecture publique,
--    et get_stop_serving_lines/served_routes sont SECURITY DEFINER).
ALTER POLICY stops_select_pilot_public ON public.stops
    USING (network_id IN (
        '00000000-0000-4000-8000-000000000001'::uuid,
        """ + f"'{NETWORK_ID}'::uuid));\n" + """ALTER POLICY stations_select_pilot_public ON public.stations
    USING (network_id IN (
        '00000000-0000-4000-8000-000000000001'::uuid,
        """ + f"'{NETWORK_ID}'::uuid));\n" + """
-- Le pont GTFS→stops.id (gtfs_stop_mapping) n'avait pas de politique anon :
-- les correspondances de la carte publique (mapGtfsIdsToUuidStops) tombaient
-- à vide. On l'ouvre en lecture anon pour les réseaux publics (cohérent avec
-- les autres tables gtfs_* déjà publiques).
DROP POLICY IF EXISTS gtfs_stop_mapping_select_pilot_public ON public.gtfs_stop_mapping;
CREATE POLICY gtfs_stop_mapping_select_pilot_public ON public.gtfs_stop_mapping
    FOR SELECT TO anon
    USING (network_id IN (
        '00000000-0000-4000-8000-000000000001'::uuid,
        """ + f"'{NETWORK_ID}'::uuid));\n" + """
COMMIT;
""")

    import os
    print(f"\n✓ {out} ({os.path.getsize(out)/1_048_576:.2f} Mo)")


if __name__ == "__main__":
    main()
