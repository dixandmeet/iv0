-- Mission de contrôle V1 : présence, références, audit/events, readiness, transitions PAD
-- ---------------------------------------------------------------------------

-- Colonnes mission
ALTER TABLE public.control_plans
    ADD COLUMN IF NOT EXISTS operational_responsible_id UUID
        REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS mission_reference TEXT,
    ADD COLUMN IF NOT EXISTS mission_display_number INT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_control_plans_mission_reference
    ON public.control_plans (mission_reference)
    WHERE mission_reference IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_control_plans_display_number
    ON public.control_plans (mission_display_number)
    WHERE mission_display_number IS NOT NULL;

CREATE SEQUENCE IF NOT EXISTS public.mission_display_number_seq START 1;

ALTER TABLE public.msr_missions
    ADD COLUMN IF NOT EXISTS intervention_started_at TIMESTAMPTZ;

ALTER TABLE public.team_members
    ADD COLUMN IF NOT EXISTS presence_status TEXT
        CHECK (presence_status IS NULL OR presence_status IN ('participant', 'present')),
    ADD COLUMN IF NOT EXISTS present_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS presence_confirmed_by UUID,
    ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ;

-- Journal audit + événements métier (timeline V2)
CREATE TABLE IF NOT EXISTS public.mission_audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    control_plan_id UUID NOT NULL REFERENCES public.control_plans(id) ON DELETE CASCADE,
    actor_driver_id UUID,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mission_audit_plan
    ON public.mission_audit_log (control_plan_id, created_at);

