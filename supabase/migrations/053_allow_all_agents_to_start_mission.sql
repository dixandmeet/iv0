-- Migration: Allow all accepted team members to start and complete control missions.
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
    v_started TIMESTAMPTZ;
    v_duration_min INT;
    v_pad_name TEXT;
    v_debrief JSONB;
BEGIN
    v_driver_id := public.current_driver_id();
    SELECT * INTO v_mission FROM public.msr_missions WHERE id = p_mission_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Mission introuvable');
    END IF;

    v_team_id := v_mission.team_id::uuid;

    IF p_action = 'start' THEN
        -- Check if driver is a member of the team and has accepted
        IF NOT EXISTS (
            SELECT 1 FROM public.team_members tm
            WHERE tm.team_id = v_team_id
              AND tm.user_id = v_driver_id
              AND tm.invitation_status = 'accepted'
        ) THEN
            RETURN jsonb_build_object('success', false, 'message', 'Seul un membre de l''équipe ayant accepté peut démarrer l''intervention');
        END IF;

        IF v_mission.status <> 'assigned' THEN
            RETURN jsonb_build_object('success', false, 'message', 'Mission déjà démarrée ou terminée');
        END IF;

        v_started := NOW();
        UPDATE public.msr_missions
        SET status = 'in_progress', intervention_started_at = v_started, updated_at = NOW()
        WHERE id = p_mission_id;

        PERFORM public.log_mission_event(
            v_mission.control_plan_id, 'MISSION_STARTED', v_driver_id,
            jsonb_build_object('mission_id', p_mission_id)
        );

        RETURN jsonb_build_object(
            'success', true, 'status', 'in_progress',
            'message', 'Intervention démarrée'
        );
    END IF;

    IF p_action = 'complete' THEN
        -- Check if driver is a member of the team and has accepted
        IF NOT EXISTS (
            SELECT 1 FROM public.team_members tm
            WHERE tm.team_id = v_team_id
              AND tm.user_id = v_driver_id
              AND tm.invitation_status = 'accepted'
        ) THEN
            RETURN jsonb_build_object('success', false, 'message', 'Seul un membre de l''équipe ayant accepté peut terminer l''intervention');
        END IF;

        IF v_mission.status <> 'in_progress' THEN
            RETURN jsonb_build_object('success', false, 'message', 'Mission non en cours');
        END IF;

        UPDATE public.msr_missions
        SET status = 'completed', updated_at = NOW()
        WHERE id = p_mission_id;

        v_duration_min := EXTRACT(EPOCH FROM (NOW() - COALESCE(v_mission.intervention_started_at, v_mission.scheduled_start)))::INT / 60;

        SELECT public.driver_display_name(tm.user_id) INTO v_pad_name
        FROM public.team_members tm
        WHERE tm.team_id = v_team_id AND (tm.mentions::text ILIKE '%PAD%')
        LIMIT 1;

        v_debrief := jsonb_build_object(
            'mission_name', (SELECT name FROM public.control_plans WHERE id = v_mission.control_plan_id),
            'duration_minutes', v_duration_min,
            'team_size', (SELECT COUNT(*) FROM public.team_members WHERE team_id = v_team_id AND invitation_status = 'accepted'),
            'pad_name', v_pad_name,
            'incidents_count', 0,
            'notes_count', 0,
            'started_at', v_mission.intervention_started_at,
            'completed_at', NOW()
        );

        PERFORM public.log_mission_event(
            v_mission.control_plan_id, 'MISSION_COMPLETED', v_driver_id,
            jsonb_build_object('mission_id', p_mission_id, 'debrief', v_debrief)
        );

        RETURN jsonb_build_object(
            'success', true, 'status', 'completed',
            'message', 'Intervention terminée',
            'debrief', v_debrief
        );
    END IF;

    RETURN jsonb_build_object('success', false, 'message', 'Action inconnue');
END;
$$;
