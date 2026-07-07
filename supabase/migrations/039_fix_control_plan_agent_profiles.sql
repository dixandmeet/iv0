-- Corrige la création de plan de contrôle lorsque des conducteurs n'ont pas
-- de ligne dans user_profiles alors que control_plan_agents.agent_id y référence.
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
        name,
        objective,
        status,
        start_date,
        end_date,
        created_by
    )
    VALUES (
        v_name,
        v_objective,
        'active',
        p_start_date,
        p_end_date,
        v_user_id
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
    ELSIF v_user_id IS NOT NULL THEN
        INSERT INTO public.control_plan_agents (plan_id, agent_id)
        VALUES (v_plan_id, v_user_id)
        ON CONFLICT DO NOTHING;
    END IF;

    IF p_line_ids IS NOT NULL THEN
        FOREACH v_line_id IN ARRAY p_line_ids
        LOOP
            v_line_id := btrim(v_line_id);
            IF length(v_line_id) > 0 THEN
                INSERT INTO public.control_plan_lines (plan_id, line_id)
                VALUES (v_plan_id, v_line_id)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    IF p_zones IS NOT NULL THEN
        FOREACH v_zone IN ARRAY p_zones
        LOOP
            v_zone := btrim(v_zone);
            IF length(v_zone) > 0 THEN
                INSERT INTO public.control_plan_zones (plan_id, zone_id)
                VALUES (v_plan_id, v_zone)
                ON CONFLICT DO NOTHING;
            END IF;
        END LOOP;
    END IF;

    IF p_instructions IS NOT NULL THEN
        FOREACH v_instruction IN ARRAY p_instructions
        LOOP
            v_instruction := btrim(v_instruction);
            IF length(v_instruction) > 0 THEN
                INSERT INTO public.control_plan_instructions (
                    plan_id,
                    content,
                    sort_order
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
