-- Phase 0 — Couche temps réel unifiée + score de fiabilité

CREATE TABLE IF NOT EXISTS live_fleet_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id TEXT NOT NULL,
    trip_id TEXT,
    transport_type TEXT NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL,
    speed NUMERIC,
    heading NUMERIC,
    source TEXT NOT NULL CHECK (source IN ('driver', 'community', 'operator')),
    source_confidence INTEGER CHECK (source_confidence BETWEEN 0 AND 100),
    reliability_score INTEGER NOT NULL CHECK (reliability_score BETWEEN 0 AND 100),
    freshness_seconds INTEGER NOT NULL DEFAULT 0,
    coherence_score INTEGER CHECK (coherence_score BETWEEN 0 AND 100),
    driver_session_id UUID REFERENCES driver_sessions(id) ON DELETE SET NULL,
    community_vehicle_id UUID REFERENCES community_vehicles(id) ON DELETE SET NULL,
    active_user_count INTEGER,
    estimated_delay_seconds INTEGER,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_live_fleet_route ON live_fleet_positions(route_id);
CREATE INDEX IF NOT EXISTS idx_live_fleet_geom ON live_fleet_positions USING gist(geom);
CREATE INDEX IF NOT EXISTS idx_live_fleet_reliability ON live_fleet_positions(reliability_score DESC);

-- Clé logique par source (une ligne par véhicule/session)
CREATE UNIQUE INDEX IF NOT EXISTS idx_live_fleet_driver
    ON live_fleet_positions(driver_session_id)
    WHERE driver_session_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_live_fleet_community
    ON live_fleet_positions(community_vehicle_id)
    WHERE community_vehicle_id IS NOT NULL;

-- Score composite : source (40 %) + fraîcheur (35 %) + cohérence (25 %)
CREATE OR REPLACE FUNCTION public.compute_reliability_score(
    p_source TEXT,
    p_source_confidence INTEGER,
    p_last_seen_at TIMESTAMPTZ,
    p_coherence_score INTEGER DEFAULT NULL
)
RETURNS TABLE (
    reliability_score INTEGER,
    freshness_seconds INTEGER,
    coherence_score INTEGER
) AS $$
DECLARE
    v_source_weight NUMERIC;
    v_freshness NUMERIC;
    v_coherence NUMERIC;
    v_age_seconds INTEGER;
BEGIN
    v_age_seconds := GREATEST(0, EXTRACT(EPOCH FROM (NOW() - p_last_seen_at))::INTEGER);
    freshness_seconds := v_age_seconds;

    v_source_weight := CASE p_source
        WHEN 'driver' THEN 100
        WHEN 'operator' THEN 95
        WHEN 'community' THEN COALESCE(p_source_confidence, 50)
        ELSE 40
    END;

    v_freshness := CASE
        WHEN v_age_seconds <= 30 THEN 100
        WHEN v_age_seconds <= 120 THEN 100 - ((v_age_seconds - 30)::NUMERIC / 90 * 50)
        WHEN v_age_seconds <= 300 THEN 50 - ((v_age_seconds - 120)::NUMERIC / 180 * 50)
        ELSE 0
    END;

    v_coherence := COALESCE(p_coherence_score, 70);
    coherence_score := v_coherence::INTEGER;

    reliability_score := ROUND(
        v_source_weight * 0.40 +
        v_freshness * 0.35 +
        v_coherence * 0.25
    )::INTEGER;

    reliability_score := GREATEST(0, LEAST(100, reliability_score));
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- Cohérence : accord entre sources sur même route à proximité
CREATE OR REPLACE FUNCTION public.compute_coherence_for_position(
    p_route_id TEXT,
    p_geom GEOMETRY(Point, 4326)
)
RETURNS INTEGER AS $$
DECLARE
    match_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO match_count
    FROM live_fleet_positions lfp
    WHERE lfp.route_id = p_route_id
      AND lfp.last_seen_at >= NOW() - INTERVAL '2 minutes'
      AND ST_DWithin(lfp.geom::geography, p_geom::geography, 200);

    RETURN CASE
        WHEN match_count >= 2 THEN 95
        WHEN match_count = 1 THEN 75
        ELSE 50
    END;
END;
$$ LANGUAGE plpgsql STABLE;

