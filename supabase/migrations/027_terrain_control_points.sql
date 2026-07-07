-- Couche Terrain réelle — points de contrôle
-- ---------------------------------------------------------------------------
-- Le modèle control_plans (020) ne porte pas de géométrie : un plan cible des
-- stations (control_plan_stations.station_id → stations.id). Un « point de
-- contrôle » sur la carte = une station d'un plan ACTIF couvrant la date du
-- jour, positionnée sur les coordonnées de la station.
--
-- Durcissement : les tables control_plan_* sont des données d'exploitation MSR
-- → RLS activée, accès direct réservé au staff. La carte y accède en lecture
-- seule via une fonction SECURITY DEFINER (comme les autres couches Terrain).
-- ---------------------------------------------------------------------------

-- === RLS staff-only sur la famille control_plan_* ========================
DO $$
DECLARE t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'control_plans', 'control_plan_teams', 'control_plan_agents',
        'control_plan_lines', 'control_plan_stations', 'control_plan_zones',
        'control_plan_instructions'
    ]
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_staff_all', t);
        EXECUTE format(
            'CREATE POLICY %I ON public.%I FOR ALL TO authenticated '
            'USING (public.is_staff()) WITH CHECK (public.is_staff())',
            t || '_staff_all', t);
    END LOOP;
END $$;

-- === Points de contrôle (plans actifs) ====================================
CREATE OR REPLACE FUNCTION public.terrain_control_points()
RETURNS TABLE (
    id TEXT,
    plan_name TEXT,
    priority TEXT,
    station_name TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    recorded_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT DISTINCT ON (cps.station_id)
        'ctrl:' || cp.id::text || ':' || cps.station_id,
        cp.name,
        cp.priority,
        st.name,
        st.latitude_center,
        st.longitude_center,
        cp.updated_at
    FROM control_plans cp
    JOIN control_plan_stations cps ON cps.plan_id = cp.id
    JOIN stations st ON st.id::text = cps.station_id
    WHERE cp.status = 'active'
      AND CURRENT_DATE BETWEEN cp.start_date AND cp.end_date
      AND st.latitude_center IS NOT NULL
      AND st.longitude_center IS NOT NULL
    ORDER BY cps.station_id, cp.updated_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.terrain_control_points() TO authenticated;

-- === Réplication temps réel (idempotent) ==================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.control_plans;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.control_plan_stations;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
