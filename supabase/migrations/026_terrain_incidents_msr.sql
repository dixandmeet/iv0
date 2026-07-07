-- Couches Terrain réelles — incidents & équipes MSR
-- ---------------------------------------------------------------------------
-- Même principe que fleet_live_positions (025) : les tables sources sont sous
-- RLS, on expose en lecture seule l'essentiel via des fonctions SECURITY
-- DEFINER destinées à la carte Terrain (utilisateurs authentifiés Aule Pro).
--
--  • terrain_incidents  : signalements conducteurs (driver_reports) + incidents
--    réseau (network_incidents), ouverts/en cours, géolocalisés.
--  • terrain_msr_teams  : missions MSR actives, positionnées au centroïde de
--    leur zone (pas de GPS agent en temps réel dans le modèle actuel).
-- ---------------------------------------------------------------------------

-- === Incidents ============================================================
CREATE OR REPLACE FUNCTION public.terrain_incidents(
    p_max_age_seconds INTEGER DEFAULT 86400
)
RETURNS TABLE (
    id TEXT,
    source TEXT,
    category TEXT,
    label TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    severity TEXT,
    status TEXT,
    recorded_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        'dr:' || dr.id::text,
        'driver_report',
        dr.type,
        COALESCE(NULLIF(dr.message, ''), dr.type),
        dr.latitude,
        dr.longitude,
        dr.urgency,
        dr.status,
        dr.created_at
    FROM public.driver_reports dr
    WHERE dr.status IN ('open', 'acknowledged')
      AND dr.latitude IS NOT NULL
      AND dr.longitude IS NOT NULL
      AND dr.created_at >=
          NOW() - (GREATEST(p_max_age_seconds, 0)::text || ' seconds')::interval

    UNION ALL

    SELECT
        'ni:' || ni.id::text,
        'network',
        ni.incident_type,
        COALESCE(NULLIF(ni.title, ''), ni.incident_type),
        ST_Y(ST_Centroid(ni.geom)),
        ST_X(ST_Centroid(ni.geom)),
        ni.severity::text,
        ni.status::text,
        ni.created_at
    FROM public.network_incidents ni
    WHERE ni.status IN ('open', 'acknowledged', 'in_progress')
      AND ni.geom IS NOT NULL
      AND ni.created_at >=
          NOW() - (GREATEST(p_max_age_seconds, 0)::text || ' seconds')::interval;
$$;

GRANT EXECUTE ON FUNCTION public.terrain_incidents(INTEGER) TO authenticated;

-- === Équipes MSR ==========================================================
CREATE OR REPLACE FUNCTION public.terrain_msr_teams(
    p_max_age_seconds INTEGER DEFAULT 43200
)
RETURNS TABLE (
    id TEXT,
    status TEXT,
    zone_type TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    recorded_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT
        'msr:' || m.id::text,
        m.status,
        m.zone_type,
        ST_Y(ST_Centroid(m.zone_geom)),
        ST_X(ST_Centroid(m.zone_geom)),
        COALESCE(m.started_at, m.updated_at, m.created_at)
    FROM public.msr_missions m
    WHERE m.status IN ('assigned', 'in_progress')
      AND m.zone_geom IS NOT NULL
      AND COALESCE(m.started_at, m.updated_at, m.created_at) >=
          NOW() - (GREATEST(p_max_age_seconds, 0)::text || ' seconds')::interval;
$$;

GRANT EXECUTE ON FUNCTION public.terrain_msr_teams(INTEGER) TO authenticated;

-- === Réplication temps réel (idempotent) ==================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_reports;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.network_incidents;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.msr_missions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
