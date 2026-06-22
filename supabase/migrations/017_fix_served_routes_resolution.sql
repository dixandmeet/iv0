-- Corrige la résolution GTFS des lignes desservies (mapping manquant, surcharge TEXT[])

DROP FUNCTION IF EXISTS public.get_stops_served_routes(TEXT[]);
DROP FUNCTION IF EXISTS public.get_stop_serving_lines(TEXT);
DROP FUNCTION IF EXISTS public.get_stop_departures(TEXT, INTEGER);

CREATE OR REPLACE FUNCTION public.resolve_gtfs_stop_id(p_stop_id UUID)
RETURNS TEXT AS $$
    SELECT COALESCE(
        (
            SELECT m.gtfs_stop_id
            FROM public.gtfs_stop_mapping m
            WHERE m.stop_id = p_stop_id
            LIMIT 1
        ),
        (
            SELECT NULLIF(TRIM(s.gtfs_source_id), '')
            FROM public.stops s
            WHERE s.id = p_stop_id
            LIMIT 1
        ),
        (
            SELECT s.code
            FROM public.stops s
            WHERE s.id = p_stop_id
              AND s.source = 'gtfs'
            LIMIT 1
        )
    );
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION public.get_stops_served_routes(p_stop_ids UUID[])
RETURNS TABLE (
    stop_id UUID,
    route_id TEXT,
    route_short_name TEXT,
    route_color TEXT
) AS $$
DECLARE
    v_radius_m DOUBLE PRECISION := 80;
BEGIN
    RETURN QUERY
    WITH gtfs_routes AS (
        SELECT DISTINCT
            s.id AS stop_id,
            r.route_id,
            r.route_short_name,
            r.route_color
        FROM public.stops s
        CROSS JOIN LATERAL (
            SELECT public.resolve_gtfs_stop_id(s.id) AS gtfs_stop_id
        ) resolved
        JOIN gtfs_stop_times st ON st.stop_id = resolved.gtfs_stop_id
        JOIN gtfs_trips t ON t.trip_id = st.trip_id
        JOIN gtfs_routes r ON r.route_id = t.route_id
        WHERE s.id = ANY(p_stop_ids)
          AND resolved.gtfs_stop_id IS NOT NULL
    ),
    geo_routes AS (
        SELECT DISTINCT
            s.id AS stop_id,
            r.route_id,
            r.route_short_name,
            r.route_color
        FROM public.stops s
        JOIN gtfs_shapes sh ON ST_DWithin(s.geom::geography, sh.geom::geography, v_radius_m)
        JOIN gtfs_trips t ON t.shape_id = sh.shape_id
        JOIN gtfs_routes r ON r.route_id = t.route_id
        WHERE s.id = ANY(p_stop_ids)
    )
    SELECT gr.stop_id, gr.route_id, gr.route_short_name, gr.route_color FROM gtfs_routes gr
    UNION
    SELECT geo.stop_id, geo.route_id, geo.route_short_name, geo.route_color
    FROM geo_routes geo
    WHERE NOT EXISTS (
        SELECT 1
        FROM gtfs_routes gr
        WHERE gr.stop_id = geo.stop_id
          AND gr.route_id = geo.route_id
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

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

    IF v_gtfs_stop_id IS NOT NULL THEN
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
            RETURN;
        END IF;
    END IF;

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
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