-- Rafraîchissement de la couche unifiée depuis conducteurs + communauté
CREATE OR REPLACE FUNCTION public.refresh_live_fleet_positions()
RETURNS VOID AS $$
DECLARE
    rec RECORD;
    scores RECORD;
    v_coherence INTEGER;
BEGIN
    DELETE FROM live_fleet_positions WHERE last_seen_at < NOW() - INTERVAL '5 minutes';

    -- Source 1 : conducteurs certifiés (dernière position par session active)
    FOR rec IN
        SELECT DISTINCT ON (ds.id)
            ds.id AS session_id,
            ds.route_id,
            ds.trip_id,
            dle.geom,
            dle.speed,
            dle.heading,
            dle.timestamp AS last_seen_at,
            COALESCE(ds.detection_confidence, 100) AS source_confidence,
            CASE
                WHEN ds.route_id IN ('1','2','3') THEN 'tram'
                WHEN ds.route_id IN ('4','C4') THEN 'busway'
                WHEN ds.route_id LIKE 'N%' THEN 'navibus'
                ELSE 'bus'
            END AS transport_type
        FROM driver_sessions ds
        JOIN driver_location_events dle ON dle.session_id = ds.id
        WHERE ds.status IN ('active', 'paused')
        ORDER BY ds.id, dle.timestamp DESC
    LOOP
        v_coherence := compute_coherence_for_position(rec.route_id, rec.geom);
        SELECT * INTO scores FROM compute_reliability_score(
            'driver', rec.source_confidence, rec.last_seen_at, v_coherence
        );

        INSERT INTO live_fleet_positions (
            route_id, trip_id, transport_type, geom, speed, heading,
            source, source_confidence, reliability_score, freshness_seconds,
            coherence_score, driver_session_id, last_seen_at, updated_at
        ) VALUES (
            rec.route_id, rec.trip_id, rec.transport_type, rec.geom,
            rec.speed, rec.heading,
            'driver', rec.source_confidence, scores.reliability_score,
            scores.freshness_seconds, scores.coherence_score,
            rec.session_id, rec.last_seen_at, NOW()
        )
        ON CONFLICT (driver_session_id) WHERE driver_session_id IS NOT NULL
        DO UPDATE SET
            geom = EXCLUDED.geom,
            speed = EXCLUDED.speed,
            heading = EXCLUDED.heading,
            reliability_score = EXCLUDED.reliability_score,
            freshness_seconds = EXCLUDED.freshness_seconds,
            coherence_score = EXCLUDED.coherence_score,
            last_seen_at = EXCLUDED.last_seen_at,
            updated_at = NOW();
    END LOOP;

    -- Source 2 : véhicules communautaires
    FOR rec IN
        SELECT cv.*
        FROM community_vehicles cv
        WHERE cv.last_seen_at >= NOW() - INTERVAL '3 minutes'
    LOOP
        v_coherence := compute_coherence_for_position(rec.route_id, rec.geom);
        SELECT * INTO scores FROM compute_reliability_score(
            'community', rec.confidence_score, rec.last_seen_at, v_coherence
        );

        INSERT INTO live_fleet_positions (
            route_id, trip_id, transport_type, geom, speed, heading,
            source, source_confidence, reliability_score, freshness_seconds,
            coherence_score, community_vehicle_id, active_user_count,
            estimated_delay_seconds, last_seen_at, updated_at
        ) VALUES (
            rec.route_id, rec.trip_id, rec.transport_type, rec.geom,
            rec.speed, rec.heading,
            'community', rec.confidence_score, scores.reliability_score,
            scores.freshness_seconds, scores.coherence_score,
            rec.id, rec.active_user_count, rec.estimated_delay_seconds,
            rec.last_seen_at, NOW()
        )
        ON CONFLICT (community_vehicle_id) WHERE community_vehicle_id IS NOT NULL
        DO UPDATE SET
            geom = EXCLUDED.geom,
            speed = EXCLUDED.speed,
            heading = EXCLUDED.heading,
            reliability_score = EXCLUDED.reliability_score,
            freshness_seconds = EXCLUDED.freshness_seconds,
            coherence_score = EXCLUDED.coherence_score,
            active_user_count = EXCLUDED.active_user_count,
            estimated_delay_seconds = EXCLUDED.estimated_delay_seconds,
            last_seen_at = EXCLUDED.last_seen_at,
            updated_at = NOW();
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Realtime (ignorer l'erreur si déjà publié)
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE live_fleet_positions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE network_incidents;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE msr_missions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
