-- Équipes de contrôle Aule Pro (control teams)
-- ---------------------------------------------------------------------------
-- Un agent habilité Contrôle compose une équipe de contrôle : informations
-- générales (dépôt, horaires), périmètre de mission (ligne / véhicule / zone /
-- consignes) et un groupe d'agents porteurs de mentions opérationnelles
-- (PAD, Chef, TPE).
--
-- Architecture extensible : `teams.type` distingue déjà 'control' des futurs
-- modules 'intervention' et 'umtc' (hors périmètre v1). La logique métier fine
-- (PAD/Chef unique, minimum 2 agents, passage Brouillon -> Planifiée) est
-- portée par l'app ; la base garantit l'intégrité structurelle de base.
--
-- Conventions reprises du MVP conducteur (cf. 021_driver_mvp) :
--   line_id / vehicle_id en TEXT pour interopérer avec les identifiants GTFS
--   et un numéro de véhicule libre, sans table « lines » / « vehicles » dédiée.
-- ---------------------------------------------------------------------------

-- === Helper : l'appelant est-il habilité Contrôle ? =======================
-- Vrai pour un conducteur dont la fiche porte msr_control, ou pour le staff.
CREATE OR REPLACE FUNCTION public.current_driver_is_control()
RETURNS BOOLEAN AS $$
    SELECT public.is_staff()
        OR EXISTS (
            SELECT 1 FROM public.drivers d
            WHERE d.id = public.current_driver_id()
              AND d.msr_control
        );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.current_driver_is_control() TO authenticated;

-- Helpers RLS : évite la récursion infinie teams ↔ team_members (42P17).
CREATE OR REPLACE FUNCTION public.is_team_member(p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.team_members m
        WHERE m.team_id = p_team_id
          AND m.user_id = public.current_driver_id()
    );
$$;