CREATE TABLE IF NOT EXISTS public.mission_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    control_plan_id UUID NOT NULL REFERENCES public.control_plans(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    actor_driver_id UUID,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mission_events_plan
    ON public.mission_events (control_plan_id, created_at);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.next_mission_display_number()
RETURNS INT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT nextval('public.mission_display_number_seq')::INT;
$$;

CREATE OR REPLACE FUNCTION public.mission_reference_code(p_date DATE DEFAULT CURRENT_DATE)
RETURNS TEXT
LANGUAGE sql
STABLE
AS $$
    SELECT 'MC-' || to_char(p_date, 'YYYYMMDD') || '-' ||
           lpad(
               (
                   SELECT COUNT(*)::TEXT
                   FROM public.control_plans cp
                   WHERE cp.start_date = p_date
               ),
               2, '0'
           );
$$;

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
END;
$$;

CREATE OR REPLACE FUNCTION public.driver_has_pad_mention(
    p_team_id UUID,
    p_driver_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.team_members tm
        WHERE tm.team_id = p_team_id
          AND tm.user_id = p_driver_id
          AND tm.invitation_status = 'accepted'
          AND (tm.mentions::text ILIKE '%PAD%')
    );
$$;

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
    v_items JSONB := '[]'::jsonb;
    v_ready BOOLEAN := false;
    v_pending JSONB := '[]'::jsonb;
    v_member RECORD;
BEGIN
    IF p_team_id IS NULL THEN
        RETURN jsonb_build_object('items', '[]'::jsonb, 'ready', false, 'blocking_label', NULL);
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.team_members m
        WHERE m.team_id = p_team_id AND m.invitation_status <> 'removed'
          AND (m.mentions::text ILIKE '%PAD%')
    ) INTO v_has_pad;

    SELECT EXISTS (
        SELECT 1 FROM public.team_members m
        WHERE m.team_id = p_team_id AND m.invitation_status <> 'removed'
          AND (m.mentions::text ILIKE '%Chef%')
    ) INTO v_has_chef;

    SELECT EXISTS (
        SELECT 1 FROM public.team_members m
        WHERE m.team_id = p_team_id AND m.invitation_status <> 'removed'
          AND (m.mentions::text ILIKE '%TPE%')
    ) INTO v_has_tpe;

    SELECT
        COUNT(*) FILTER (WHERE invitation_status = 'accepted'),
        COUNT(*) FILTER (WHERE invitation_status NOT IN ('removed', 'declined')),
        COUNT(*) FILTER (
            WHERE invitation_status = 'accepted'
              AND presence_status = 'present'
        )
    INTO v_joined, v_total, v_present
    FROM public.team_members
    WHERE team_id = p_team_id
      AND invitation_status NOT IN ('removed', 'declined');

    FOR v_member IN
        SELECT tm.user_id, tm.invitation_status, tm.presence_status,
               public.driver_display_name(tm.user_id) AS display_name
        FROM public.team_members tm
        WHERE tm.team_id = p_team_id
          AND tm.invitation_status = 'invited'
    LOOP
        v_pending := v_pending || jsonb_build_array(v_member.display_name);
    END LOOP;

    FOR v_member IN
        SELECT public.driver_display_name(tm.user_id) AS display_name
        FROM public.team_members tm
        WHERE tm.team_id = p_team_id
          AND tm.invitation_status = 'accepted'
          AND COALESCE(tm.presence_status, 'participant') <> 'present'
    LOOP
        IF v_blocking IS NULL THEN
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
            'done', v_total > 0 AND v_joined = v_total
        ),
        jsonb_build_object(
            'key', 'all_present',
            'label', 'Tous les agents sont présents',
            'done', v_joined > 0 AND v_present = v_joined,
            'blocking', v_blocking
        )
    );

    v_ready := v_has_pad AND v_has_chef AND v_has_tpe
        AND v_total > 0 AND v_joined = v_total AND v_joined > 0
        AND v_present = v_joined;

    RETURN jsonb_build_object(
        'items', v_items,
        'ready', v_ready,
        'blocking_label', NULL,
        'joined_count', v_joined,
        'joined_total', v_total,
        'present_count', v_present,
        'pending_invitations', v_pending
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.mission_channel_id(p_mission_id UUID)
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT ch.id
    FROM public.resources r
    JOIN public.channels ch ON ch.resource_id = r.id
    WHERE r.type = 'mission'
      AND r.external_id = p_mission_id::text
    LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.mission_message_count(p_channel_id UUID)
RETURNS INT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COUNT(*)::INT
    FROM public.messages msg
    WHERE msg.channel_id = p_channel_id
      AND msg.deleted_at IS NULL;
$$;

-- ---------------------------------------------------------------------------
-- respond_team_invitation : + participant + message terrain
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
    v_plan_id UUID;
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

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false, 'status', 'error',
            'message', 'Invitation introuvable'
        );
    END IF;

    IF v_member.invitation_status = 'removed' THEN
        RETURN jsonb_build_object(
            'success', false, 'status', 'error',
            'message', 'Vous avez été retiré de cette équipe'
        );
    END IF;

    SELECT m.control_plan_id INTO v_plan_id
    FROM public.msr_missions m
    WHERE m.team_id = p_team_id::text
    ORDER BY m.updated_at DESC NULLS LAST
    LIMIT 1;

    IF FOUND AND v_mission.scheduled_end IS NOT NULL
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
            accepted_at = NOW(),
            declined_at = NULL,
            presence_status = 'participant'
        WHERE id = v_member.id;

        IF v_plan_id IS NOT NULL THEN
            PERFORM public.log_mission_event(
                v_plan_id, 'MEMBER_JOINED', v_driver_id,
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
        declined_at = NOW(),
        accepted_at = NULL
    WHERE id = v_member.id;

    IF v_plan_id IS NOT NULL THEN
        PERFORM public.log_mission_event(
            v_plan_id, 'MEMBER_DECLINED', v_driver_id,
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
-- Présence
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.declare_team_presence(p_team_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_plan_id UUID;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Session introuvable');
    END IF;

    UPDATE public.team_members tm
    SET presence_status = 'present',
        present_at = NOW(),
        last_seen_at = NOW()
  WHERE tm.team_id = p_team_id
      AND tm.user_id = v_driver_id
      AND tm.invitation_status = 'accepted'
      AND COALESCE(tm.presence_status, 'participant') <> 'present';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Présence déjà enregistrée ou non autorisée');
    END IF;

    SELECT m.control_plan_id INTO v_plan_id
    FROM public.msr_missions m
    WHERE m.team_id = p_team_id::text
    ORDER BY m.updated_at DESC NULLS LAST LIMIT 1;

    IF v_plan_id IS NOT NULL THEN
        PERFORM public.log_mission_event(
            v_plan_id, 'MEMBER_PRESENT', v_driver_id,
            jsonb_build_object('team_id', p_team_id, 'method', 'manual')
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'presence_status', 'present',
        'message', 'Présence enregistrée'
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_team_presence(
    p_team_id UUID,
    p_lat DOUBLE PRECISION,
    p_lng DOUBLE PRECISION
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_depot_geom GEOMETRY;
    v_distance DOUBLE PRECISION;
    v_plan_id UUID;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Session introuvable');
    END IF;

    UPDATE public.team_members
    SET last_seen_at = NOW()
    WHERE team_id = p_team_id AND user_id = v_driver_id;

    SELECT ST_Distance(
        d.geom::geography,
        ST_SetSRID(ST_Point(p_lng, p_lat), 4326)::geography
    )
    INTO v_distance
    FROM public.teams t
    JOIN public.depots d ON d.id = t.depot_id
    WHERE t.id = p_team_id AND d.geom IS NOT NULL;

    IF v_distance IS NULL OR v_distance > 150 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Hors zone dépôt');
    END IF;

    UPDATE public.team_members tm
    SET presence_status = 'present',
        present_at = COALESCE(present_at, NOW()),
        last_seen_at = NOW()
    WHERE tm.team_id = p_team_id
      AND tm.user_id = v_driver_id
      AND tm.invitation_status = 'accepted'
      AND COALESCE(tm.presence_status, 'participant') <> 'present';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', true, 'presence_status', 'present', 'message', 'Déjà présent');
    END IF;

    SELECT m.control_plan_id INTO v_plan_id
    FROM public.msr_missions m WHERE m.team_id = p_team_id::text
    ORDER BY m.updated_at DESC LIMIT 1;

    IF v_plan_id IS NOT NULL THEN
        PERFORM public.log_mission_event(
            v_plan_id, 'MEMBER_PRESENT', v_driver_id,
            jsonb_build_object('team_id', p_team_id, 'method', 'gps')
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true, 'presence_status', 'present', 'message', 'Présence détectée'
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_member_presence(
    p_team_id UUID,
    p_member_driver_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_plan_id UUID;
BEGIN
    v_driver_id := public.current_driver_id();
    IF NOT public.driver_has_pad_mention(p_team_id, v_driver_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Réservé au PAD');
    END IF;

    UPDATE public.team_members tm
    SET presence_status = 'present',
        present_at = NOW(),
        presence_confirmed_by = v_driver_id,
        last_seen_at = NOW()
    WHERE tm.team_id = p_team_id
      AND tm.user_id = p_member_driver_id
      AND tm.invitation_status = 'accepted';

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Membre introuvable');
    END IF;

    SELECT m.control_plan_id INTO v_plan_id
    FROM public.msr_missions m WHERE m.team_id = p_team_id::text LIMIT 1;

    IF v_plan_id IS NOT NULL THEN
        PERFORM public.log_mission_event(
            v_plan_id, 'MEMBER_PRESENT', p_member_driver_id,
            jsonb_build_object('team_id', p_team_id, 'method', 'pad', 'confirmed_by', v_driver_id)
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Présence confirmée');
END;
$$;

-- ---------------------------------------------------------------------------
-- Rôles (préparation uniquement)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_team_member_roles(
    p_team_id UUID,
    p_member_driver_id UUID,
    p_mentions TEXT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_mission_status TEXT;
    v_plan_id UUID;
    v_is_admin BOOLEAN;
BEGIN
    v_driver_id := public.current_driver_id();

    SELECT m.status, m.control_plan_id INTO v_mission_status, v_plan_id
    FROM public.msr_missions m
    WHERE m.team_id = p_team_id::text
    ORDER BY m.updated_at DESC LIMIT 1;

    IF v_mission_status IS NOT NULL AND v_mission_status <> 'assigned' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Rôles verrouillés pendant l''intervention');
    END IF;

    SELECT (cp.created_by = (
        SELECT d.user_id FROM public.drivers d WHERE d.id = v_driver_id
    )) INTO v_is_admin
    FROM public.control_plans cp WHERE cp.id = v_plan_id;

    IF NOT v_is_admin AND NOT public.driver_has_pad_mention(p_team_id, v_driver_id) THEN
        RETURN jsonb_build_object('success', false, 'message', 'Non autorisé');
    END IF;

    UPDATE public.team_members
    SET mentions = to_jsonb(p_mentions)
    WHERE team_id = p_team_id AND user_id = p_member_driver_id;

    IF v_plan_id IS NOT NULL THEN
        PERFORM public.log_mission_event(
            v_plan_id, 'ROLE_UPDATED', v_driver_id,
            jsonb_build_object('team_id', p_team_id, 'member_id', p_member_driver_id, 'mentions', p_mentions)
        );
    END IF;

    RETURN jsonb_build_object('success', true, 'message', 'Rôles mis à jour');
END;
$$;

-- ---------------------------------------------------------------------------
-- Transition intervention
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
        IF NOT public.driver_has_pad_mention(v_team_id, v_driver_id) THEN
            RETURN jsonb_build_object('success', false, 'message', 'Seul le PAD peut démarrer l''intervention');
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
        IF NOT public.driver_has_pad_mention(v_team_id, v_driver_id) THEN
            RETURN jsonb_build_object('success', false, 'message', 'Seul le PAD peut terminer l''intervention');
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

    RETURN jsonb_build_object('success', false, 'message', 'Action invalide');
END;
$$;

GRANT EXECUTE ON FUNCTION public.declare_team_presence(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.sync_team_presence(UUID, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_member_presence(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_team_member_roles(UUID, UUID, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.transition_control_mission(UUID, TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- create_control_plan étendu (références + responsable + event)
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.create_control_plan(TEXT, TEXT, DATE, DATE, UUID, TEXT[], TEXT[], TEXT[]);

CREATE OR REPLACE FUNCTION public.create_control_plan(
    p_name TEXT,
    p_objective TEXT DEFAULT 'Contrôle titres de transport',
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_team_id UUID DEFAULT NULL,
    p_instructions TEXT[] DEFAULT '{}',
    p_line_ids TEXT[] DEFAULT '{}',
    p_zones TEXT[] DEFAULT '{}',
    p_operational_responsible_id UUID DEFAULT NULL,
    p_priority TEXT DEFAULT 'low'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_user_id UUID;
    v_plan_id UUID;
    v_name TEXT;
    v_objective TEXT;
    v_instruction TEXT;
    v_line_id TEXT;
    v_zone TEXT;
    v_sort INTEGER := 0;
    v_team RECORD;
    v_zone_id TEXT;
    v_line_id_val TEXT;
    v_start_time TIME;
    v_end_time TIME;
    v_scheduled_start TIMESTAMPTZ;
    v_scheduled_end TIMESTAMPTZ;
    v_display_num INT;
    v_ref TEXT;
    v_responsible UUID;
BEGIN
    IF NOT public.current_driver_is_control() THEN
        RAISE EXCEPTION 'Création réservée aux agents habilités Contrôle';
    END IF;

    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'Conducteur introuvable';
    END IF;

    SELECT d.user_id INTO v_user_id
    FROM public.drivers d WHERE d.id = v_driver_id;

    v_name := btrim(p_name);
    IF v_name IS NULL OR length(v_name) < 3 THEN
        RAISE EXCEPTION 'Le nom de la mission doit contenir au moins 3 caractères';
    END IF;

    v_objective := btrim(p_objective);
    IF v_objective IS NULL OR length(v_objective) < 3 THEN
        RAISE EXCEPTION 'L''objectif doit contenir au moins 3 caractères';
    END IF;

    IF p_end_date < p_start_date THEN
        RAISE EXCEPTION 'La date de fin doit être postérieure ou égale à la date de début';
    END IF;

    IF p_priority NOT IN ('low', 'medium', 'high') THEN
        RAISE EXCEPTION 'Priorité invalide';
    END IF;

    v_responsible := COALESCE(p_operational_responsible_id, v_user_id);
    v_display_num := public.next_mission_display_number();
    v_ref := public.mission_reference_code(p_start_date);

    INSERT INTO public.control_plans (
        name, objective, status, start_date, end_date, created_by,
        priority, operational_responsible_id,
        mission_reference, mission_display_number
    )
    VALUES (
        v_name, v_objective, 'active', p_start_date, p_end_date, v_user_id,
        p_priority, v_responsible, v_ref, v_display_num
    )
    RETURNING id INTO v_plan_id;

    IF p_team_id IS NOT NULL THEN
        IF NOT (public.is_team_member(p_team_id) OR public.is_team_creator(p_team_id)) THEN
            RAISE EXCEPTION 'Équipe introuvable ou non autorisée';
        END IF;

        INSERT INTO public.control_plan_teams (plan_id, team_id)
        VALUES (v_plan_id, p_team_id::text) ON CONFLICT DO NOTHING;

        INSERT INTO public.control_plan_agents (plan_id, agent_id)
        SELECT DISTINCT v_plan_id, d.user_id
        FROM public.team_members tm
        JOIN public.drivers d ON d.id = tm.user_id
        WHERE tm.team_id = p_team_id AND tm.invitation_status <> 'removed'
          AND d.user_id IS NOT NULL
        ON CONFLICT DO NOTHING;

        IF NOT EXISTS (
            SELECT 1 FROM public.msr_missions m
            WHERE m.control_plan_id = v_plan_id AND m.team_id = p_team_id::text
        ) THEN
            SELECT t.line_id, t.zone, t.departure_time, t.return_time, t.vacations
            INTO v_team FROM public.teams t WHERE t.id = p_team_id;

            v_line_id_val := COALESCE(NULLIF(btrim(v_team.line_id), ''), NULLIF(btrim(p_line_ids[1]), ''));
            v_zone_id := COALESCE(NULLIF(btrim(v_team.zone), ''), NULLIF(btrim(p_zones[1]), ''), 'zone');
            v_start_time := COALESCE(NULLIF(btrim(v_team.vacations->0->>'start_time'), '')::time, v_team.departure_time, '08:00'::time);
            v_end_time := COALESCE(NULLIF(btrim(v_team.vacations->0->>'end_time'), '')::time, v_team.return_time, '12:00'::time);
            v_scheduled_start := (p_start_date + v_start_time)::timestamp;
            v_scheduled_end := (p_start_date + v_end_time)::timestamp;
            IF v_scheduled_end <= v_scheduled_start THEN
                v_scheduled_end := v_scheduled_end + INTERVAL '1 day';
            END IF;

            INSERT INTO public.msr_missions (
                control_plan_id, team_id, zone_id, zone_type, zone_config,
                scheduled_start, scheduled_end, status
            ) VALUES (
                v_plan_id, p_team_id::text, v_zone_id, 'custom_polygon',
                jsonb_strip_nulls(jsonb_build_object(
                    'line_id', v_line_id_val,
                    'zone', NULLIF(btrim(v_team.zone), ''),
                    'plan_instructions', to_jsonb(COALESCE(p_instructions, '{}'::text[]))
                )),
                v_scheduled_start, v_scheduled_end, 'assigned'
            );
        END IF;
    ELSIF v_user_id IS NOT NULL THEN
        INSERT INTO public.control_plan_agents (plan_id, agent_id)
        VALUES (v_plan_id, v_user_id) ON CONFLICT DO NOTHING;
    END IF;

    FOREACH v_line_id IN ARRAY COALESCE(p_line_ids, '{}'::text[]) LOOP
        v_line_id := btrim(v_line_id);
        IF length(v_line_id) > 0 THEN
            INSERT INTO public.control_plan_lines (plan_id, line_id)
            VALUES (v_plan_id, v_line_id) ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;

    FOREACH v_zone IN ARRAY COALESCE(p_zones, '{}'::text[]) LOOP
        v_zone := btrim(v_zone);
        IF length(v_zone) > 0 THEN
            INSERT INTO public.control_plan_zones (plan_id, zone_id)
            VALUES (v_plan_id, v_zone) ON CONFLICT DO NOTHING;
        END IF;
    END LOOP;

    FOREACH v_instruction IN ARRAY COALESCE(p_instructions, '{}'::text[]) LOOP
        v_instruction := btrim(v_instruction);
        IF length(v_instruction) > 0 THEN
            INSERT INTO public.control_plan_instructions (plan_id, content, sort_order)
            VALUES (v_plan_id, v_instruction, v_sort);
            v_sort := v_sort + 1;
        END IF;
    END LOOP;

    PERFORM public.log_mission_event(
        v_plan_id, 'MISSION_CREATED', v_driver_id,
        jsonb_build_object('name', v_name, 'display_number', v_display_num)
    );

    RETURN v_plan_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_control_plan(
    TEXT, TEXT, DATE, DATE, UUID, TEXT[], TEXT[], TEXT[], UUID, TEXT
) TO authenticated;

-- ---------------------------------------------------------------------------
-- my_control_plan_upcoming
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_control_plan_upcoming(
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

    SELECT COALESCE(jsonb_agg(row_data ORDER BY scheduled_start ASC NULLS LAST), '[]'::jsonb)
    INTO v_missions
    FROM (
        SELECT
            m.scheduled_start,
            public.control_mission_preview_json(
                m, cp.name, t.name, public.driver_display_name(t.created_by)
            ) || jsonb_build_object(
                'mission_display_number', cp.mission_display_number,
                'objective', cp.objective,
                'priority', cp.priority,
                'phase', 'preparation'
            ) AS row_data
        FROM public.msr_missions m
        JOIN public.team_members tm ON tm.team_id::text = m.team_id
        JOIN public.teams t ON t.id = tm.team_id
        JOIN public.control_plans cp ON cp.id = m.control_plan_id
        WHERE tm.user_id = v_driver_id
          AND tm.invitation_status NOT IN ('removed', 'declined')
          AND m.status = 'assigned'
          AND m.scheduled_start > NOW()
          AND cp.status = 'active'
        ORDER BY m.scheduled_start ASC NULLS LAST
        OFFSET v_offset LIMIT v_limit + 1
    ) sub;

    v_has_more := jsonb_array_length(v_missions) > v_limit;
    IF v_has_more THEN
        v_missions := (
            SELECT jsonb_agg(elem)
            FROM (
                SELECT elem FROM jsonb_array_elements(v_missions) WITH ORDINALITY AS t(elem, ord)
                WHERE ord <= v_limit
            ) trimmed
        );
    END IF;

    RETURN jsonb_build_object('missions', COALESCE(v_missions, '[]'::jsonb), 'has_more', v_has_more);
END;
$$;

GRANT EXECUTE ON FUNCTION public.my_control_plan_upcoming(INT, INT) TO authenticated;

-- ---------------------------------------------------------------------------
-- get_mission_team_readiness (appel direct)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_mission_team_readiness(p_team_id UUID)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.mission_team_readiness(p_team_id);
$$;

GRANT EXECUTE ON FUNCTION public.get_mission_team_readiness(UUID) TO authenticated;
