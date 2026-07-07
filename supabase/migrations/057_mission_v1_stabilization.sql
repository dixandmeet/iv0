-- 057 — Stabilisation du parcours Mission V1
--
-- Règle métier : tout membre ayant accepté peut démarrer une mission lorsque
-- la checklist est complète. La clôture reste réservée au PAD.

-- ---------------------------------------------------------------------------
-- Readiness : un refus bloque tant que le membre n'est pas remplacé/retiré.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mission_team_readiness(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_has_pad BOOLEAN := false;
    v_has_chef BOOLEAN := false;
    v_has_tpe BOOLEAN := false;
    v_joined INT := 0;
    v_total INT := 0;
    v_present INT := 0;
    v_blocking TEXT := NULL;
    v_items JSONB;
    v_ready BOOLEAN;
    v_pending JSONB := '[]'::jsonb;
    v_member RECORD;
BEGIN
    IF p_team_id IS NULL THEN
        RETURN jsonb_build_object(
            'items', '[]'::jsonb,
            'ready', false,
            'blocking_label', 'Équipe introuvable',
            'joined_count', 0,
            'joined_total', 0,
            'present_count', 0
        );
    END IF;

    SELECT
        bool_or(mentions::text ILIKE '%PAD%')
            FILTER (WHERE invitation_status NOT IN ('removed', 'declined')),
        bool_or(mentions::text ILIKE '%Chef%')
            FILTER (WHERE invitation_status NOT IN ('removed', 'declined')),
        bool_or(mentions::text ILIKE '%TPE%')
            FILTER (WHERE invitation_status NOT IN ('removed', 'declined')),
        COUNT(*) FILTER (WHERE invitation_status = 'accepted'),
        COUNT(*) FILTER (WHERE invitation_status <> 'removed'),
        COUNT(*) FILTER (
            WHERE invitation_status = 'accepted'
              AND presence_status = 'present'
        )
    INTO v_has_pad, v_has_chef, v_has_tpe, v_joined, v_total, v_present
    FROM public.team_members
    WHERE team_id = p_team_id;

    v_has_pad := COALESCE(v_has_pad, false);
    v_has_chef := COALESCE(v_has_chef, false);
    v_has_tpe := COALESCE(v_has_tpe, false);

    FOR v_member IN
        SELECT
            tm.invitation_status,
            tm.presence_status,
            public.driver_display_name(tm.user_id) AS display_name
        FROM public.team_members tm
        WHERE tm.team_id = p_team_id
          AND tm.invitation_status <> 'removed'
        ORDER BY tm.created_at
    LOOP
        IF v_member.invitation_status = 'invited' THEN
            v_pending := v_pending || jsonb_build_array(v_member.display_name);
            IF v_blocking IS NULL THEN
                v_blocking := v_member.display_name || ' n''a pas encore accepté';
            END IF;
        ELSIF v_member.invitation_status = 'declined' AND v_blocking IS NULL THEN
            v_blocking := v_member.display_name || ' a refusé la mission';
        ELSIF v_member.invitation_status = 'accepted'
              AND COALESCE(v_member.presence_status, 'participant') <> 'present'
              AND v_blocking IS NULL THEN
            v_blocking := v_member.display_name || ' n''est pas encore arrivé';
        END IF;
    END LOOP;

    v_items := jsonb_build_array(
        jsonb_build_object('key', 'pad', 'label', 'PAD désigné', 'done', v_has_pad),
        jsonb_build_object('key', 'chef', 'label', 'Chef désigné', 'done', v_has_chef),
        jsonb_build_object('key', 'tpe', 'label', 'TPE désigné', 'done', v_has_tpe),
        jsonb_build_object(
            'key', 'all_joined',
            'label', 'Tous les agents ont accepté',
            'done', v_total > 0 AND v_joined = v_total,
            'blocking', CASE
                WHEN v_total > 0 AND v_joined = v_total THEN NULL
                ELSE v_blocking
            END
        ),
        jsonb_build_object(
            'key', 'all_present',
            'label', 'Tous les agents sont présents',
            'done', v_joined > 0 AND v_present = v_joined,
            'blocking', v_blocking
        )
    );

    v_ready := v_has_pad AND v_has_chef AND v_has_tpe
        AND v_total > 0 AND v_joined = v_total
        AND v_present = v_joined;

    RETURN jsonb_build_object(
        'items', v_items,
        'ready', v_ready,
        'blocking_label', CASE WHEN v_ready THEN NULL ELSE
            COALESCE(v_blocking, 'Préparation incomplète') END,
        'joined_count', v_joined,
        'joined_total', v_total,
        'present_count', v_present,
        'pending_invitations', v_pending
    );