CREATE OR REPLACE FUNCTION public.is_team_creator(p_team_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.teams t
        WHERE t.id = p_team_id
          AND t.created_by = public.current_driver_id()
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_team_member(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_team_creator(UUID) TO authenticated;

-- === teams =================================================================
CREATE TABLE IF NOT EXISTS public.teams (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    network_id     UUID REFERENCES public.networks(id) ON DELETE SET NULL
                   DEFAULT '00000000-0000-4000-8000-000000000001',
    name           TEXT NOT NULL,
    type           TEXT NOT NULL DEFAULT 'control'
                   CHECK (type IN ('control', 'intervention', 'umtc')),
    depot_id       UUID REFERENCES public.depots(id) ON DELETE SET NULL,
    status         TEXT NOT NULL DEFAULT 'draft'
                   CHECK (status IN ('draft', 'planned', 'awaiting_agents', 'ready')),
    departure_time TIME,
    return_time    TIME,
    line_id        TEXT,
    vehicle_id     TEXT,
    zone           TEXT,
    -- Liste de consignes (plusieurs lignes), ex. ["Contrôle aux portes", "..."]
    instructions   JSONB NOT NULL DEFAULT '[]'::jsonb,
    -- Vacations multiples (créneaux horaires) ; complète departure_time / return_time
    vacations      JSONB NOT NULL DEFAULT '[]'::jsonb,
    mobility_mode  TEXT CHECK (
        mobility_mode IS NULL OR mobility_mode IN ('vehicle', 'on_foot')
    ),
    created_by     UUID REFERENCES public.drivers(id) ON DELETE SET NULL,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- L'heure de retour doit suivre l'heure de départ (tolère les brouillons
    -- incomplets où l'une des deux n'est pas encore renseignée).
    CONSTRAINT teams_return_after_departure CHECK (
        departure_time IS NULL
        OR return_time IS NULL
        OR return_time > departure_time
    ),
    CONSTRAINT teams_vacations_is_array CHECK (
        jsonb_typeof(vacations) = 'array'
    )
);

CREATE INDEX IF NOT EXISTS idx_teams_status
    ON public.teams(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_teams_created_by
    ON public.teams(created_by, created_at DESC);

-- === team_members ==========================================================
-- Tous les membres sont agents de contrôle par défaut ; les mentions
-- (PAD / Chef / TPE) sont facultatives et stockées en tableau JSONB,
-- ex. ["PAD","Chef"], ["TPE"], [].
CREATE TABLE IF NOT EXISTS public.team_members (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id           UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    invitation_status TEXT NOT NULL DEFAULT 'invited'
                      CHECK (invitation_status IN (
                          'invited', 'accepted', 'declined',
                          'pending', 'removed', 'unavailable'
                      )),
    mentions          JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Un même agent n'apparaît qu'une fois par équipe.
    CONSTRAINT team_members_unique_per_team UNIQUE (team_id, user_id),
    CONSTRAINT team_members_mentions_is_array CHECK (
        jsonb_typeof(mentions) = 'array'
    )
);

CREATE INDEX IF NOT EXISTS idx_team_members_team
    ON public.team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user
    ON public.team_members(user_id);

-- Tient updated_at à jour sur les deux tables.
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_teams_updated_at ON public.teams;
CREATE TRIGGER trg_teams_updated_at
    BEFORE UPDATE ON public.teams
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

DROP TRIGGER IF EXISTS trg_team_members_updated_at ON public.team_members;
CREATE TRIGGER trg_team_members_updated_at
    BEFORE UPDATE ON public.team_members
    FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- === RLS ===================================================================
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

-- teams : lecture par les agents Contrôle / staff ; un agent voit aussi les
-- équipes où il est membre.
DROP POLICY IF EXISTS teams_select ON public.teams;
CREATE POLICY teams_select ON public.teams
    FOR SELECT TO authenticated
    USING (
        public.current_driver_is_control()
        OR public.is_team_member(id)
    );

-- Création / modification / suppression : agent Contrôle habilité, créateur
-- de l'équipe (ou staff).
DROP POLICY IF EXISTS teams_insert ON public.teams;
CREATE POLICY teams_insert ON public.teams
    FOR INSERT TO authenticated
    WITH CHECK (
        public.current_driver_is_control()
        AND created_by = public.current_driver_id()
    );

DROP POLICY IF EXISTS teams_update ON public.teams;
CREATE POLICY teams_update ON public.teams
    FOR UPDATE TO authenticated
    USING (created_by = public.current_driver_id() OR public.is_staff())
    WITH CHECK (created_by = public.current_driver_id() OR public.is_staff());

DROP POLICY IF EXISTS teams_delete ON public.teams;
CREATE POLICY teams_delete ON public.teams
    FOR DELETE TO authenticated
    USING (created_by = public.current_driver_id() OR public.is_staff());

-- team_members : lecture pour les agents Contrôle / staff, et pour le membre
-- lui-même.
DROP POLICY IF EXISTS team_members_select ON public.team_members;
CREATE POLICY team_members_select ON public.team_members
    FOR SELECT TO authenticated
    USING (
        public.current_driver_is_control()
        OR user_id = public.current_driver_id()
    );

-- Écriture des membres : réservée au créateur de l'équipe (ou staff).
DROP POLICY IF EXISTS team_members_write ON public.team_members;
DROP POLICY IF EXISTS team_members_insert ON public.team_members;
DROP POLICY IF EXISTS team_members_update ON public.team_members;
DROP POLICY IF EXISTS team_members_delete ON public.team_members;

CREATE POLICY team_members_insert ON public.team_members
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_staff()
        OR public.is_team_creator(team_id)
    );

CREATE POLICY team_members_update ON public.team_members
    FOR UPDATE TO authenticated
    USING (
        public.is_staff()
        OR public.is_team_creator(team_id)
    )
    WITH CHECK (
        public.is_staff()
        OR public.is_team_creator(team_id)
    );

CREATE POLICY team_members_delete ON public.team_members
    FOR DELETE TO authenticated
    USING (
        public.is_staff()
        OR public.is_team_creator(team_id)
    );

-- === RPC : recherche d'agents pour composer une équipe =====================
-- La RLS de `drivers` interdit la lecture des autres fiches : cette fonction
-- SECURITY DEFINER expose, aux seuls agents Contrôle, les champs nécessaires
-- pour rechercher et ajouter un agent. Elle signale aussi l'équipe active
-- éventuelle de l'agent (pour empêcher une double affectation côté app).
CREATE OR REPLACE FUNCTION public.search_team_agents(p_query TEXT)
RETURNS TABLE (
    id               UUID,
    first_name       TEXT,
    last_name        TEXT,
    driver_number    TEXT,
    depot_name       TEXT,
    active_team_id   UUID,
    active_team_name TEXT
) AS $$
    SELECT
        d.id,
        d.first_name,
        d.last_name,
        d.driver_number,
        dep.name AS depot_name,
        act.team_id AS active_team_id,
        act.team_name AS active_team_name
    FROM public.drivers d
    LEFT JOIN public.depots dep ON dep.id = d.depot_id
    LEFT JOIN LATERAL (
        SELECT t.id AS team_id, t.name AS team_name
        FROM public.team_members m
        JOIN public.teams t ON t.id = m.team_id
        WHERE m.user_id = d.id
          AND t.status IN ('planned', 'awaiting_agents', 'ready')
          AND m.invitation_status <> 'removed'
        ORDER BY t.created_at DESC
        LIMIT 1
    ) act ON TRUE
    WHERE public.current_driver_is_control()
      AND (
          p_query IS NULL
          OR length(btrim(p_query)) = 0
          OR d.driver_number ILIKE '%' || p_query || '%'
          OR (coalesce(d.first_name, '') || ' ' || coalesce(d.last_name, '')) ILIKE '%' || p_query || '%'
      )
    ORDER BY d.last_name NULLS LAST, d.first_name NULLS LAST
    LIMIT 30;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.search_team_agents(TEXT) TO authenticated;

-- === Réplication temps réel (idempotent) ==================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.teams;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.team_members;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
