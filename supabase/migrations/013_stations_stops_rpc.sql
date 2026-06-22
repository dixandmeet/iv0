-- RPC Stations / Arrêts (v3) — remplace les RPC basées sur gtfs_stops

-- Helper : résoudre gtfs_stop_id depuis stop UUID
CREATE OR REPLACE FUNCTION public.resolve_gtfs_stop_id(p_stop_id UUID)
RETURNS TEXT AS $$
    SELECT m.gtfs_stop_id
    FROM public.gtfs_stop_mapping m
    WHERE m.stop_id = p_stop_id
    LIMIT 1;
$$ LANGUAGE sql STABLE;

-- ---------------------------------------------------------------------------
-- Recherche stations
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_stations(
    p_network_id UUID DEFAULT NULL,
    p_query TEXT DEFAULT '',
    p_audience TEXT DEFAULT 'staff',
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    name TEXT,
    commune TEXT,
    status TEXT,
    latitude_center DOUBLE PRECISION,
    longitude_center DOUBLE PRECISION,
    stop_count BIGINT
) AS $$
DECLARE
    v_network_id UUID;
    v_q TEXT;
BEGIN
    v_network_id := COALESCE(
        p_network_id,
        (SELECT n.id FROM public.networks n WHERE n.code = 'naolib-nantes' LIMIT 1)
    );
    v_q := public.normalize_station_name(p_query);

    RETURN QUERY
    SELECT
        st.id,
        st.name,
        st.commune,
        st.status,
        st.latitude_center,
        st.longitude_center,
        COUNT(sp.id) AS stop_count
    FROM public.stations st
    LEFT JOIN public.stops sp ON sp.station_id = st.id
    WHERE st.network_id = v_network_id
      AND (p_audience <> 'passenger' OR st.status = 'active')
      AND (
          v_q = '' OR st.name_normalized LIKE '%' || v_q || '%'
          OR st.name ILIKE '%' || trim(p_query) || '%'
      )
    GROUP BY st.id
    ORDER BY st.name
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- Détail station + arrêts
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_station_detail(
    p_station_id UUID,
    p_user_lat DOUBLE PRECISION DEFAULT NULL,
    p_user_lng DOUBLE PRECISION DEFAULT NULL,
    p_audience TEXT DEFAULT 'staff'
)
RETURNS JSONB AS $$
DECLARE
    v_station public.stations%ROWTYPE;
    v_origin GEOMETRY;
    v_result JSONB;
BEGIN
    SELECT * INTO v_station FROM public.stations WHERE id = p_station_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF p_audience = 'passenger' AND v_station.status <> 'active' THEN
        RETURN NULL;
    END IF;

    IF p_user_lat IS NOT NULL AND p_user_lng IS NOT NULL THEN
        v_origin := ST_SetSRID(ST_Point(p_user_lng, p_user_lat), 4326);
    END IF;

    SELECT jsonb_build_object(
        'station', jsonb_build_object(
            'id', v_station.id,
            'name', v_station.name,
            'description', v_station.description,
            'commune', v_station.commune,
            'status', v_station.status,
            'latitude_center', v_station.latitude_center,
            'longitude_center', v_station.longitude_center
        ),
        'stops', COALESCE((
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', sp.id,
                    'code', sp.code,
                    'name', sp.name,
                    'platform', sp.platform,
                    'transport_mode', sp.transport_mode::TEXT,
                    'is_accessible', sp.is_accessible,
                    'status', sp.status,
                    'latitude', sp.latitude,
                    'longitude', sp.longitude,
                    'source', sp.source::TEXT,
                    'distance_m', CASE
                        WHEN v_origin IS NOT NULL
                        THEN ST_Distance(sp.geom::geography, v_origin::geography)
                        ELSE NULL
                    END
                )
                ORDER BY sp.code
            )
            FROM public.stops sp
            WHERE sp.station_id = p_station_id
              AND (p_audience <> 'passenger' OR sp.status = 'active')
        ), '[]'::JSONB)
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- Lignes desservant un arrêt (UUID)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_stop_serving_lines(p_stop_id UUID)
RETURNS TABLE (
    route_id TEXT,
    route_short_name TEXT,
    route_long_name TEXT,
    route_type INTEGER,
    route_color TEXT,
    direction_id INTEGER,
    trip_id TEXT,
    stop_sequence INTEGER,
    prev_stop_id TEXT,
    prev_stop_name TEXT,
    next_stop_id TEXT,
    next_stop_name TEXT,
    arrival_time TEXT,
    time_from_terminus_seconds INTEGER
) AS $$
DECLARE
    v_gtfs_stop_id TEXT;
    v_has_stop_times BOOLEAN;
    v_radius_m DOUBLE PRECISION := 80;