END;
$$;

-- ---------------------------------------------------------------------------
-- Invitations : charge réellement la mission avant le contrôle d'expiration.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.respond_team_invitation(
    p_team_id UUID,
    p_accept BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_member public.team_members%ROWTYPE;
    v_mission public.msr_missions%ROWTYPE;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false, 'status', 'error',
            'message', 'Session conducteur introuvable'
        );
    END IF;

    SELECT * INTO v_member
    FROM public.team_members tm
    WHERE tm.team_id = p_team_id AND tm.user_id = v_driver_id
    FOR UPDATE;

    IF NOT FOUND OR v_member.invitation_status = 'removed' THEN
        RETURN jsonb_build_object(
            'success', false, 'status', 'error',
            'message', 'Invitation introuvable'
        );
    END IF;

    SELECT * INTO v_mission
    FROM public.msr_missions m
    WHERE m.team_id = p_team_id::text
    ORDER BY m.updated_at DESC NULLS LAST
    LIMIT 1;

    IF FOUND
       AND v_mission.scheduled_end IS NOT NULL
       AND v_mission.scheduled_end < NOW()
       AND v_member.invitation_status = 'invited' THEN
        RETURN jsonb_build_object(
            'success', false, 'status', 'expired',
            'message', 'Mission dépassée — invitation inactive'
        );
    END IF;

    IF p_accept THEN
        UPDATE public.team_members
        SET invitation_status = 'accepted',
            accepted_at = COALESCE(accepted_at, NOW()),
            declined_at = NULL,
            presence_status = COALESCE(presence_status, 'participant')
        WHERE id = v_member.id;

        IF v_mission.control_plan_id IS NOT NULL
           AND v_member.invitation_status <> 'accepted' THEN
            PERFORM public.log_mission_event(
                v_mission.control_plan_id, 'MEMBER_JOINED', v_driver_id,
                jsonb_build_object('team_id', p_team_id)
            );
        END IF;

        RETURN jsonb_build_object(
            'success', true, 'status', 'accepted',
            'message', 'Vous avez rejoint la mission'
        );
    END IF;

    UPDATE public.team_members
    SET invitation_status = 'declined',
        declined_at = COALESCE(declined_at, NOW()),
        accepted_at = NULL,
        presence_status = NULL
    WHERE id = v_member.id;

    IF v_mission.control_plan_id IS NOT NULL
       AND v_member.invitation_status <> 'declined' THEN
        PERFORM public.log_mission_event(
            v_mission.control_plan_id, 'MEMBER_DECLINED', v_driver_id,
            jsonb_build_object('team_id', p_team_id)
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true, 'status', 'declined',
        'message', 'Invitation refusée'
    );
END;
$$;

