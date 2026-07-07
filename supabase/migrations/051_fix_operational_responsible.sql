-- Corrige operational_responsible_id : l'app envoie des drivers.id alors que
-- control_plans.operational_responsible_id référence user_profiles.id.
-- Corrige aussi control_plan_agents quand des conducteurs n'ont pas de profil.
-- ---------------------------------------------------------------------------

-- Profils manquants pour des comptes auth déjà liés à une fiche conducteur.
INSERT INTO public.user_profiles (id, role, display_name)
SELECT
    d.user_id,
    'driver',
    COALESCE(
        NULLIF(
            trim(
                coalesce(d.first_name, '') || ' ' || coalesce(d.last_name, '')
            ),
            ''
        ),
        d.email
    )
FROM public.drivers d
WHERE d.user_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM auth.users u WHERE u.id = d.user_id)
  AND NOT EXISTS (
      SELECT 1 FROM public.user_profiles up WHERE up.id = d.user_id
  )
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.ensure_driver_user_profile(p_driver_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    IF p_driver_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT up.id INTO v_user_id
    FROM public.drivers d
    JOIN public.user_profiles up ON up.id = d.user_id
    WHERE d.id = p_driver_id;

    IF v_user_id IS NOT NULL THEN
        RETURN v_user_id;
    END IF;

    INSERT INTO public.user_profiles (id, role, display_name)
    SELECT
        d.user_id,
        'driver',
        COALESCE(
            NULLIF(
                trim(
                    coalesce(d.first_name, '') || ' ' || coalesce(d.last_name, '')
                ),
                ''
            ),
            d.email
        )
    FROM public.drivers d
    WHERE d.id = p_driver_id
      AND d.user_id IS NOT NULL
      AND EXISTS (SELECT 1 FROM auth.users u WHERE u.id = d.user_id)
    ON CONFLICT (id) DO NOTHING
    RETURNING id INTO v_user_id;

    IF v_user_id IS NULL THEN
        SELECT up.id INTO v_user_id
        FROM public.drivers d
        JOIN public.user_profiles up ON up.id = d.user_id
        WHERE d.id = p_driver_id;
    END IF;

    RETURN v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_user_profile_id(p_id UUID)
RETURNS UUID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile_id UUID;
BEGIN
    IF p_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT id INTO v_profile_id
    FROM public.user_profiles
    WHERE id = p_id;

    IF v_profile_id IS NOT NULL THEN
        RETURN v_profile_id;
    END IF;

    RETURN public.ensure_driver_user_profile(p_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_driver_user_profile(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resolve_user_profile_id(UUID) TO authenticated;

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
    v_member_driver_id UUID;
BEGIN
    IF NOT public.current_driver_is_control() THEN
        RAISE EXCEPTION 'Création réservée aux agents habilités Contrôle';
    END IF;

    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'Conducteur introuvable';
    END IF;

    v_user_id := public.ensure_driver_user_profile(v_driver_id);

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

    v_responsible := COALESCE(
        public.resolve_user_profile_id(p_operational_responsible_id),
        v_user_id
    );

    IF v_user_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.user_profiles WHERE id = v_user_id
    ) THEN
        v_user_id := NULL;
    END IF;

    IF v_responsible IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.user_profiles WHERE id = v_responsible
    ) THEN
        v_responsible := NULL;
    END IF;

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

        FOR v_member_driver_id IN
            SELECT tm.user_id
            FROM public.team_members tm
            WHERE tm.team_id = p_team_id
              AND tm.invitation_status <> 'removed'
        LOOP
            PERFORM public.ensure_driver_user_profile(v_member_driver_id);
        END LOOP;

        INSERT INTO public.control_plan_agents (plan_id, agent_id)
        SELECT DISTINCT v_plan_id, up.id
        FROM public.team_members tm
        JOIN public.drivers d ON d.id = tm.user_id
        JOIN public.user_profiles up ON up.id = d.user_id
        WHERE tm.team_id = p_team_id
          AND tm.invitation_status <> 'removed'
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
