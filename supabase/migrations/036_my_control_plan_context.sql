-- Contexte « mon plan de contrôle » pour l'app mobile agent
-- ---------------------------------------------------------------------------
-- Expose plan actif + équipe de l'agent + liste des équipes du contexte,
-- en contournant la RLS staff-only sur control_plans (SECURITY DEFINER).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.my_control_plan_context()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_user_id UUID;
    v_plan_id UUID;
    v_my_team_id UUID;
    v_plan JSONB;
    v_teams JSONB;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object(
            'plan', NULL,
            'my_team_id', NULL,
            'teams', '[]'::jsonb
        );
    END IF;

    SELECT d.user_id INTO v_user_id
    FROM public.drivers d
    WHERE d.id = v_driver_id;

    -- Priorité 1 : affectation directe au plan (user_profiles.id)
    IF v_user_id IS NOT NULL THEN
        SELECT cp.id INTO v_plan_id
        FROM public.control_plans cp
        JOIN public.control_plan_agents cpa ON cpa.plan_id = cp.id
        WHERE cp.status = 'active'
          AND CURRENT_DATE BETWEEN cp.start_date AND cp.end_date
          AND cpa.agent_id = v_user_id
        ORDER BY cp.updated_at DESC
        LIMIT 1;
    END IF;

    -- Priorité 2 : membre d'une équipe liée au plan
    IF v_plan_id IS NULL THEN
        SELECT cp.id INTO v_plan_id
        FROM public.control_plans cp
        JOIN public.control_plan_teams cpt ON cpt.plan_id = cp.id
        JOIN public.teams t ON t.id::text = cpt.team_id
        JOIN public.team_members tm ON tm.team_id = t.id
        WHERE cp.status = 'active'
          AND CURRENT_DATE BETWEEN cp.start_date AND cp.end_date
          AND tm.user_id = v_driver_id
          AND tm.invitation_status <> 'removed'
        ORDER BY cp.updated_at DESC
        LIMIT 1;
    END IF;

    -- Équipe active de l'agent (priorise celle du plan si trouvé)
    SELECT tm.team_id INTO v_my_team_id
    FROM public.team_members tm
    JOIN public.teams t ON t.id = tm.team_id
    WHERE tm.user_id = v_driver_id
      AND tm.invitation_status <> 'removed'
      AND t.type = 'control'
      AND t.status IN ('planned', 'awaiting_agents', 'ready')
    ORDER BY
        CASE
            WHEN v_plan_id IS NOT NULL AND EXISTS (
                SELECT 1
                FROM public.control_plan_teams cpt
                WHERE cpt.plan_id = v_plan_id
                  AND cpt.team_id = t.id::text
            ) THEN 0
            ELSE 1
        END,
        t.updated_at DESC
    LIMIT 1;

    -- Plan enrichi (consignes ordonnées)
    IF v_plan_id IS NOT NULL THEN
        SELECT jsonb_build_object(
            'id', cp.id,
            'name', cp.name,
            'status', cp.status,
            'start_date', cp.start_date,
            'end_date', cp.end_date,
            'objective', cp.objective,
            'instructions', COALESCE(
                (
                    SELECT jsonb_agg(cpi.content ORDER BY cpi.sort_order)
                    FROM public.control_plan_instructions cpi
                    WHERE cpi.plan_id = cp.id
                ),
                '[]'::jsonb
            )
        )
        INTO v_plan
        FROM public.control_plans cp
        WHERE cp.id = v_plan_id;
    ELSE
        v_plan := NULL;
    END IF;

    -- Équipes visibles dans le contexte
    SELECT COALESCE(
        jsonb_agg(team_row ORDER BY (team_row->>'created_at') DESC NULLS LAST),
        '[]'::jsonb
    )
    INTO v_teams
    FROM (
        SELECT jsonb_build_object(
            'id', t.id,
            'name', t.name,
            'type', t.type,
            'depot_id', t.depot_id,
            'status', t.status,
            'departure_time', t.departure_time,
            'return_time', t.return_time,
            'vacations', t.vacations,
            'mobility_mode', t.mobility_mode,
            'line_id', t.line_id,
            'vehicle_id', t.vehicle_id,
            'zone', t.zone,
            'instructions', t.instructions,
            'created_at', t.created_at,
            'team_members', COALESCE(
                (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'id', m.id,
                            'user_id', m.user_id,
                            'invitation_status', m.invitation_status,
                            'mentions', m.mentions
                        )
                    )
                    FROM public.team_members m
                    WHERE m.team_id = t.id
                ),
                '[]'::jsonb
            )
        ) AS team_row
        FROM public.teams t
        WHERE t.type = 'control'
          AND (
              v_plan_id IS NULL
              OR EXISTS (
                  SELECT 1
                  FROM public.control_plan_teams cpt
                  WHERE cpt.plan_id = v_plan_id
                    AND cpt.team_id = t.id::text
              )
          )
          AND (
              public.current_driver_is_control()
              OR public.is_team_member(t.id)
          )
    ) sub;

    RETURN jsonb_build_object(
        'plan', v_plan,
        'my_team_id', v_my_team_id,
        'teams', v_teams
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.my_control_plan_context() TO authenticated;
