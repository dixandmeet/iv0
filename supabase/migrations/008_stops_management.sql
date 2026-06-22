-- Gestion opérationnelle des arrêts (dashboard régulateur / admin)

-- ---------------------------------------------------------------------------
-- Extension gtfs_stops
-- ---------------------------------------------------------------------------
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive', 'works', 'relocated'));
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS commune TEXT;
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS tariff_zone TEXT;
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS platform_count SMALLINT NOT NULL DEFAULT 1;
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS transport_modes TEXT[] DEFAULT ARRAY['bus']::TEXT[];
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL;
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS updated_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_gtfs_stops_status ON gtfs_stops(status);
CREATE INDEX IF NOT EXISTS idx_gtfs_stops_commune ON gtfs_stops(commune);
CREATE INDEX IF NOT EXISTS idx_gtfs_stops_name ON gtfs_stops(stop_name);

-- Backfill commune par défaut
UPDATE gtfs_stops SET commune = 'Nantes' WHERE commune IS NULL;

-- ---------------------------------------------------------------------------
-- Journal d'audit arrêts
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS stop_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stop_id TEXT REFERENCES gtfs_stops(stop_id) ON DELETE CASCADE NOT NULL,
    action TEXT NOT NULL CHECK (action IN (
        'created', 'updated', 'disabled', 'relocated', 'imported'
    )),
    changes JSONB NOT NULL DEFAULT '{}',
    performed_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_stop_audit_log_stop ON stop_audit_log(stop_id, created_at DESC);

ALTER TABLE stop_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS stop_audit_log_select_staff ON stop_audit_log;
CREATE POLICY stop_audit_log_select_staff ON stop_audit_log
    FOR SELECT TO authenticated
    USING (public.is_staff());

DROP POLICY IF EXISTS stop_audit_log_insert_staff ON stop_audit_log;
CREATE POLICY stop_audit_log_insert_staff ON stop_audit_log
    FOR INSERT TO authenticated
    WITH CHECK (public.has_role(ARRAY['admin', 'regulator']));

-- ---------------------------------------------------------------------------
-- RLS écriture gtfs_stops (admin + régulateur)
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS gtfs_stops_manage_staff ON gtfs_stops;
CREATE POLICY gtfs_stops_manage_staff ON gtfs_stops
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['admin', 'regulator']))
    WITH CHECK (public.has_role(ARRAY['admin', 'regulator']));

-- ---------------------------------------------------------------------------
-- RPC : arrêts proches
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_nearby_stops(
    p_lng DOUBLE PRECISION,
    p_lat DOUBLE PRECISION,
    p_radius_m DOUBLE PRECISION DEFAULT 300,
    p_exclude_stop_id TEXT DEFAULT NULL
)
RETURNS TABLE (
    stop_id TEXT,
    stop_name TEXT,
    status TEXT,
    distance_m DOUBLE PRECISION,
    geom JSONB
) AS $$
DECLARE
    origin GEOMETRY;
BEGIN
    origin := ST_SetSRID(ST_Point(p_lng, p_lat), 4326);
    RETURN QUERY
    SELECT
        s.stop_id,
        s.stop_name,
        s.status,
        ST_Distance(s.geom::geography, origin::geography) AS distance_m,
        ST_AsGeoJSON(s.geom)::JSONB AS geom
    FROM gtfs_stops s
    WHERE ST_DWithin(s.geom::geography, origin::geography, p_radius_m)
      AND (p_exclude_stop_id IS NULL OR s.stop_id <> p_exclude_stop_id)
    ORDER BY distance_m
    LIMIT 20;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- RPC : lignes desservant un arrêt
-- ---------------------------------------------------------------------------
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
BEGIN
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
            st.trip_id,
            st.stop_sequence,
            st.stop_id,
            s.stop_name,
            st.arrival_time
        FROM gtfs_stop_times st
        JOIN gtfs_stops s ON s.stop_id = st.stop_id
        WHERE st.trip_id IN (SELECT trip_id FROM stop_trips)
    ),
    first_times AS (
        SELECT
            st.trip_id,
            MIN(st.arrival_time) AS first_arrival
        FROM gtfs_stop_times st
        WHERE st.trip_id IN (SELECT trip_id FROM stop_trips)
        GROUP BY st.trip_id
    )
    SELECT
        r.route_id,
        r.route_short_name,
        r.route_long_name,
        r.route_type,
        r.route_color,
        st.direction_id,
        st.trip_id,
        st.stop_sequence,
        prev.stop_id AS prev_stop_id,
        prev.stop_name AS prev_stop_name,
        nxt.stop_id AS next_stop_id,
        nxt.stop_name AS next_stop_name,
        to_char(st.arrival_time, 'HH24:MI') AS arrival_time,
        EXTRACT(EPOCH FROM (st.arrival_time - ft.first_arrival))::INTEGER AS time_from_terminus_seconds
    FROM stop_trips st
    JOIN gtfs_routes r ON r.route_id = st.route_id
    JOIN first_times ft ON ft.trip_id = st.trip_id
    LEFT JOIN with_neighbors prev
        ON prev.trip_id = st.trip_id AND prev.stop_sequence = st.stop_sequence - 1
    LEFT JOIN with_neighbors nxt
        ON nxt.trip_id = st.trip_id AND nxt.stop_sequence = st.stop_sequence + 1
    ORDER BY r.route_short_name NULLS LAST, st.direction_id, st.stop_sequence;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- RPC : prochains passages à un arrêt
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_stop_departures(
    p_stop_id TEXT,
    p_limit INTEGER DEFAULT 20
)
RETURNS TABLE (
    trip_id TEXT,
    route_id TEXT,
    route_short_name TEXT,
    route_color TEXT,
    direction_id INTEGER,
    theoretical_time TEXT,
    stop_sequence INTEGER
) AS $$
DECLARE
    now_interval INTERVAL;
BEGIN
    now_interval := LOCALTIME::INTERVAL;
    RETURN QUERY
    SELECT
        st.trip_id,
        t.route_id,
        r.route_short_name,
        r.route_color,
        t.direction_id,
        to_char(st.arrival_time, 'HH24:MI') AS theoretical_time,
        st.stop_sequence
    FROM gtfs_stop_times st
    JOIN gtfs_trips t ON t.trip_id = st.trip_id
    JOIN gtfs_routes r ON r.route_id = t.route_id
    WHERE st.stop_id = p_stop_id
      AND st.arrival_time >= now_interval
    ORDER BY st.arrival_time
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- Trigger updated_at
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.touch_gtfs_stop_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_gtfs_stops_updated ON gtfs_stops;
CREATE TRIGGER on_gtfs_stops_updated
    BEFORE UPDATE ON gtfs_stops
    FOR EACH ROW EXECUTE FUNCTION public.touch_gtfs_stop_updated_at();
