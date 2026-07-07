-- Backfill missions MSR pour plans existants + mission preview si msr_missions absente.
-- ---------------------------------------------------------------------------

-- Crée les msr_missions manquantes pour les couples plan / équipe déjà liés.
INSERT INTO public.msr_missions (
    control_plan_id,
    team_id,
    zone_id,
    zone_type,
    zone_config,
    scheduled_start,
    scheduled_end,
    status
)
SELECT
    cp.id,
    cpt.team_id,
    COALESCE(NULLIF(btrim(t.zone), ''), 'zone'),
    'custom_polygon',
    jsonb_strip_nulls(jsonb_build_object(
        'line_id', NULLIF(btrim(t.line_id), ''),
        'zone', NULLIF(btrim(t.zone), '')
    )),
    (
        cp.start_date + COALESCE(
            NULLIF(btrim(t.vacations->0->>'start_time'), '')::time,
            t.departure_time,
            '08:00'::time
        )
    )::timestamp,
    (
        cp.start_date + COALESCE(
            NULLIF(btrim(t.vacations->0->>'end_time'), '')::time,
            t.return_time,
            '12:00'::time
        )
    )::timestamp
        + CASE
            WHEN (
                cp.start_date + COALESCE(
                    NULLIF(btrim(t.vacations->0->>'end_time'), '')::time,
                    t.return_time,
                    '12:00'::time
                )
            )::timestamp <= (
                cp.start_date + COALESCE(
                    NULLIF(btrim(t.vacations->0->>'start_time'), '')::time,
                    t.departure_time,
                    '08:00'::time
                )
            )::timestamp
            THEN INTERVAL '1 day'
            ELSE INTERVAL '0'
          END,
    'assigned'
FROM public.control_plan_teams cpt
JOIN public.teams t ON t.id::text = cpt.team_id
JOIN public.control_plans cp ON cp.id = cpt.plan_id
WHERE NOT EXISTS (
    SELECT 1
    FROM public.msr_missions m
    WHERE m.control_plan_id = cp.id
      AND m.team_id = cpt.team_id
);

