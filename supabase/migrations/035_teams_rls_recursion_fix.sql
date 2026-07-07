-- Corrige la récursion infinie RLS entre teams ↔ team_members (42P17).
-- Les politiques croisées déclenchaient une boucle lors du INSERT … RETURNING.
-- Les helpers SECURITY DEFINER contournent la RLS pour les tests d'appartenance.

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

-- teams : lecture sans sous-requête directe sur team_members (RLS).
DROP POLICY IF EXISTS teams_select ON public.teams;
CREATE POLICY teams_select ON public.teams
    FOR SELECT TO authenticated
    USING (
        public.current_driver_is_control()
        OR public.is_team_member(id)
    );

-- team_members : écriture sans sous-requête directe sur teams (RLS).
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
