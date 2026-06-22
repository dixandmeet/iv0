-- Arrêts opérationnels : stations GTFS parentes, modes de transport, proximité shapes

ALTER TABLE gtfs_stops
    ADD COLUMN IF NOT EXISTS location_type SMALLINT NOT NULL DEFAULT 0;

-- Station GTFS parente (ex. RAZA) quand des quais numérotés existent (RAZA1, RAZA2…)
UPDATE gtfs_stops parent
SET location_type = 1
WHERE parent.stop_id !~ '[0-9]$'
  AND EXISTS (
    SELECT 1
    FROM gtfs_stops child
    WHERE child.stop_name = parent.stop_name
      AND child.stop_id ~ ('^' || parent.stop_id || '[0-9]+$')
  );

-- Modes dérivés des tracés à 80 m (évite d'attribuer toutes les lignes du carrefour)
UPDATE gtfs_stops s
SET transport_modes = COALESCE(
    (
        SELECT ARRAY_AGG(DISTINCT mode ORDER BY mode)
        FROM (
            SELECT CASE r.route_type
                WHEN 0 THEN 'tram'
                WHEN 4 THEN 'navibus'
                WHEN 2 THEN 'train'
                ELSE 'bus'
            END AS mode
            FROM gtfs_shapes sh
            JOIN gtfs_trips t ON t.shape_id = sh.shape_id
            JOIN gtfs_routes r ON r.route_id = t.route_id
            WHERE ST_DWithin(s.geom::geography, sh.geom::geography, 80)
        ) modes
    ),
    ARRAY['bus']::TEXT[]
);

-- Rayon de repli réduit : 350 m regroupait tout un carrefour (ex. 6× Ranzay)
CREATE OR REPLACE FUNCTION public.get_stop_serving_lines(p_stop_id TEXT)
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
    v_has_stop_times BOOLEAN;
    v_radius_m DOUBLE PRECISION := 80;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM gtfs_stop_times st WHERE st.stop_id = p_stop_id LIMIT 1
    ) INTO v_has_stop_times;

    IF v_has_stop_times THEN
        RETURN QUERY
        WITH stop_trips AS (
            SELECT DISTINCT ON (t.route_id, t.direction_id, st.trip_id)
                t.route_id,
                t.direction_id,
                st.trip_id,
                st.stop_sequence,
                st.arrival_time
            FROM gtfs_stop_times st
            JOIN gtfs_trips t ON t.trip_id = st.trip_id
            WHERE st.stop_id = p_stop_id
            ORDER BY t.route_id, t.direction_id, st.trip_id, st.stop_sequence
        ),
        with_neighbors AS (
            SELECT
                st2.trip_id,
                st2.stop_sequence,
                st2.stop_id,
                gs.stop_name,
                st2.arrival_time
            FROM gtfs_stop_times st2
            JOIN gtfs_stops gs ON gs.stop_id = st2.stop_id
            WHERE st2.trip_id IN (SELECT stp.trip_id FROM stop_trips stp)
        ),
        first_times AS (
            SELECT
                st3.trip_id,
                MIN(st3.arrival_time) AS first_arrival
            FROM gtfs_stop_times st3
            WHERE st3.trip_id IN (SELECT stp.trip_id FROM stop_trips stp)
            GROUP BY st3.trip_id
        )
        SELECT
            r.route_id,
            r.route_short_name,
            r.route_long_name,
            r.route_type,
            r.route_color,
            stp.direction_id,
            stp.trip_id,
            stp.stop_sequence,
            prev.stop_id AS prev_stop_id,
            prev.stop_name AS prev_stop_name,
            nxt.stop_id AS next_stop_id,
            nxt.stop_name AS next_stop_name,
            to_char(stp.arrival_time, 'HH24:MI') AS arrival_time,
            EXTRACT(EPOCH FROM (stp.arrival_time - ft.first_arrival))::INTEGER AS time_from_terminus_seconds
        FROM stop_trips stp
        JOIN gtfs_routes r ON r.route_id = stp.route_id
        JOIN first_times ft ON ft.trip_id = stp.trip_id
        LEFT JOIN with_neighbors prev
            ON prev.trip_id = stp.trip_id AND prev.stop_sequence = stp.stop_sequence - 1
        LEFT JOIN with_neighbors nxt
            ON nxt.trip_id = stp.trip_id AND nxt.stop_sequence = stp.stop_sequence + 1
        ORDER BY r.route_short_name NULLS LAST, stp.direction_id, stp.stop_sequence;
    ELSE
        RETURN QUERY
        SELECT DISTINCT ON (r.route_id, COALESCE(t.direction_id, 0))
            r.route_id,
            r.route_short_name,
            r.route_long_name,
            r.route_type,
            r.route_color,
            COALESCE(t.direction_id, 0)::INTEGER,
            t.trip_id,
            NULL::INTEGER,
            NULL::TEXT,
            NULL::TEXT,
            NULL::TEXT,
            NULL::TEXT,
            NULL::TEXT,
            NULL::INTEGER
        FROM gtfs_stops s
        JOIN gtfs_shapes sh ON ST_DWithin(s.geom::geography, sh.geom::geography, v_radius_m)
        JOIN gtfs_trips t ON t.shape_id = sh.shape_id
        JOIN gtfs_routes r ON r.route_id = t.route_id
        WHERE s.stop_id = p_stop_id
        ORDER BY r.route_id, COALESCE(t.direction_id, 0), r.route_short_name NULLS LAST;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_stops_served_routes(p_stop_ids TEXT[])
RETURNS TABLE (
    stop_id TEXT,
    route_id TEXT,
    route_short_name TEXT,
    route_color TEXT
) AS $$
DECLARE
    v_radius_m DOUBLE PRECISION := 80;
BEGIN
    IF EXISTS (SELECT 1 FROM gtfs_stop_times LIMIT 1) THEN
        RETURN QUERY
        SELECT DISTINCT
            st.stop_id,
            r.route_id,
            r.route_short_name,
            r.route_color
        FROM gtfs_stop_times st
        JOIN gtfs_trips t ON t.trip_id = st.trip_id
        JOIN gtfs_routes r ON r.route_id = t.route_id
        WHERE st.stop_id = ANY(p_stop_ids);
    ELSE
        RETURN QUERY
        SELECT DISTINCT
            s.stop_id,
            r.route_id,
            r.route_short_name,
            r.route_color
        FROM gtfs_stops s
        JOIN gtfs_shapes sh ON ST_DWithin(s.geom::geography, sh.geom::geography, v_radius_m)
        JOIN gtfs_trips t ON t.shape_id = sh.shape_id
        JOIN gtfs_routes r ON r.route_id = t.route_id
        WHERE s.stop_id = ANY(p_stop_ids);
    END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