-- ---------------------------------------------------------------------------
-- Transitions atomiques.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.transition_control_mission(
    p_mission_id UUID,
    p_action TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_mission public.msr_missions%ROWTYPE;
    v_team_id UUID;
    v_readiness JSONB;
    v_started TIMESTAMPTZ;
    v_completed TIMESTAMPTZ;
    v_duration_min INT;
    v_pad_name TEXT;
    v_responsible_name TEXT;
    v_debrief JSONB;
BEGIN
    v_driver_id := public.current_driver_id();
    SELECT * INTO v_mission
    FROM public.msr_missions
    WHERE id = p_mission_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Mission introuvable');
    END IF;
    IF v_mission.team_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Équipe introuvable');
    END IF;
    v_team_id := v_mission.team_id::uuid;

    IF p_action = 'start' THEN
        IF NOT EXISTS (
            SELECT 1
            FROM public.team_members tm
            WHERE tm.team_id = v_team_id
              AND tm.user_id = v_driver_id
              AND tm.invitation_status = 'accepted'
        ) THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Seul un participant ayant accepté peut démarrer l''intervention'
            );
        END IF;

        IF v_mission.status <> 'assigned' THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Mission déjà démarrée ou terminée'
            );
        END IF;

        v_readiness := public.mission_team_readiness(v_team_id);
        IF NOT COALESCE((v_readiness->>'ready')::boolean, false) THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'not_ready',
                'message', COALESCE(
                    v_readiness->>'blocking_label',
                    'La checklist de préparation est incomplète'
                ),
                'readiness', v_readiness
            );
        END IF;

        v_started := NOW();
        UPDATE public.msr_missions
        SET status = 'in_progress',
            intervention_started_at = v_started,
            updated_at = v_started
        WHERE id = p_mission_id AND status = 'assigned';

        IF NOT FOUND THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Mission déjà démarrée'
            );
        END IF;

        PERFORM public.log_mission_event(
            v_mission.control_plan_id, 'MISSION_STARTED', v_driver_id,
            jsonb_build_object('mission_id', p_mission_id)
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'in_progress',
            'message', 'Intervention démarrée'
        );
    END IF;

    IF p_action = 'complete' THEN
        IF NOT public.driver_has_pad_mention(v_team_id, v_driver_id) THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Seul le PAD peut terminer l''intervention'
            );
        END IF;
        IF v_mission.status <> 'in_progress' THEN
            RETURN jsonb_build_object('success', false, 'message', 'Mission non en cours');
        END IF;

        v_completed := NOW();
        UPDATE public.msr_missions
        SET status = 'completed', updated_at = v_completed
        WHERE id = p_mission_id AND status = 'in_progress';

        IF NOT FOUND THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Mission déjà terminée'
            );
        END IF;

        v_duration_min := GREATEST(
            0,
            EXTRACT(EPOCH FROM (
                v_completed - COALESCE(
                    v_mission.intervention_started_at,
                    v_mission.scheduled_start,
                    v_completed
                )
            ))::INT / 60
        );

        SELECT public.driver_display_name(tm.user_id)
        INTO v_pad_name
        FROM public.team_members tm
        WHERE tm.team_id = v_team_id
          AND tm.invitation_status = 'accepted'
          AND tm.mentions::text ILIKE '%PAD%'
        LIMIT 1;

        SELECT up.display_name
        INTO v_responsible_name
        FROM public.control_plans cp
        LEFT JOIN public.user_profiles up
          ON up.id = cp.operational_responsible_id
        WHERE cp.id = v_mission.control_plan_id;

        SELECT jsonb_build_object(
            'mission_name', cp.name,
            'duration_minutes', v_duration_min,
            'team_size', (
                SELECT COUNT(*)
                FROM public.team_members
                WHERE team_id = v_team_id
                  AND invitation_status = 'accepted'
            ),
            'pad_name', v_pad_name,
            'operational_responsible_name', v_responsible_name,
            'incidents_count', 0,
            'notes_count', 0,
            'started_at', v_mission.intervention_started_at,
            'completed_at', v_completed,
            'display_number', cp.mission_display_number,
            'reference_code', cp.mission_reference
        )
        INTO v_debrief
        FROM public.control_plans cp
        WHERE cp.id = v_mission.control_plan_id;

        PERFORM public.log_mission_event(
            v_mission.control_plan_id, 'MISSION_COMPLETED', v_driver_id,
            jsonb_build_object('mission_id', p_mission_id, 'debrief', v_debrief)
        );

        RETURN jsonb_build_object(
            'success', true,
            'status', 'completed',
            'message', 'Intervention terminée',
            'debrief', v_debrief
        );
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'Action inconnue');
END;
$$;

