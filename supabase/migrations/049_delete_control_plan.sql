-- Suppression d'une mission de contrôle depuis l'app Pro.
--
-- Pendant du flux manuel MVP (040/048) : l'agent crée ses plans via
-- `create_control_plan` et doit pouvoir les supprimer depuis l'écran Missions.
-- Un « mission » côté app = un control_plan + ses msr_missions rattachées.
--
-- Droit : agent habilité Contrôle ET créateur du plan (control_plans.created_by)
-- ou créateur d'une des équipes rattachées au plan. La fonction est SECURITY
-- DEFINER et contourne donc la RLS — d'où les contrôles explicites ci-dessous.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.delete_control_plan(p_plan_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_user_id UUID;
    v_plan public.control_plans%ROWTYPE;
    v_allowed BOOLEAN := false;
BEGIN
    IF NOT public.current_driver_is_control() THEN
        RAISE EXCEPTION 'Suppression réservée aux agents habilités Contrôle';
    END IF;

    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'Conducteur introuvable';
    END IF;

    SELECT up.id INTO v_user_id
    FROM public.drivers d
    LEFT JOIN public.user_profiles up ON up.id = d.user_id
    WHERE d.id = v_driver_id;

    SELECT * INTO v_plan
    FROM public.control_plans
    WHERE id = p_plan_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Mission introuvable';
    END IF;

    -- Droit : créateur du plan, ou créateur d'une équipe rattachée au plan.
    v_allowed := (v_user_id IS NOT NULL AND v_plan.created_by = v_user_id);

    IF NOT v_allowed THEN
        SELECT EXISTS (
            SELECT 1
            FROM public.control_plan_teams cpt
            JOIN public.teams t ON t.id::text = cpt.team_id
            WHERE cpt.plan_id = p_plan_id
              AND t.created_by = v_driver_id
        ) INTO v_allowed;
    END IF;

    IF NOT v_allowed THEN
        RAISE EXCEPTION 'Seul le créateur peut supprimer cette mission';
    END IF;

    -- Clôture des ressources plateforme miroir (042/043) : on conserve
    -- l'historique de discussion mais on retire les entités du graphe actif.
    UPDATE public.resources r
    SET status = 'deleted', updated_at = NOW()
    WHERE r.type = 'mission'
      AND r.external_id IN (
          SELECT m.id::text
          FROM public.msr_missions m
          WHERE m.control_plan_id = p_plan_id
      );

    UPDATE public.resources r
    SET status = 'deleted', updated_at = NOW()
    WHERE r.type = 'control_plan'
      AND r.external_id = p_plan_id::text;

    -- Missions MSR du plan (cascade msr_patrol_proposals via FK ON DELETE CASCADE).
    DELETE FROM public.msr_missions
    WHERE control_plan_id = p_plan_id;

    -- Plan (cascade control_plan_teams / agents / lines / zones / instructions).
    DELETE FROM public.control_plans
    WHERE id = p_plan_id;

    RETURN p_plan_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_control_plan(UUID) TO authenticated;