-- Horaires plan + équipe → bornes mission (preview si msr_missions absente).
CREATE OR REPLACE FUNCTION public.control_team_schedule_bounds(
    p_team public.teams,
    p_plan_start DATE
)
RETURNS TABLE (
    scheduled_start TIMESTAMPTZ,
    scheduled_end TIMESTAMPTZ
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_start_time TIME;
    v_end_time TIME;
    v_start_ts TIMESTAMPTZ;
    v_end_ts TIMESTAMPTZ;
BEGIN
    v_start_time := COALESCE(
        NULLIF(btrim(p_team.vacations->0->>'start_time'), '')::time,
        p_team.departure_time,
        '08:00'::time
    );
    v_end_time := COALESCE(
        NULLIF(btrim(p_team.vacations->0->>'end_time'), '')::time,
        p_team.return_time,
        '12:00'::time
    );

    v_start_ts := (p_plan_start + v_start_time)::timestamp;
    v_end_ts := (p_plan_start + v_end_time)::timestamp;
    IF v_end_ts <= v_start_ts THEN
        v_end_ts := v_end_ts + INTERVAL '1 day';
    END IF;

    scheduled_start := v_start_ts;
    scheduled_end := v_end_ts;
    RETURN NEXT;
END;
$$;

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
    v_plan_start DATE;
    v_my_team_id UUID;
    v_my_invitation_status TEXT;
    v_effective_status TEXT;
    v_is_creator BOOLEAN := false;
    v_can_view_full BOOLEAN := false;
    v_plan JSONB;
    v_current_mission JSONB;
    v_teams JSONB;
    v_mission public.msr_missions%ROWTYPE;
    v_has_mission BOOLEAN := false;
    v_mission_end TIMESTAMPTZ;
    v_team public.teams%ROWTYPE;
    v_plan_name TEXT;
    v_creator_name TEXT;
    v_plan_instructions JSONB;
    v_team_members JSONB;
    v_bounds RECORD;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object(
            'plan', NULL,
            'my_team_id', NULL,
            'my_invitation_status', NULL,
            'my_invitation_effective_status', NULL,
            'is_creator', false,
            'can_view_full', false,
            'current_mission', NULL,
            'teams', '[]'::jsonb
        );
    END IF;

    SELECT d.user_id INTO v_user_id
    FROM public.drivers d
    WHERE d.id = v_driver_id;

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

    IF v_plan_id IS NOT NULL THEN
        SELECT cp.start_date INTO v_plan_start
        FROM public.control_plans cp
        WHERE cp.id = v_plan_id;
    END IF;

    SELECT tm.team_id, tm.invitation_status
    INTO v_my_team_id, v_my_invitation_status
    FROM public.team_members tm
    JOIN public.teams t ON t.id = tm.team_id
    WHERE tm.user_id = v_driver_id
      AND tm.invitation_status <> 'removed'
      AND t.type = 'control'
      AND t.status IN ('planned', 'awaiting_agents', 'ready')
    ORDER BY
        CASE
            WHEN v_plan_id IS NOT NULL AND EXISTS (
                SELECT 1 FROM public.control_plan_teams cpt
                WHERE cpt.plan_id = v_plan_id
                  AND cpt.team_id = t.id::text
            ) THEN 0
            ELSE 1
        END,
        t.updated_at DESC
    LIMIT 1;

    IF v_my_team_id IS NOT NULL THEN
        SELECT (t.created_by = v_driver_id)
        INTO v_is_creator
        FROM public.teams t
        WHERE t.id = v_my_team_id;
    END IF;

    v_can_view_full := v_is_creator OR v_my_invitation_status = 'accepted';

    IF v_plan_id IS NOT NULL THEN
        IF v_can_view_full THEN
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
            SELECT jsonb_build_object(
                'id', cp.id,
                'name', cp.name,
                'status', cp.status,
                'start_date', cp.start_date,
                'end_date', cp.end_date,
                'objective', cp.objective,
                'instructions', '[]'::jsonb
            )
            INTO v_plan
            FROM public.control_plans cp
            WHERE cp.id = v_plan_id;
        END IF;
    END IF;

    SELECT m.* INTO v_mission
    FROM public.msr_missions m
    JOIN public.team_members tm ON tm.team_id::text = m.team_id
    JOIN public.control_plans cp ON cp.id = m.control_plan_id
    WHERE tm.user_id = v_driver_id
      AND tm.invitation_status <> 'removed'
      AND m.status IN ('assigned', 'in_progress')
      AND cp.status = 'active'
      AND CURRENT_DATE BETWEEN cp.start_date AND cp.end_date
      AND (v_plan_id IS NULL OR m.control_plan_id = v_plan_id)
    ORDER BY
        CASE WHEN m.status = 'in_progress' THEN 0 ELSE 1 END,
        m.scheduled_start DESC NULLS LAST
    LIMIT 1;

    v_has_mission := FOUND;

    IF v_has_mission THEN
        v_mission_end := v_mission.scheduled_end;

        SELECT t.* INTO v_team
        FROM public.teams t
        WHERE t.id::text = v_mission.team_id;

        SELECT cp.name INTO v_plan_name
        FROM public.control_plans cp
        WHERE cp.id = v_mission.control_plan_id;

        v_creator_name := public.driver_display_name(v_team.created_by);

        IF v_can_view_full THEN
            SELECT COALESCE(
                jsonb_agg(cpi.content ORDER BY cpi.sort_order),
                '[]'::jsonb
            )
            INTO v_plan_instructions
            FROM public.control_plan_instructions cpi
            WHERE cpi.plan_id = v_mission.control_plan_id;

            SELECT COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', m.id,
                        'user_id', m.user_id,
                        'invitation_status', m.invitation_status,
                        'mentions', m.mentions
                    )
                ),
                '[]'::jsonb
            )
            INTO v_team_members
            FROM public.team_members m
            WHERE m.team_id = v_team.id
              AND m.invitation_status <> 'removed';

            v_current_mission := public.control_mission_full_json(
                v_mission,
                v_plan_name,
                v_team.name,
                v_creator_name,
                v_plan_instructions,
                v_team_members,
                COALESCE(NULLIF(btrim(v_team.line_id), ''), v_mission.zone_config->>'line_id'),
                COALESCE(NULLIF(btrim(v_team.zone), ''), v_mission.zone_id)
            );
        ELSE
            v_current_mission := public.control_mission_preview_json(
                v_mission,
                v_plan_name,
                v_team.name,
                v_creator_name
            );
        END IF;
    ELSIF v_my_team_id IS NOT NULL AND v_plan_id IS NOT NULL THEN
        -- Preview mission dérivée équipe + plan (plans créés avant msr_missions).
        SELECT t.* INTO v_team FROM public.teams t WHERE t.id = v_my_team_id;

        SELECT cp.name INTO v_plan_name
        FROM public.control_plans cp
        WHERE cp.id = v_plan_id;

        v_creator_name := public.driver_display_name(v_team.created_by);

        SELECT b.scheduled_start, b.scheduled_end
        INTO v_bounds
        FROM public.control_team_schedule_bounds(v_team, v_plan_start) b;

        v_mission_end := v_bounds.scheduled_end;

        IF v_can_view_full THEN
            SELECT COALESCE(
                jsonb_agg(cpi.content ORDER BY cpi.sort_order),
                '[]'::jsonb
            )
            INTO v_plan_instructions
            FROM public.control_plan_instructions cpi
            WHERE cpi.plan_id = v_plan_id;

            SELECT COALESCE(
                jsonb_agg(
                    jsonb_build_object(
                        'id', m.id,
                        'user_id', m.user_id,
                        'invitation_status', m.invitation_status,
                        'mentions', m.mentions
                    )
                ),
                '[]'::jsonb
            )
            INTO v_team_members
            FROM public.team_members m
            WHERE m.team_id = v_team.id
              AND m.invitation_status <> 'removed';

            v_current_mission := jsonb_build_object(
                'id', v_my_team_id::text,
                'control_plan_id', v_plan_id,
                'plan_name', v_plan_name,
                'team_id', v_my_team_id::text,
                'team_name', v_team.name,
                'scheduled_start', v_bounds.scheduled_start,
                'scheduled_end', v_bounds.scheduled_end,
                'creator_name', v_creator_name,
                'status', 'assigned',
                'zone_id', NULLIF(btrim(v_team.zone), ''),
                'zone_label', COALESCE(NULLIF(btrim(v_team.zone), ''), 'zone'),
                'line_id', NULLIF(btrim(v_team.line_id), ''),
                'instructions', v_plan_instructions,
                'team_members', v_team_members
            );
        ELSE
            v_current_mission := jsonb_build_object(
                'id', v_my_team_id::text,
                'control_plan_id', v_plan_id,
                'plan_name', v_plan_name,
                'team_id', v_my_team_id::text,
                'team_name', v_team.name,
                'scheduled_start', v_bounds.scheduled_start,
                'scheduled_end', v_bounds.scheduled_end,
                'creator_name', v_creator_name,
                'status', 'assigned'
            );
        END IF;
    END IF;

    v_effective_status := v_my_invitation_status;
    IF v_my_invitation_status = 'invited'
       AND v_mission_end IS NOT NULL
       AND v_mission_end < NOW() THEN
        v_effective_status := 'expired';
    END IF;

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
            'line_id', CASE WHEN v_can_view_full THEN t.line_id ELSE NULL END,
            'vehicle_id', CASE WHEN v_can_view_full THEN t.vehicle_id ELSE NULL END,
            'zone', CASE WHEN v_can_view_full THEN t.zone ELSE NULL END,
            'instructions', CASE WHEN v_can_view_full THEN t.instructions ELSE '[]'::jsonb END,
            'created_at', t.created_at,
            'team_members', CASE
                WHEN v_can_view_full THEN COALESCE(
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
                ELSE '[]'::jsonb
            END
        ) AS team_row
        FROM public.teams t
        WHERE t.type = 'control'
          AND (
              v_plan_id IS NULL
              OR EXISTS (
                  SELECT 1 FROM public.control_plan_teams cpt
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
        'my_invitation_status', v_my_invitation_status,
        'my_invitation_effective_status', v_effective_status,
        'is_creator', v_is_creator,
        'can_view_full', v_can_view_full,
        'current_mission', v_current_mission,
        'teams', v_teams
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.control_team_schedule_bounds(public.teams, DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_control_plan_context() TO authenticated;