-- ---------------------------------------------------------------------------
-- Contexte isolé d'un workspace.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.control_mission_workspace_context(
    p_mission_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_user_id UUID;
    v_mission public.msr_missions%ROWTYPE;
    v_plan public.control_plans%ROWTYPE;
    v_team public.teams%ROWTYPE;
    v_invitation_status TEXT;
    v_effective_status TEXT;
    v_is_creator BOOLEAN := false;
    v_can_view_full BOOLEAN := false;
    v_members JSONB := '[]'::jsonb;
    v_instructions JSONB := '[]'::jsonb;
    v_plan_json JSONB;
    v_mission_json JSONB;
    v_team_json JSONB;
    v_channel_id UUID;
    v_responsible_name TEXT;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object('current_mission', NULL, 'teams', '[]'::jsonb);
    END IF;

    SELECT d.user_id INTO v_user_id
    FROM public.drivers d
    WHERE d.id = v_driver_id;

    SELECT * INTO v_mission
    FROM public.msr_missions
    WHERE id = p_mission_id;
    IF NOT FOUND OR v_mission.team_id IS NULL THEN
        RETURN jsonb_build_object('current_mission', NULL, 'teams', '[]'::jsonb);
    END IF;

    SELECT * INTO v_plan
    FROM public.control_plans
    WHERE id = v_mission.control_plan_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('current_mission', NULL, 'teams', '[]'::jsonb);
    END IF;
    SELECT * INTO v_team
    FROM public.teams
    WHERE id::text = v_mission.team_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('current_mission', NULL, 'teams', '[]'::jsonb);
    END IF;

    SELECT tm.invitation_status INTO v_invitation_status
    FROM public.team_members tm
    WHERE tm.team_id = v_team.id AND tm.user_id = v_driver_id;

    v_is_creator := v_plan.created_by = v_user_id;
    IF v_invitation_status IS NULL AND NOT v_is_creator THEN
        RETURN jsonb_build_object('current_mission', NULL, 'teams', '[]'::jsonb);
    END IF;

    v_can_view_full := v_is_creator OR v_invitation_status = 'accepted';
    v_effective_status := v_invitation_status;
    IF v_invitation_status = 'invited'
       AND v_mission.scheduled_end IS NOT NULL
       AND v_mission.scheduled_end < NOW() THEN
        v_effective_status := 'expired';
    END IF;

    IF v_can_view_full THEN
        SELECT COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'id', tm.id,
                    'user_id', tm.user_id,
                    'invitation_status', tm.invitation_status,
                    'mentions', tm.mentions,
                    'presence_status', tm.presence_status,
                    'display_name', public.driver_display_name(tm.user_id),
                    'driver_number', d.driver_number
                )
                ORDER BY tm.created_at
            ),
            '[]'::jsonb
        )
        INTO v_members
        FROM public.team_members tm
        LEFT JOIN public.drivers d ON d.id = tm.user_id
        WHERE tm.team_id = v_team.id
          AND tm.invitation_status <> 'removed';

        SELECT COALESCE(
            jsonb_agg(cpi.content ORDER BY cpi.sort_order),
            '[]'::jsonb
        )
        INTO v_instructions
        FROM public.control_plan_instructions cpi
        WHERE cpi.plan_id = v_plan.id;
    END IF;

    SELECT up.display_name INTO v_responsible_name
    FROM public.user_profiles up
    WHERE up.id = v_plan.operational_responsible_id;

    v_channel_id := public.mission_channel_id(v_mission.id);
    v_plan_json := jsonb_build_object(
        'id', v_plan.id,
        'name', v_plan.name,
        'status', v_plan.status,
        'start_date', v_plan.start_date,
        'end_date', v_plan.end_date,
        'objective', v_plan.objective,
        'instructions', v_instructions,
        'priority', v_plan.priority,
        'mission_display_number', v_plan.mission_display_number,
        'mission_reference', v_plan.mission_reference,
        'operational_responsible_name', v_responsible_name
    );

    IF v_can_view_full THEN
        v_mission_json := public.control_mission_full_json(
            v_mission,
            v_plan.name,
            v_team.name,
            public.driver_display_name(v_team.created_by),
            v_instructions,
            v_members,
            COALESCE(
                NULLIF(btrim(v_team.line_id), ''),
                v_mission.zone_config->>'line_id'
            ),
            COALESCE(
                NULLIF(btrim(v_team.zone), ''),
                v_mission.zone_config->>'zone',
                v_mission.zone_id
            )
        );
    ELSE
        v_mission_json := public.control_mission_preview_json(
            v_mission,
            v_plan.name,
            v_team.name,
            public.driver_display_name(v_team.created_by)
        );
    END IF;

    v_mission_json := v_mission_json || jsonb_build_object(
        'full_access', v_can_view_full,
        'invitation_status', v_invitation_status,
        'mission_display_number', v_plan.mission_display_number,
        'objective', v_plan.objective,
        'priority', v_plan.priority,
        'intervention_started_at', v_mission.intervention_started_at,
        'channel_id', v_channel_id
    );

    v_team_json := jsonb_build_object(
        'id', v_team.id,
        'name', v_team.name,
        'type', v_team.type,
        'depot_id', v_team.depot_id,
        'status', v_team.status,
        'departure_time', v_team.departure_time,
        'return_time', v_team.return_time,
        'vacations', v_team.vacations,
        'mobility_mode', v_team.mobility_mode,
        'line_id', CASE WHEN v_can_view_full THEN v_team.line_id ELSE NULL END,
        'vehicle_id', CASE WHEN v_can_view_full THEN v_team.vehicle_id ELSE NULL END,
        'zone', CASE WHEN v_can_view_full THEN v_team.zone ELSE NULL END,
        'instructions', CASE
            WHEN v_can_view_full THEN v_team.instructions
            ELSE '[]'::jsonb
        END,
        'created_at', v_team.created_at,
        'created_by', v_team.created_by,
        'team_members', v_members
    );

    RETURN jsonb_build_object(
        'plan', v_plan_json,
        'my_team_id', v_team.id,
        'my_invitation_status', v_invitation_status,
        'my_invitation_effective_status', v_effective_status,
        'is_creator', v_is_creator,
        'can_view_full', v_can_view_full,
        'current_mission', v_mission_json,
        'teams', jsonb_build_array(v_team_json),
        'team_readiness', CASE
            WHEN v_can_view_full THEN public.mission_team_readiness(v_team.id)
            ELSE NULL
        END,
        'operational_responsible_name', v_responsible_name,
        'connected_count', (
            SELECT COUNT(*)
            FROM public.team_members tm
            WHERE tm.team_id = v_team.id
              AND tm.invitation_status = 'accepted'
              AND tm.last_seen_at > NOW() - INTERVAL '5 minutes'
        ),
        'last_activity_at', (
            SELECT MAX(me.created_at)
            FROM public.mission_events me
            WHERE me.control_plan_id = v_plan.id
        ),
        'channel_id', v_channel_id,
        'message_count', public.mission_message_count(v_channel_id)
    );
