-- Phase 0 — Missions MSR (structure complète, planificateur en Phase 5)

CREATE TABLE IF NOT EXISTS msr_sectors (
    id TEXT PRIMARY KEY,
    label TEXT NOT NULL,
    geom GEOMETRY(Polygon, 4326) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_msr_sectors_geom ON msr_sectors USING gist(geom);

CREATE TABLE IF NOT EXISTS msr_missions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supervisor_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    agent_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    zone_type TEXT NOT NULL CHECK (zone_type IN ('sector', 'line_buffer', 'custom_polygon')),
    zone_config JSONB NOT NULL DEFAULT '{}',
    zone_geom GEOMETRY(Polygon, 4326),
    depot_id UUID REFERENCES depots(id) ON DELETE SET NULL,
    depot_return_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'assigned', 'in_progress', 'completed', 'cancelled')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_msr_missions_agent ON msr_missions(agent_id, status);
CREATE INDEX IF NOT EXISTS idx_msr_missions_status ON msr_missions(status);
CREATE INDEX IF NOT EXISTS idx_msr_missions_geom ON msr_missions USING gist(zone_geom);

CREATE TABLE IF NOT EXISTS msr_patrol_proposals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    mission_id UUID REFERENCES msr_missions(id) ON DELETE CASCADE NOT NULL,
    rank INTEGER NOT NULL DEFAULT 1,
    legs JSONB NOT NULL DEFAULT '[]',
    total_duration_min INTEGER,
    estimated_return_at TIMESTAMPTZ,
    fits_depot_deadline BOOLEAN NOT NULL DEFAULT FALSE,
    selected BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_msr_patrol_mission ON msr_patrol_proposals(mission_id, rank);

-- Buffer autour d'un tronçon de ligne GTFS (MVP #5 — RPC prête dès Phase 0)
CREATE OR REPLACE FUNCTION public.msr_build_line_buffer(
    p_route_id TEXT,
    p_direction_id INTEGER,
    p_distance_m NUMERIC,
    p_buffer_m NUMERIC DEFAULT 150
)
RETURNS TABLE (
    zone_geom GEOMETRY(Polygon, 4326),
    stop_ids TEXT[],
    estimated_length_m NUMERIC
) AS $$
DECLARE
    line_geom GEOMETRY(LineString, 4326);
    clipped_geom GEOMETRY(LineString, 4326);
    line_len_m NUMERIC;
BEGIN
    SELECT ST_MakeLine(s.geom ORDER BY s.shape_pt_sequence)
    INTO line_geom
    FROM gtfs_shapes s
    JOIN gtfs_trips t ON t.shape_id = s.shape_id
    WHERE t.route_id = p_route_id
      AND (p_direction_id IS NULL OR t.direction_id = p_direction_id)
    GROUP BY t.shape_id
    ORDER BY COUNT(*) DESC
    LIMIT 1;

    IF line_geom IS NULL THEN
        RETURN;
    END IF;

    line_len_m := ST_Length(line_geom::geography);
    IF line_len_m <= 0 THEN
        RETURN;
    END IF;

    clipped_geom := ST_LineSubstring(
        line_geom,
        0,
        LEAST(1.0, p_distance_m / line_len_m)
    );

    zone_geom := ST_Buffer(clipped_geom::geography, p_buffer_m)::geometry;
    estimated_length_m := ST_Length(clipped_geom::geography);

    SELECT ARRAY_AGG(DISTINCT st.stop_id)
    INTO stop_ids
    FROM gtfs_stops st
    WHERE ST_DWithin(st.geom::geography, zone_geom::geography, 0);

    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- Planificateur stub (implémentation complète Phase 5)
CREATE OR REPLACE FUNCTION public.msr_plan_patrol(p_mission_id UUID)
RETURNS JSONB AS $$
DECLARE
    mission RECORD;
BEGIN
    SELECT * INTO mission FROM msr_missions WHERE id = p_mission_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'mission_not_found');
    END IF;

    RETURN jsonb_build_object(
        'status', 'stub',
        'mission_id', p_mission_id,
        'note', 'Planificateur complet en Phase 5'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