BEGIN
    SELECT public.resolve_gtfs_stop_id(p_stop_id) INTO v_gtfs_stop_id;
    IF v_gtfs_stop_id IS NULL THEN
        RETURN;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM gtfs_stop_times st WHERE st.stop_id = v_gtfs_stop_id LIMIT 1
    ) INTO v_has_stop_times;

    IF v_has_stop_times THEN
        RETURN QUERY
        WITH stop_trips AS (
            SELECT DISTINCT ON (t.route_id, t.direction_id, st.trip_id)
                t.route_id, t.direction_id, st.trip_id, st.stop_sequence, st.arrival_time
            FROM gtfs_stop_times st
            JOIN gtfs_trips t ON t.trip_id = st.trip_id
            WHERE st.stop_id = v_gtfs_stop_id
            ORDER BY t.route_id, t.direction_id, st.trip_id, st.stop_sequence
        ),
        with_neighbors AS (
            SELECT st2.trip_id, st2.stop_sequence, st2.stop_id, gs.stop_name, st2.arrival_time
            FROM gtfs_stop_times st2
            JOIN gtfs_stops gs ON gs.stop_id = st2.stop_id
            WHERE st2.trip_id IN (SELECT stp.trip_id FROM stop_trips stp)
        ),
        first_times AS (
            SELECT st3.trip_id, MIN(st3.arrival_time) AS first_arrival
            FROM gtfs_stop_times st3
            WHERE st3.trip_id IN (SELECT stp.trip_id FROM stop_trips stp)
            GROUP BY st3.trip_id
        )
        SELECT
            r.route_id, r.route_short_name, r.route_long_name, r.route_type, r.route_color,
            stp.direction_id, stp.trip_id, stp.stop_sequence,
            prev.stop_id, prev.stop_name, nxt.stop_id, nxt.stop_name,
            to_char(stp.arrival_time, 'HH24:MI'),
            EXTRACT(EPOCH FROM (stp.arrival_time - ft.first_arrival))::INTEGER
        FROM stop_trips stp
        JOIN gtfs_routes r ON r.route_id = stp.route_id
        JOIN first_times ft ON ft.trip_id = stp.trip_id
        LEFT JOIN with_neighbors prev ON prev.trip_id = stp.trip_id AND prev.stop_sequence = stp.stop_sequence - 1
        LEFT JOIN with_neighbors nxt ON nxt.trip_id = stp.trip_id AND nxt.stop_sequence = stp.stop_sequence + 1
        ORDER BY r.route_short_name NULLS LAST, stp.direction_id, stp.stop_sequence;
    ELSE
        RETURN QUERY
        SELECT DISTINCT ON (r.route_id, COALESCE(t.direction_id, 0))
            r.route_id, r.route_short_name, r.route_long_name, r.route_type, r.route_color,
            COALESCE(t.direction_id, 0)::INTEGER, t.trip_id,
            NULL::INTEGER, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::INTEGER
        FROM public.stops s
        JOIN gtfs_shapes sh ON ST_DWithin(s.geom::geography, sh.geom::geography, v_radius_m)
        JOIN gtfs_trips t ON t.shape_id = sh.shape_id
        JOIN gtfs_routes r ON r.route_id = t.route_id
        WHERE s.id = p_stop_id
        ORDER BY r.route_id, COALESCE(t.direction_id, 0), r.route_short_name NULLS LAST;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Surcharge TEXT pour compatibilité temporaire des appels legacy (dépréciée)