END;
$$;

-- ---------------------------------------------------------------------------
-- Historique : conserve les missions refusées et expose les champs terrain.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_control_plan_history(
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_limit INT;
    v_offset INT;
    v_missions JSONB;
    v_has_more BOOLEAN;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object('missions', '[]'::jsonb, 'has_more', false);
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);

    SELECT COALESCE(
        jsonb_agg(row_data ORDER BY scheduled_end DESC NULLS LAST),
        '[]'::jsonb
    )
    INTO v_missions
    FROM (
        SELECT
            m.scheduled_end,
            (
                CASE
                    WHEN tm.invitation_status = 'accepted' THEN
                        public.control_mission_full_json(
                            m,
                            cp.name,
                            t.name,
                            public.driver_display_name(t.created_by),
                            COALESCE((
                                SELECT jsonb_agg(
                                    cpi.content ORDER BY cpi.sort_order
                                )
                                FROM public.control_plan_instructions cpi
                                WHERE cpi.plan_id = m.control_plan_id
                            ), '[]'::jsonb),
                            COALESCE((
                                SELECT jsonb_agg(jsonb_build_object(
                                    'id', mem.id,
                                    'user_id', mem.user_id,
                                    'invitation_status', mem.invitation_status,
                                    'mentions', mem.mentions,
                                    'presence_status', mem.presence_status,
                                    'display_name',
                                        public.driver_display_name(mem.user_id)
                                ))
                                FROM public.team_members mem
                                WHERE mem.team_id::text = m.team_id
                                  AND mem.invitation_status <> 'removed'
                            ), '[]'::jsonb),
                            COALESCE(
                                NULLIF(btrim(t.line_id), ''),
                                m.zone_config->>'line_id'
                            ),
                            COALESCE(
                                NULLIF(btrim(t.zone), ''),
                                m.zone_config->>'zone',
                                m.zone_id
                            )
                        )
                    ELSE
                        public.control_mission_preview_json(
                            m,
                            cp.name,
                            t.name,
                            public.driver_display_name(t.created_by)
                        )
                END
            ) || jsonb_build_object(
                'invitation_status', tm.invitation_status,
                'full_access', tm.invitation_status = 'accepted',
                'mission_display_number', cp.mission_display_number,
                'objective', cp.objective,
                'priority', cp.priority,
                'intervention_started_at', m.intervention_started_at
            ) AS row_data
        FROM public.msr_missions m
        JOIN public.team_members tm ON tm.team_id::text = m.team_id
        JOIN public.teams t ON t.id = tm.team_id
        LEFT JOIN public.control_plans cp ON cp.id = m.control_plan_id
        WHERE tm.user_id = v_driver_id
          AND tm.invitation_status <> 'removed'
          AND (
              tm.invitation_status = 'declined'
              OR m.status IN ('completed', 'cancelled')
              OR m.scheduled_end < NOW()
              OR cp.status IN ('completed', 'suspended')
          )
        ORDER BY m.scheduled_end DESC NULLS LAST, m.updated_at DESC
        OFFSET v_offset
        LIMIT v_limit + 1
    ) rows_with_extra;

    v_has_more := jsonb_array_length(v_missions) > v_limit;
    IF v_has_more THEN
        SELECT jsonb_agg(elem)
        INTO v_missions
        FROM (
            SELECT elem
            FROM jsonb_array_elements(v_missions)
                WITH ORDINALITY AS expanded(elem, ord)
            WHERE ord <= v_limit
        ) trimmed;
    END IF;

    RETURN jsonb_build_object(
        'missions', COALESCE(v_missions, '[]'::jsonb),
        'has_more', v_has_more
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.update_control_mission_metadata(
    p_plan_id UUID,
    p_objective TEXT,
    p_priority TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_user_id UUID;
    v_objective TEXT;
BEGIN
    v_driver_id := public.current_driver_id();
    SELECT d.user_id INTO v_user_id
    FROM public.drivers d
    WHERE d.id = v_driver_id;

    IF NOT EXISTS (
        SELECT 1
        FROM public.control_plans cp
        WHERE cp.id = p_plan_id AND cp.created_by = v_user_id
    ) THEN
        RAISE EXCEPTION 'Modification réservée au créateur';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM public.msr_missions m
        WHERE m.control_plan_id = p_plan_id
          AND m.status <> 'assigned'
    ) THEN
        RAISE EXCEPTION 'Mission verrouillée après le démarrage';
    END IF;

    v_objective := btrim(p_objective);
    IF v_objective IS NULL OR length(v_objective) < 3 THEN
        RAISE EXCEPTION 'Objectif invalide';
    END IF;
    IF p_priority NOT IN ('low', 'medium', 'high') THEN
        RAISE EXCEPTION 'Priorité invalide';
    END IF;

    UPDATE public.control_plans
    SET objective = v_objective,
        priority = p_priority,
        updated_at = NOW()
    WHERE id = p_plan_id;

    PERFORM public.log_mission_event(
        p_plan_id,
        'MISSION_UPDATED',
        v_driver_id,
        jsonb_build_object(
            'objective', v_objective,
            'priority', p_priority
        )
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.respond_team_invitation(UUID, BOOLEAN)
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_control_mission(UUID, TEXT)
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.control_mission_workspace_context(UUID)
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_control_plan_history(INT, INT)
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_control_mission_metadata(
    UUID, TEXT, TEXT
) TO authenticated;

-- ---------------------------------------------------------------------------
-- Projection des événements Mission vers le Hub et ses notifications realtime.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.log_mission_event(
    p_plan_id UUID,
    p_event_type TEXT,
    p_actor_driver_id UUID DEFAULT NULL,
    p_payload JSONB DEFAULT '{}'::jsonb
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_resource_id UUID;
    v_channel_id UUID;
    v_actor_user_id UUID;
    v_body TEXT;
BEGIN
    INSERT INTO public.mission_events (
        control_plan_id, event_type, actor_driver_id, payload
    ) VALUES (
        p_plan_id, p_event_type, p_actor_driver_id, p_payload
    );
    INSERT INTO public.mission_audit_log (
        control_plan_id, event_type, actor_driver_id, payload
    ) VALUES (
        p_plan_id, p_event_type, p_actor_driver_id, p_payload
    );

    SELECT r.id, ch.id
    INTO v_resource_id, v_channel_id
    FROM public.msr_missions m
    JOIN public.resources r
      ON r.type = 'mission' AND r.external_id = m.id::text
    LEFT JOIN public.channels ch ON ch.resource_id = r.id
    WHERE m.control_plan_id = p_plan_id
    ORDER BY m.updated_at DESC NULLS LAST
    LIMIT 1;

    SELECT d.user_id INTO v_actor_user_id
    FROM public.drivers d
    WHERE d.id = p_actor_driver_id;

    v_body := CASE p_event_type
        WHEN 'MISSION_CREATED' THEN 'Une mission vous a été proposée'
        WHEN 'MEMBER_JOINED' THEN 'Un agent a rejoint la mission'
        WHEN 'MEMBER_DECLINED' THEN 'Un agent a refusé la mission'
        WHEN 'MEMBER_PRESENT' THEN 'Une présence a été enregistrée'
        WHEN 'ROLE_UPDATED' THEN 'Les rôles de la mission ont été modifiés'
        WHEN 'MISSION_STARTED' THEN 'L''intervention a démarré'
        WHEN 'MISSION_COMPLETED' THEN 'L''intervention est terminée'
        ELSE 'La mission a été mise à jour'
    END;

    IF v_resource_id IS NOT NULL THEN
        INSERT INTO public.resource_events (
            resource_id,
            channel_id,
            event_type,
            actor_id,
            payload,
            priority
        ) VALUES (
            v_resource_id,
            v_channel_id,
            lower(p_event_type),
            v_actor_user_id,
            COALESCE(p_payload, '{}'::jsonb) ||
                jsonb_build_object('body_preview', v_body),
            CASE
                WHEN p_event_type IN ('MISSION_STARTED', 'MISSION_COMPLETED')
                    THEN 'high'
                ELSE 'normal'
            END
        );
    END IF;
END;
$$;
