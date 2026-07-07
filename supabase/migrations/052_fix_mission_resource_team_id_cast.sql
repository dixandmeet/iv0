-- Corrige la synchronisation ressource des missions MSR.
-- msr_missions.team_id est stocké en TEXT alors que teams.id est UUID.
-- Le trigger appelé à la création de mission comparait UUID = TEXT.

CREATE OR REPLACE FUNCTION public.sync_mission_resource(p_mission_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_mission RECORD;
    v_resource_id UUID;
    v_parent UUID;
    v_name TEXT;
BEGIN
    SELECT m.*, t.name AS team_name, t.resource_id AS team_resource_id
    INTO v_mission
    FROM public.msr_missions m
    LEFT JOIN public.teams t ON t.id::text = m.team_id
    WHERE m.id = p_mission_id;

    IF NOT FOUND THEN RETURN NULL; END IF;

    v_name := coalesce(v_mission.team_name, 'Mission MSR');
    v_parent := coalesce(
        v_mission.team_resource_id,
        '00000000-0000-4000-8000-000000000100'::uuid
    );

    v_resource_id := public.upsert_platform_resource(
        'mission',
        v_name,
        p_mission_id::text,
        v_parent,
        'temporary',
        '{}'::jsonb,
        jsonb_build_object('status', v_mission.status)
    );

    PERFORM public.ensure_discussion_channel(v_resource_id);

    IF v_mission.team_resource_id IS NOT NULL THEN
        INSERT INTO public.resource_relations (
            source_resource_id, target_resource_id, relation_type
        ) VALUES (
            v_resource_id, v_mission.team_resource_id, 'assigned_to'
        )
        ON CONFLICT (source_resource_id, target_resource_id, relation_type) DO NOTHING;
    END IF;

    IF v_mission.status IN ('completed', 'cancelled') THEN
        UPDATE public.resources
        SET status = 'closed', updated_at = NOW()
        WHERE id = v_resource_id;
    END IF;

    RETURN v_resource_id;
END;
$$;