CREATE OR REPLACE FUNCTION public.get_stop_serving_lines(p_stop_id TEXT)
RETURNS TABLE (
    route_id TEXT, route_short_name TEXT, route_long_name TEXT, route_type INTEGER,
    route_color TEXT, direction_id INTEGER, trip_id TEXT, stop_sequence INTEGER,
    prev_stop_id TEXT, prev_stop_name TEXT, next_stop_id TEXT, next_stop_name TEXT,
    arrival_time TEXT, time_from_terminus_seconds INTEGER
) AS $$
DECLARE v_uuid UUID;
BEGIN
    SELECT s.id INTO v_uuid FROM public.stops s WHERE s.code = p_stop_id LIMIT 1;
    IF v_uuid IS NULL THEN RETURN; END IF;
    RETURN QUERY SELECT * FROM public.get_stop_serving_lines(v_uuid);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- Badges lignes pour liste d'arrêts (UUID[])
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_stops_served_routes(p_stop_ids UUID[])
RETURNS TABLE (
    stop_id UUID,
    route_id TEXT,
    route_short_name TEXT,
    route_color TEXT
) AS $$
DECLARE v_radius_m DOUBLE PRECISION := 80;
BEGIN
    IF EXISTS (SELECT 1 FROM gtfs_stop_times LIMIT 1) THEN
        RETURN QUERY
        SELECT DISTINCT s.id, r.route_id, r.route_short_name, r.route_color
        FROM public.stops s
        JOIN public.gtfs_stop_mapping m ON m.stop_id = s.id
        JOIN gtfs_stop_times st ON st.stop_id = m.gtfs_stop_id
        JOIN gtfs_trips t ON t.trip_id = st.trip_id
        JOIN gtfs_routes r ON r.route_id = t.route_id
        WHERE s.id = ANY(p_stop_ids);
    ELSE
        RETURN QUERY
        SELECT DISTINCT s.id, r.route_id, r.route_short_name, r.route_color
        FROM public.stops s
        JOIN gtfs_shapes sh ON ST_DWithin(s.geom::geography, sh.geom::geography, v_radius_m)
        JOIN gtfs_trips t ON t.shape_id = sh.shape_id
        JOIN gtfs_routes r ON r.route_id = t.route_id
        WHERE s.id = ANY(p_stop_ids);
    END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- Prochains passages (UUID)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_stop_departures(
    p_stop_id UUID,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    trip_id TEXT, route_id TEXT, route_short_name TEXT, route_color TEXT,
    direction_id INTEGER, theoretical_time TEXT, stop_sequence INTEGER
) AS $$
DECLARE
    v_gtfs_stop_id TEXT;
    now_interval INTERVAL;
BEGIN
    SELECT public.resolve_gtfs_stop_id(p_stop_id) INTO v_gtfs_stop_id;
    IF v_gtfs_stop_id IS NULL THEN RETURN; END IF;

    now_interval := LOCALTIME::INTERVAL;
    RETURN QUERY
    SELECT st.trip_id, t.route_id, r.route_short_name, r.route_color,
           t.direction_id, to_char(st.arrival_time, 'HH24:MI'), st.stop_sequence
    FROM gtfs_stop_times st
    JOIN gtfs_trips t ON t.trip_id = st.trip_id
    JOIN gtfs_routes r ON r.route_id = t.route_id
    WHERE st.stop_id = v_gtfs_stop_id AND st.arrival_time >= now_interval
    ORDER BY st.arrival_time
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_stop_departures(p_stop_id TEXT, p_limit INTEGER DEFAULT 20)
RETURNS TABLE (
    trip_id TEXT, route_id TEXT, route_short_name TEXT, route_color TEXT,
    direction_id INTEGER, theoretical_time TEXT, stop_sequence INTEGER
) AS $$
DECLARE v_uuid UUID;
BEGIN
    SELECT s.id INTO v_uuid FROM public.stops s WHERE s.code = p_stop_id LIMIT 1;
    IF v_uuid IS NULL THEN RETURN; END IF;
    RETURN QUERY SELECT * FROM public.get_stop_departures(v_uuid, p_limit);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- Arrêts proches (UUID, filtre station active pour voyageur)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_nearby_stops(
    p_lng DOUBLE PRECISION,
    p_lat DOUBLE PRECISION,
    p_radius_m DOUBLE PRECISION DEFAULT 300,
    p_exclude_stop_id UUID DEFAULT NULL,
    p_audience TEXT DEFAULT 'staff'
)
RETURNS TABLE (
    stop_id UUID,
    stop_code TEXT,
    stop_name TEXT,
    station_id UUID,
    station_name TEXT,
    status TEXT,
    distance_m DOUBLE PRECISION,
    geom JSONB
) AS $$
DECLARE origin GEOMETRY;
BEGIN
    origin := ST_SetSRID(ST_Point(p_lng, p_lat), 4326);
    RETURN QUERY
    SELECT
        sp.id,
        sp.code,
        COALESCE(sp.name, st.name),
        st.id,
        st.name,
        sp.status,
        ST_Distance(sp.geom::geography, origin::geography),
        ST_AsGeoJSON(sp.geom)::JSONB
    FROM public.stops sp
    JOIN public.stations st ON st.id = sp.station_id
    WHERE ST_DWithin(sp.geom::geography, origin::geography, p_radius_m)
      AND (p_exclude_stop_id IS NULL OR sp.id <> p_exclude_stop_id)
      AND (p_audience <> 'passenger' OR (sp.status = 'active' AND st.status = 'active'))
    ORDER BY 7
    LIMIT 20;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Realtime subscription channel for new tables
-- (dashboard écoute stations + stops)
