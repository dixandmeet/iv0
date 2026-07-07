-- Couche Terrain réelle — demandes d'assistance
-- ---------------------------------------------------------------------------
-- Boucle « Besoin d'aide » : un agent terrain (conducteur / MSR) déclenche une
-- demande d'assistance géolocalisée ; elle apparaît sur la carte Terrain de
-- tous les utilisateurs authentifiés jusqu'à prise en charge / résolution.
--
-- Écriture par l'auteur uniquement (RLS), lecture carte via fonction SECURITY
-- DEFINER (comme les autres couches Terrain).
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.assistance_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_by UUID DEFAULT auth.uid(),
    driver_id UUID REFERENCES public.drivers(id) ON DELETE SET NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    message TEXT,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'acknowledged', 'resolved')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_assistance_requests_status
    ON public.assistance_requests(status, created_at DESC);

ALTER TABLE public.assistance_requests ENABLE ROW LEVEL SECURITY;

-- L'auteur crée ses demandes.
DROP POLICY IF EXISTS assistance_insert_own ON public.assistance_requests;
CREATE POLICY assistance_insert_own ON public.assistance_requests
    FOR INSERT TO authenticated
    WITH CHECK (created_by = auth.uid());

-- L'auteur lit les siennes ; le staff lit tout.
DROP POLICY IF EXISTS assistance_select ON public.assistance_requests;
CREATE POLICY assistance_select ON public.assistance_requests
    FOR SELECT TO authenticated
    USING (created_by = auth.uid() OR public.is_staff());

-- Prise en charge / résolution : auteur ou staff.
DROP POLICY IF EXISTS assistance_update ON public.assistance_requests;
CREATE POLICY assistance_update ON public.assistance_requests
    FOR UPDATE TO authenticated
    USING (created_by = auth.uid() OR public.is_staff())
    WITH CHECK (created_by = auth.uid() OR public.is_staff());

-- === Lecture carte (toutes les demandes ouvertes/en cours) ================
CREATE OR REPLACE FUNCTION public.terrain_assistance(
    p_max_age_seconds INTEGER DEFAULT 7200
)
RETURNS TABLE (
    id TEXT,
    message TEXT,
    status TEXT,
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
        'help:' || ar.id::text,
        ar.message,
        ar.status,
        ar.latitude,
        ar.longitude,
        ar.created_at
    FROM public.assistance_requests ar
    WHERE ar.status IN ('open', 'acknowledged')
      AND ar.latitude IS NOT NULL
      AND ar.longitude IS NOT NULL
      AND ar.created_at >=
          NOW() - (GREATEST(p_max_age_seconds, 0)::text || ' seconds')::interval;
$$;

GRANT EXECUTE ON FUNCTION public.terrain_assistance(INTEGER) TO authenticated;

-- === Réplication temps réel (idempotent) ==================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.assistance_requests;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
