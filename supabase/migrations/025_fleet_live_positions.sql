-- Flux flotte temps réel — vue opérationnelle « Terrain » (modèle MVP conducteur)
-- ---------------------------------------------------------------------------
-- La table vehicle_positions est protégée par RLS : un conducteur ne lit que
-- ses propres points (le staff voit tout). Pour la carte Terrain, on expose en
-- lecture seule la DERNIÈRE position de chaque service ACTIF, sur une fenêtre
-- récente, via une fonction SECURITY DEFINER : pas d'historique, pas de
-- véhicules inactifs, pas d'identité conducteur.
--
-- S'appuie sur le modèle MVP (021 : drivers / driver_services / vehicle_positions),
-- et NON sur l'ancien live_fleet_positions (005, auto-détection abandonnée).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fleet_live_positions(
    p_max_age_seconds INTEGER DEFAULT 300
)
RETURNS TABLE (
    driver_service_id UUID,
    vehicle_id TEXT,
    line_id TEXT,
    direction_id INTEGER,
    headsign TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    speed DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    accuracy DOUBLE PRECISION,
    recorded_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT DISTINCT ON (vp.driver_service_id)
        vp.driver_service_id,
        vp.vehicle_id,
        ds.line_id,
        ds.direction_id,
        ds.headsign,
        vp.latitude,
        vp.longitude,
        vp.speed,
        vp.heading,
        vp.accuracy,
        vp.created_at AS recorded_at
    FROM public.vehicle_positions vp
    JOIN public.driver_services ds ON ds.id = vp.driver_service_id
    WHERE ds.status = 'active'
      AND vp.created_at >=
          NOW() - (GREATEST(p_max_age_seconds, 0)::text || ' seconds')::interval
    ORDER BY vp.driver_service_id, vp.created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.fleet_live_positions(INTEGER) TO authenticated;

-- Réplication temps réel des positions (idempotent). La RLS de vehicle_positions
-- reste appliquée au flux : un conducteur n'y reçoit que ses propres lignes, le
-- staff toute la flotte ; la fonction ci-dessus complète le snapshot flotte pour
-- tous les rôles authentifiés.
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.vehicle_positions;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
