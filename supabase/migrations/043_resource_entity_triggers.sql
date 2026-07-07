-- Sync entités métier → resources + channels (Phase 4)
-- Architecture resource-first

ALTER TABLE public.teams
    ADD COLUMN IF NOT EXISTS resource_id UUID REFERENCES public.resources(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_teams_resource ON public.teams(resource_id);

-- Map driver UUID → auth user_profiles.id
CREATE OR REPLACE FUNCTION public.driver_auth_user_id(p_driver_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(
        d.user_id,
        (SELECT up.id FROM public.user_profiles up
         JOIN public.drivers d2 ON d2.id = p_driver_id
         WHERE lower(up.id::text) = lower(d2.user_id::text)
         LIMIT 1)
    )
    FROM public.drivers d
    WHERE d.id = p_driver_id
    LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.driver_auth_user_id(UUID) TO authenticated;

-- Sync team → resource + channel + members
CREATE OR REPLACE FUNCTION public.sync_team_resource(p_team_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_team public.teams%ROWTYPE;
    v_resource_id UUID;
    v_channel_id UUID;
    v_member RECORD;
    v_auth_user UUID;
    v_role_id UUID;
BEGIN
    SELECT * INTO v_team FROM public.teams WHERE id = p_team_id;
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    v_resource_id := public.upsert_platform_resource(
        'team',
        v_team.name,
        p_team_id::text,
        '00000000-0000-4000-8000-000000000100'::uuid,
        'temporary',
        jsonb_build_object(
            'refs', jsonb_strip_nulls(jsonb_build_array(
                CASE WHEN v_team.line_id IS NOT NULL THEN
                    jsonb_build_object('resource', 'line', 'id', v_team.line_id)
                END,
                CASE WHEN v_team.vehicle_id IS NOT NULL THEN
                    jsonb_build_object('resource', 'vehicle', 'id', v_team.vehicle_id)
                END
            ))
        ),
        jsonb_build_object(
            'status', v_team.status,
            'line_id', v_team.line_id,
            'vehicle_id', v_team.vehicle_id,
            'zone', v_team.zone
        )
    );

    UPDATE public.teams SET resource_id = v_resource_id WHERE id = p_team_id;

    v_channel_id := public.ensure_discussion_channel(v_resource_id);

    SELECT id INTO v_role_id FROM public.roles WHERE key = 'channel_member' LIMIT 1;

    FOR v_member IN
        SELECT tm.* FROM public.team_members tm
        WHERE tm.team_id = p_team_id
          AND tm.invitation_status IN ('accepted', 'invited', 'pending')
    LOOP
        v_auth_user := public.driver_auth_user_id(v_member.user_id);
        IF v_auth_user IS NULL THEN
            CONTINUE;
        END IF;

        INSERT INTO public.channel_members (channel_id, user_id, status)
        VALUES (v_channel_id, v_auth_user, 'active')
        ON CONFLICT (channel_id, user_id) DO UPDATE SET status = 'active';

        IF v_role_id IS NOT NULL THEN
            INSERT INTO public.member_roles (user_id, role_id, channel_id, resource_id)
            VALUES (v_auth_user, v_role_id, v_channel_id, v_resource_id)
            ON CONFLICT DO NOTHING;
        END IF;

        -- Rôle métier depuis mentions (pad, chef, tpe)
        IF v_member.mentions ? 'PAD' OR v_member.mentions::text ILIKE '%PAD%' THEN
            SELECT id INTO v_role_id FROM public.roles WHERE key = 'pad' LIMIT 1;
            IF v_role_id IS NOT NULL THEN
                INSERT INTO public.member_roles (user_id, role_id, channel_id, resource_id)
                VALUES (v_auth_user, v_role_id, v_channel_id, v_resource_id)
                ON CONFLICT DO NOTHING;
            END IF;
        END IF;
    END LOOP;

    INSERT INTO public.resource_events (
        resource_id, channel_id, event_type, actor_id, payload
    ) VALUES (
        v_resource_id, v_channel_id, 'team_synced', auth.uid(),
        jsonb_build_object('team_id', p_team_id)
    );

    RETURN v_resource_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_teams_sync_resource()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public.sync_team_resource(NEW.id);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_teams_sync_resource ON public.teams;
CREATE TRIGGER trg_teams_sync_resource
    AFTER INSERT OR UPDATE OF name, status, line_id, vehicle_id ON public.teams
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_teams_sync_resource();

CREATE OR REPLACE FUNCTION public.trg_team_members_sync_resource()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    PERFORM public.sync_team_resource(
        COALESCE(NEW.team_id, OLD.team_id)
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_team_members_sync ON public.team_members;
CREATE TRIGGER trg_team_members_sync
    AFTER INSERT OR UPDATE OR DELETE ON public.team_members
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_team_members_sync_resource();

-- control_plans → resource
CREATE OR REPLACE FUNCTION public.sync_control_plan_resource(p_plan_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_plan public.control_plans%ROWTYPE;
    v_resource_id UUID;
BEGIN
    SELECT * INTO v_plan FROM public.control_plans WHERE id = p_plan_id;
    IF NOT FOUND THEN RETURN NULL; END IF;

    v_resource_id := public.upsert_platform_resource(
        'control_plan',
        v_plan.name,
        p_plan_id::text,
        '00000000-0000-4000-8000-000000000100'::uuid,
        'temporary',
        '{}'::jsonb,
        jsonb_build_object(
            'objective', v_plan.objective,
            'status', v_plan.status,
            'start_date', v_plan.start_date,
            'end_date', v_plan.end_date
        )
    );

    PERFORM public.ensure_discussion_channel(v_resource_id);

    -- Transition lifecycle
    IF v_plan.status IN ('completed', 'suspended') THEN
        UPDATE public.resources
        SET status = CASE v_plan.status
            WHEN 'completed' THEN 'archived'
            ELSE 'closed'
        END,
        updated_at = NOW()
        WHERE id = v_resource_id;
    END IF;

    RETURN v_resource_id;
END;
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'control_plans'
    ) THEN
        EXECUTE $fn$
        CREATE OR REPLACE FUNCTION public.trg_control_plans_sync_resource()
        RETURNS TRIGGER
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = public
        AS $body$
        BEGIN
            PERFORM public.sync_control_plan_resource(NEW.id);
            RETURN NEW;
        END;
        $body$;

        DROP TRIGGER IF EXISTS trg_control_plans_sync ON public.control_plans;
        CREATE TRIGGER trg_control_plans_sync
            AFTER INSERT OR UPDATE OF name, status ON public.control_plans
            FOR EACH ROW
            EXECUTE FUNCTION public.trg_control_plans_sync_resource();
        $fn$;
    END IF;
END $$;

-- msr_missions avec control_plan_id / team_id (040+)
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
    LEFT JOIN public.teams t ON t.id = m.team_id
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

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'msr_missions'
          AND column_name = 'team_id'
    ) THEN
        EXECUTE $fn$
        CREATE OR REPLACE FUNCTION public.trg_msr_missions_sync_resource()
        RETURNS TRIGGER
        LANGUAGE plpgsql
        SECURITY DEFINER
        SET search_path = public
        AS $body$
        BEGIN
            PERFORM public.sync_mission_resource(NEW.id);
            RETURN NEW;
        END;
        $body$;

        DROP TRIGGER IF EXISTS trg_msr_missions_sync ON public.msr_missions;
        CREATE TRIGGER trg_msr_missions_sync
            AFTER INSERT OR UPDATE OF status, team_id ON public.msr_missions
            FOR EACH ROW
            EXECUTE FUNCTION public.trg_msr_missions_sync_resource();
        $fn$;
    END IF;
END $$;

-- Backfill équipes existantes
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT id FROM public.teams WHERE resource_id IS NULL LOOP
        PERFORM public.sync_team_resource(r.id);
    END LOOP;
END $$;
