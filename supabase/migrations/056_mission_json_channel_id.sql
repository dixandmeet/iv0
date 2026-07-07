-- ---------------------------------------------------------------------------
-- 056 — expose channel_id dans les missions de contrôle
--
-- Les builders control_mission_preview_json / control_mission_full_json
-- (migration 040) ne renvoyaient jamais l'identifiant du channel Hub associé à
-- la mission. Côté app, ControlMissionSummary.fromJson lisait donc channel_id =
-- null et l'onglet Discussion affichait « Discussion indisponible ».
--
-- On ajoute 'channel_id' via le helper public.mission_channel_id (migration 050).
-- Les fonctions passent IMMUTABLE -> STABLE car elles appellent désormais une
-- fonction STABLE qui lit la table resources/channels.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.control_mission_preview_json(
    p_mission public.msr_missions,
    p_plan_name TEXT,
    p_team_name TEXT,
    p_creator_name TEXT
)
RETURNS JSONB
LANGUAGE sql
STABLE
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
        'channel_id', public.mission_channel_id(p_mission.id)
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
STABLE
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
        'team_members', p_team_members,
        'channel_id', public.mission_channel_id(p_mission.id)
    );
$$;
