-- Phase 0 — Sessions conducteur et géolocalisation certifiée

CREATE TABLE IF NOT EXISTS driver_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    route_id TEXT REFERENCES gtfs_routes(route_id) ON DELETE SET NULL,
    direction_id INTEGER,
    trip_id TEXT REFERENCES gtfs_trips(trip_id) ON DELETE SET NULL,
    headsign TEXT,
    detection_mode TEXT NOT NULL DEFAULT 'auto'
        CHECK (detection_mode IN ('auto', 'manual', 'corrected')),
    detection_confidence INTEGER CHECK (detection_confidence BETWEEN 0 AND 100),
    status TEXT NOT NULL DEFAULT 'detecting'
        CHECK (status IN ('detecting', 'active', 'paused', 'ended')),
    started_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    confirmed_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_driver_sessions_driver ON driver_sessions(driver_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_sessions_status ON driver_sessions(status) WHERE status IN ('detecting', 'active', 'paused');

CREATE TABLE IF NOT EXISTS driver_location_events (
    id BIGSERIAL PRIMARY KEY,
    session_id UUID REFERENCES driver_sessions(id) ON DELETE CASCADE NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL,
    speed NUMERIC,
    heading NUMERIC,
    accuracy NUMERIC,
    route_id TEXT,
    confidence INTEGER CHECK (confidence BETWEEN 0 AND 100),
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_driver_location_session_time
    ON driver_location_events(session_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_driver_location_geom
    ON driver_location_events USING gist(geom);

-- FK différée app_settings → driver_sessions
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'app_settings_last_driver_session_fkey'
    ) THEN
        ALTER TABLE app_settings
            ADD CONSTRAINT app_settings_last_driver_session_fkey
            FOREIGN KEY (last_driver_session_id) REFERENCES driver_sessions(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Corrélation position + horaire théorique pour identifier le trip en service
CREATE OR REPLACE FUNCTION public.match_probable_trip(
    p_route_id TEXT,
    p_direction_id INTEGER,
    p_lat DOUBLE PRECISION,
    p_lon DOUBLE PRECISION,
    p_at TIMESTAMPTZ DEFAULT NOW()
)
RETURNS TABLE (
    trip_id TEXT,
    headsign TEXT,
    confidence INTEGER
) AS $$
DECLARE
    user_geom GEOMETRY(Point, 4326);
    time_of_day INTERVAL;
BEGIN
    user_geom := ST_SetSRID(ST_Point(p_lon, p_lat), 4326);
    time_of_day := p_at::TIME;

    RETURN QUERY
    WITH nearby_stops AS (
        SELECT s.stop_id, s.stop_name,
               ST_Distance(s.geom::geography, user_geom::geography) AS dist_m
        FROM gtfs_stops s
        WHERE ST_DWithin(s.geom::geography, user_geom::geography, 120)
        ORDER BY dist_m
        LIMIT 5
    ),
    candidate_trips AS (
        SELECT DISTINCT t.trip_id, t.direction_id, ns.stop_name AS headsign_guess
        FROM gtfs_trips t
        JOIN gtfs_stop_times st ON st.trip_id = t.trip_id
        JOIN nearby_stops ns ON ns.stop_id = st.stop_id
        WHERE t.route_id = p_route_id
          AND (p_direction_id IS NULL OR t.direction_id = p_direction_id)
          AND st.departure_time BETWEEN time_of_day - INTERVAL '10 minutes'
                                    AND time_of_day + INTERVAL '10 minutes'
    )
    SELECT
        ct.trip_id,
        ct.headsign_guess,
        GREATEST(50, LEAST(100, 100 - (
            SELECT MIN(dist_m)::INTEGER FROM nearby_stops
        )))::INTEGER AS confidence
    FROM candidate_trips ct
    ORDER BY confidence DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- Démarrage automatique de session conducteur à partir de points GPS récents
CREATE OR REPLACE FUNCTION public.start_driver_session_auto(
    p_driver_id UUID,
    p_points JSONB
)
RETURNS JSONB AS $$
DECLARE
    last_point JSONB;
    lat DOUBLE PRECISION;
    lon DOUBLE PRECISION;
    heading DOUBLE PRECISION;
    speed DOUBLE PRECISION;
    best_route_id TEXT;
    best_direction_id INTEGER;
    best_confidence INTEGER;
    best_shape_id TEXT;
    trip_rec RECORD;
    new_session_id UUID;
BEGIN
    IF jsonb_array_length(p_points) < 1 THEN
        RETURN jsonb_build_object('status', 'unknown', 'reason', 'no_points');
    END IF;

    last_point := p_points->(jsonb_array_length(p_points) - 1);
    lat := (last_point->>'lat')::DOUBLE PRECISION;
    lon := (last_point->>'lon')::DOUBLE PRECISION;
    heading := COALESCE((last_point->>'heading')::DOUBLE PRECISION, 0);
    speed := COALESCE((last_point->>'speed')::DOUBLE PRECISION, 0);

    SELECT d.route_id, d.direction_id, d.confidence, d.shape_id
    INTO best_route_id, best_direction_id, best_confidence, best_shape_id
    FROM detect_probable_route(lat, lon, heading, speed) d
    ORDER BY d.confidence DESC
    LIMIT 1;

    IF best_route_id IS NULL OR best_confidence IS NULL THEN
        RETURN jsonb_build_object('status', 'unknown', 'confidence', 0);
    END IF;

    IF best_confidence >= 80 AND speed BETWEEN 2.0 AND 25.0 THEN
        SELECT * INTO trip_rec
        FROM match_probable_trip(best_route_id, best_direction_id, lat, lon);

        INSERT INTO driver_sessions (
            driver_id, route_id, direction_id, trip_id, headsign,
            detection_mode, detection_confidence, status, confirmed_at
        ) VALUES (
            p_driver_id, best_route_id, best_direction_id,
            trip_rec.trip_id, trip_rec.headsign,
            'auto', best_confidence, 'active', NOW()
        )
        RETURNING id INTO new_session_id;

        RETURN jsonb_build_object(
            'status', 'confirmed',
            'session_id', new_session_id,
            'route_id', best_route_id,
            'direction_id', best_direction_id,
            'trip_id', trip_rec.trip_id,
            'headsign', trip_rec.headsign,
            'confidence', best_confidence
        );
    END IF;

    IF best_confidence >= 50 THEN
        RETURN jsonb_build_object(
            'status', 'ambiguous',
            'route_id', best_route_id,
            'direction_id', best_direction_id,
            'confidence', best_confidence
        );
    END IF;

    RETURN jsonb_build_object('status', 'unknown', 'confidence', best_confidence);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
