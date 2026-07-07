-- Flux manuel MVP — champs présentationnels des missions MSR créées depuis l'app Pro.
--
-- La table msr_missions (004, Phase 0) est structurée autour des zones/géométrie
-- pour le planificateur (Phase 5). Tant qu'il n'est pas livré, l'agent crée et
-- supprime ses propres missions « à la main » depuis l'écran Missions. On ajoute
-- les libellés affichés + l'horaire planifié, et on rend la zone optionnelle.
--
-- RLS inchangée (006_rls_policies) : `msr_missions_access` autorise déjà l'agent
-- sur ses lignes via `agent_id = auth.uid()`.

ALTER TABLE public.msr_missions
    ADD COLUMN IF NOT EXISTS title TEXT,
    ADD COLUMN IF NOT EXISTS sector TEXT,
    ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS zone_label TEXT,
    ADD COLUMN IF NOT EXISTS team_label TEXT,
    ADD COLUMN IF NOT EXISTS instructions TEXT,
    ADD COLUMN IF NOT EXISTS kind TEXT NOT NULL DEFAULT 'controle'
        CHECK (kind IN ('controle', 'intervention'));

-- Les insertions applicatives (flux manuel) ne fournissent pas de zone : la
-- géométrie reste optionnelle jusqu'au planificateur.
ALTER TABLE public.msr_missions
    ALTER COLUMN zone_type SET DEFAULT 'custom_polygon';

COMMENT ON COLUMN public.msr_missions.title IS 'Titre affiché (flux manuel app Pro)';
COMMENT ON COLUMN public.msr_missions.sector IS 'Secteur libellé (flux manuel app Pro)';
COMMENT ON COLUMN public.msr_missions.scheduled_at IS 'Horaire planifié de la mission';
COMMENT ON COLUMN public.msr_missions.zone_label IS 'Zone libellée (flux manuel app Pro)';
COMMENT ON COLUMN public.msr_missions.team_label IS 'Équipe libellée (flux manuel app Pro)';
COMMENT ON COLUMN public.msr_missions.kind IS 'controle | intervention (service MSR)';

CREATE INDEX IF NOT EXISTS idx_msr_missions_scheduled
    ON public.msr_missions (agent_id, scheduled_at DESC);

-- Correctif : sync_mission_resource (043) joignait `teams.id` (uuid) à
-- `msr_missions.team_id` (text) → « operator does not exist: uuid = text »,
-- ce qui faisait échouer TOUT INSERT/UPDATE sur msr_missions (trigger AFTER).
-- On compare en texte (robuste même si team_id n'est pas un uuid valide).
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
