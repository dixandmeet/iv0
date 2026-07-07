-- Plans de contrôle v1 : missions MSR, validation d'intégration équipe,
-- contexte actif + historique paginé (preview / full selon invitation_status).
-- V1 : 1 équipe = 1 mission MSR par plan.
-- ---------------------------------------------------------------------------

-- Journalisation invitation (updated_at existe déjà sur team_members).
ALTER TABLE public.team_members
    ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS declined_at TIMESTAMPTZ;

-- Idempotence création mission par plan + équipe.
CREATE UNIQUE INDEX IF NOT EXISTS idx_msr_missions_plan_team
    ON public.msr_missions (control_plan_id, team_id)
    WHERE control_plan_id IS NOT NULL AND team_id IS NOT NULL;

-- Affichage nom conducteur (créateur équipe).
CREATE OR REPLACE FUNCTION public.driver_display_name(p_driver_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT COALESCE(
        NULLIF(
            trim(coalesce(d.first_name, '') || ' ' || coalesce(d.last_name, '')),
            ''
        ),
        d.email,
        'Agent'
    )
    FROM public.drivers d
    WHERE d.id = p_driver_id
    LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.driver_display_name(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- create_control_plan : + 1 msr_mission par équipe liée (v1)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_control_plan(
    p_name TEXT,
    p_objective TEXT DEFAULT 'Contrôle titres de transport',
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_team_id UUID DEFAULT NULL,
    p_instructions TEXT[] DEFAULT '{}',
    p_line_ids TEXT[] DEFAULT '{}',
    p_zones TEXT[] DEFAULT '{}'
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
BEGIN
    IF NOT public.current_driver_is_control() THEN
        RAISE EXCEPTION 'Création réservée aux agents habilités Contrôle';
    END IF;

    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'Conducteur introuvable';
    END IF;

    SELECT up.id INTO v_user_id
    FROM public.drivers d
    LEFT JOIN public.user_profiles up ON up.id = d.user_id
    WHERE d.id = v_driver_id;

    v_name := btrim(p_name);
    IF v_name IS NULL OR length(v_name) < 3 THEN
        RAISE EXCEPTION 'Le nom du plan doit contenir au moins 3 caractères';
    END IF;

    v_objective := btrim(p_objective);
    IF v_objective IS NULL OR length(v_objective) < 3 THEN
        RAISE EXCEPTION 'L''objectif doit contenir au moins 3 caractères';
    END IF;

    IF p_end_date < p_start_date THEN
        RAISE EXCEPTION 'La date de fin doit être postérieure ou égale à la date de début';
    END IF;

    IF p_team_id IS NOT NULL THEN
        IF NOT (
            public.is_team_member(p_team_id)
            OR public.is_team_creator(p_team_id)
        ) THEN
            RAISE EXCEPTION 'Équipe introuvable ou non autorisée';
        END IF;
    END IF;

    INSERT INTO public.control_plans (
        name, objective, status, start_date, end_date, created_by
    )
    VALUES (
        v_name, v_objective, 'active', p_start_date, p_end_date, v_user_id
    )
    RETURNING id INTO v_plan_id;

    IF p_team_id IS NOT NULL THEN
        INSERT INTO public.control_plan_teams (plan_id, team_id)
        VALUES (v_plan_id, p_team_id::text)
        ON CONFLICT DO NOTHING;

        INSERT INTO public.control_plan_agents (plan_id, agent_id)
        SELECT DISTINCT v_plan_id, up.id
        FROM public.team_members tm
        JOIN public.drivers d ON d.id = tm.user_id
        JOIN public.user_profiles up ON up.id = d.user_id
        WHERE tm.team_id = p_team_id
          AND tm.invitation_status <> 'removed'
        ON CONFLICT DO NOTHING;

        -- V1 : une mission MSR par équipe et par plan.
        IF NOT EXISTS (
            SELECT 1 FROM public.msr_missions m
            WHERE m.control_plan_id = v_plan_id
              AND m.team_id = p_team_id::text
        ) THEN
            SELECT
                t.line_id,
                t.zone,
                t.departure_time,
                t.return_time,
                t.instructions,
                t.vacations
            INTO v_team
            FROM public.teams t
            WHERE t.id = p_team_id;

            v_line_id_val := COALESCE(
                NULLIF(btrim(v_team.line_id), ''),
                NULLIF(btrim(p_line_ids[1]), '')
            );
            v_zone_id := COALESCE(
                NULLIF(btrim(v_team.zone), ''),
                NULLIF(btrim(p_zones[1]), ''),
                'zone'
            );

            v_start_time := COALESCE(
                NULLIF(btrim(v_team.vacations->0->>'start_time'), '')::time,
                v_team.departure_time,
                '08:00'::time
            );
            v_end_time := COALESCE(
                NULLIF(btrim(v_team.vacations->0->>'end_time'), '')::time,
                v_team.return_time,
                '12:00'::time
            );

            v_scheduled_start := (p_start_date + v_start_time)::timestamp;
            v_scheduled_end := (p_start_date + v_end_time)::timestamp;
            IF v_scheduled_end <= v_scheduled_start THEN
                v_scheduled_end := v_scheduled_end + INTERVAL '1 day';
            END IF;

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
            VALUES (
                v_plan_id,
                p_team_id::text,
                v_zone_id,
                'custom_polygon',
                jsonb_strip_nulls(jsonb_build_object(
                    'line_id', v_line_id_val,
                    'zone', NULLIF(btrim(v_team.zone), ''),
                    'plan_instructions', to_jsonb(COALESCE(p_instructions, '{}'::text[]))
                )),
                v_scheduled_start,
                v_scheduled_end,
                'assigned'
            );
        END IF;
    ELSIF v_user_id IS NOT NULL THEN
        INSERT INTO public.control_plan_agents (plan_id, agent_id)
        VALUES (v_plan_id, v_user_id)
        ON CONFLICT DO NOTHING;
    END IF;

    IF p_line_ids IS NOT NULL THEN
        FOREACH v_line_id IN ARRAY p_line_ids LOOP
            v_line_id := btrim(v_line_id);
            IF length(v_line_id) > 0 THEN
                INSERT INTO public.control_plan_lines (plan_id, line_id)
                VALUES (v_plan_id, v_line_id)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    IF p_zones IS NOT NULL THEN
        FOREACH v_zone IN ARRAY p_zones LOOP
            v_zone := btrim(v_zone);
            IF length(v_zone) > 0 THEN
                INSERT INTO public.control_plan_zones (plan_id, zone_id)
                VALUES (v_plan_id, v_zone)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    IF p_instructions IS NOT NULL THEN
        FOREACH v_instruction IN ARRAY p_instructions LOOP
            v_instruction := btrim(v_instruction);
            IF length(v_instruction) > 0 THEN
                INSERT INTO public.control_plan_instructions (
                    plan_id, content, sort_order
                )
                VALUES (v_plan_id, v_instruction, v_sort);
                v_sort := v_sort + 1;
            END IF;
        END LOOP;
    END IF;

    RETURN v_plan_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_control_plan(
    TEXT, TEXT, DATE, DATE, UUID, TEXT[], TEXT[], TEXT[]
) TO authenticated;

-- ---------------------------------------------------------------------------
-- respond_team_invitation
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
    v_team public.teams%ROWTYPE;
    v_mission public.msr_missions%ROWTYPE;
    v_plan public.control_plans%ROWTYPE;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'error',
            'message', 'Session conducteur introuvable'
        );
    END IF;

    SELECT * INTO v_member
    FROM public.team_members tm
    WHERE tm.team_id = p_team_id
      AND tm.user_id = v_driver_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'error',
            'message', 'Invitation introuvable'
        );
    END IF;

    IF v_member.invitation_status = 'removed' THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'error',
            'message', 'Vous avez été retiré de cette équipe'
        );
    END IF;

    IF v_member.invitation_status = 'accepted' THEN
        RETURN jsonb_build_object(
            'success', true,
            'status', 'accepted',
            'message', 'Intégration déjà validée'
        );
    END IF;

    IF v_member.invitation_status = 'declined' THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'already_declined',
            'message', 'Invitation déjà refusée. Contactez le créateur de l''équipe.'
        );
    END IF;

    SELECT * INTO v_team FROM public.teams t WHERE t.id = p_team_id;
    IF NOT FOUND OR v_team.status = 'draft' THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'error',
            'message', 'Équipe indisponible'
        );
    END IF;

    SELECT m.* INTO v_mission
    FROM public.msr_missions m
    WHERE m.team_id = p_team_id::text
    ORDER BY m.created_at DESC
    LIMIT 1;

    IF FOUND AND v_mission.control_plan_id IS NOT NULL THEN
        SELECT * INTO v_plan
        FROM public.control_plans cp
        WHERE cp.id = v_mission.control_plan_id;

        IF v_plan.status IN ('completed', 'suspended')
           OR CURRENT_DATE NOT BETWEEN v_plan.start_date AND v_plan.end_date THEN
            RETURN jsonb_build_object(
                'success', false,
                'status', 'error',
                'message', 'Le plan de contrôle n''est plus actif'
            );
        END IF;
    END IF;

    IF FOUND AND v_mission.status IN ('completed', 'cancelled') THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'error',
            'message', 'La mission n''est plus disponible'
        );
    END IF;

    IF v_member.invitation_status = 'invited'
       AND v_mission.scheduled_end IS NOT NULL
       AND v_mission.scheduled_end < NOW() THEN
        RETURN jsonb_build_object(
            'success', false,
            'status', 'expired',
            'message', 'Cette invitation a expiré'
        );
    END IF;

    IF p_accept THEN
        UPDATE public.team_members
        SET invitation_status = 'accepted',
            accepted_at = NOW(),
            declined_at = NULL
        WHERE id = v_member.id;

        RETURN jsonb_build_object(
            'success', true,
            'status', 'accepted',
            'message', 'Intégration validée'
        );
    END IF;

    UPDATE public.team_members
    SET invitation_status = 'declined',
        declined_at = NOW(),
        accepted_at = NULL
    WHERE id = v_member.id;

    RETURN jsonb_build_object(
        'success', true,
        'status', 'declined',
        'message', 'Invitation refusée'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.respond_team_invitation(UUID, BOOLEAN) TO authenticated;

-- ---------------------------------------------------------------------------
-- Helpers JSON mission (preview vs full — zone_config jamais en preview)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.control_mission_preview_json(
    p_mission public.msr_missions,
    p_plan_name TEXT,
    p_team_name TEXT,
    p_creator_name TEXT
)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT jsonb_build_object(
        'id', p_mission.id,
        'control_plan_id', p_mission.control_plan_id,
        'plan_name', p_plan_name,
        'team_id', p_mission.team_id,
        'team_name', p_team_name,
        'scheduled_start', p_mission.scheduled_start,
        'scheduled_end', p_mission.scheduled_end,
        'creator_name', p_creator_name,
        'status', p_mission.status
    );
$$;

CREATE OR REPLACE FUNCTION public.control_mission_full_json(
    p_mission public.msr_missions,
    p_plan_name TEXT,
    p_team_name TEXT,
    p_creator_name TEXT,
    p_plan_instructions JSONB,
    p_team_members JSONB,
    p_line_id TEXT,
    p_zone_label TEXT
)
RETURNS JSONB
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT jsonb_build_object(
        'id', p_mission.id,
        'control_plan_id', p_mission.control_plan_id,
        'plan_name', p_plan_name,
        'team_id', p_mission.team_id,
        'team_name', p_team_name,
        'scheduled_start', p_mission.scheduled_start,
        'scheduled_end', p_mission.scheduled_end,
        'creator_name', p_creator_name,
        'status', p_mission.status,
        'zone_id', p_mission.zone_id,
        'zone_label', p_zone_label,
        'line_id', p_line_id,
        'zone_config', p_mission.zone_config,
        'instructions', p_plan_instructions,
        'team_members', p_team_members
    );
$$;

-- ---------------------------------------------------------------------------
-- my_control_plan_context — contexte actif (sans historique)
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
    v_my_invitation_status TEXT;
    v_effective_status TEXT;
    v_is_creator BOOLEAN := false;
    v_can_view_full BOOLEAN := false;
    v_plan JSONB;
    v_current_mission JSONB;
    v_teams JSONB;
    v_mission public.msr_missions%ROWTYPE;
    v_team public.teams%ROWTYPE;
    v_plan_name TEXT;
    v_creator_name TEXT;
    v_plan_instructions JSONB;
    v_team_members JSONB;
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

    IF FOUND THEN
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
    END IF;

    v_effective_status := v_my_invitation_status;
    IF v_my_invitation_status = 'invited'
       AND v_mission.scheduled_end IS NOT NULL
       AND v_mission.scheduled_end < NOW() THEN
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

GRANT EXECUTE ON FUNCTION public.my_control_plan_context() TO authenticated;

-- ---------------------------------------------------------------------------
-- my_control_plan_history — missions passées paginées
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_control_plan_history(
    p_limit INT DEFAULT 20,
    p_offset INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver_id UUID;
    v_limit INT;
    v_offset INT;
    v_missions JSONB;
    v_row_count INT;
    v_has_more BOOLEAN;
BEGIN
    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RETURN jsonb_build_object('missions', '[]'::jsonb, 'has_more', false);
    END IF;

    v_limit := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
    v_offset := GREATEST(COALESCE(p_offset, 0), 0);

    SELECT COUNT(*) INTO v_row_count
    FROM (
        SELECT 1
        FROM public.msr_missions m
        JOIN public.team_members tm ON tm.team_id::text = m.team_id
        LEFT JOIN public.control_plans cp ON cp.id = m.control_plan_id
        WHERE tm.user_id = v_driver_id
          AND tm.invitation_status NOT IN ('removed', 'declined')
          AND (
              m.status IN ('completed', 'cancelled')
              OR m.scheduled_end < NOW()
              OR cp.status IN ('completed', 'suspended')
          )
        ORDER BY m.scheduled_end DESC NULLS LAST, m.updated_at DESC
        OFFSET v_offset
        LIMIT v_limit + 1
    ) sub;

    v_has_more := v_row_count > v_limit;

    SELECT COALESCE(
        jsonb_agg(mission_json ORDER BY scheduled_end DESC NULLS LAST),
        '[]'::jsonb
    )
    INTO v_missions
    FROM (
        SELECT
            m.scheduled_end,
            CASE
                WHEN tm.invitation_status = 'accepted' THEN
                    public.control_mission_full_json(
                        m,
                        cp.name,
                        t.name,
                        public.driver_display_name(t.created_by),
                        COALESCE(
                            (
                                SELECT jsonb_agg(cpi.content ORDER BY cpi.sort_order)
                                FROM public.control_plan_instructions cpi
                                WHERE cpi.plan_id = m.control_plan_id
                            ),
                            '[]'::jsonb
                        ),
                        COALESCE(
                            (
                                SELECT jsonb_agg(
                                    jsonb_build_object(
                                        'id', mem.id,
                                        'user_id', mem.user_id,
                                        'invitation_status', mem.invitation_status,
                                        'mentions', mem.mentions
                                    )
                                )
                                FROM public.team_members mem
                                WHERE mem.team_id::text = m.team_id
                                  AND mem.invitation_status <> 'removed'
                            ),
                            '[]'::jsonb
                        ),
                        m.zone_config->>'line_id',
                        COALESCE(m.zone_config->>'zone', m.zone_id)
                    ) || jsonb_build_object(
                        'invitation_status', tm.invitation_status,
                        'full_access', true
                    )
                ELSE
                    public.control_mission_preview_json(
                        m,
                        cp.name,
                        t.name,
                        public.driver_display_name(t.created_by)
                    ) || jsonb_build_object(
                        'invitation_status', tm.invitation_status,
                        'full_access', false
                    )
            END AS mission_json
        FROM public.msr_missions m
        JOIN public.team_members tm ON tm.team_id::text = m.team_id
        JOIN public.teams t ON t.id = tm.team_id
        LEFT JOIN public.control_plans cp ON cp.id = m.control_plan_id
        WHERE tm.user_id = v_driver_id
          AND tm.invitation_status NOT IN ('removed', 'declined')
          AND (
              m.status IN ('completed', 'cancelled')
              OR m.scheduled_end < NOW()
              OR cp.status IN ('completed', 'suspended')
          )
        ORDER BY m.scheduled_end DESC NULLS LAST, m.updated_at DESC
        OFFSET v_offset
        LIMIT v_limit
    ) built;

    RETURN jsonb_build_object(
        'missions', v_missions,
        'has_more', v_has_more
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.my_control_plan_history(INT, INT) TO authenticated;
