-- Création d'un plan de contrôle par un agent habilité Contrôle
-- ---------------------------------------------------------------------------
-- Les tables control_plans* sont staff-only en RLS directe ; cette RPC
-- SECURITY DEFINER permet à un agent de créer un plan simplifié et de
-- l'associer à son équipe (et aux agents de l'équipe).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_control_plan(
    p_name TEXT,
    p_objective TEXT DEFAULT 'Contrôle titres de transport',
    p_start_date DATE DEFAULT CURRENT_DATE,
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_team_id UUID DEFAULT NULL,
    p_instructions TEXT[] DEFAULT '{}'
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
    v_sort INTEGER := 0;
BEGIN
    IF NOT public.current_driver_is_control() THEN
        RAISE EXCEPTION 'Création réservée aux agents habilités Contrôle';
    END IF;

    v_driver_id := public.current_driver_id();
    IF v_driver_id IS NULL THEN
        RAISE EXCEPTION 'Conducteur introuvable';
    END IF;

    SELECT d.user_id INTO v_user_id
    FROM public.drivers d
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
        SELECT DISTINCT v_plan_id, d.user_id
        FROM public.team_members tm
        JOIN public.drivers d ON d.id = tm.user_id
        WHERE tm.team_id = p_team_id
          AND tm.invitation_status <> 'removed'
          AND d.user_id IS NOT NULL
        ON CONFLICT DO NOTHING;
    ELSIF v_user_id IS NOT NULL THEN
        INSERT INTO public.control_plan_agents (plan_id, agent_id)
        VALUES (v_plan_id, v_user_id)
        ON CONFLICT DO NOTHING;
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
    TEXT, TEXT, DATE, DATE, UUID, TEXT[]
) TO authenticated;
