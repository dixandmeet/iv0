-- Complète la table teams pour la création d'équipes côté app Pro.
-- L'app envoie `vacations` (JSONB) et `mobility_mode` ; absentes de 033 initial.

ALTER TABLE public.teams
    ADD COLUMN IF NOT EXISTS vacations JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.teams
    ADD COLUMN IF NOT EXISTS mobility_mode TEXT;

DO $$
BEGIN
    ALTER TABLE public.teams
        ADD CONSTRAINT teams_mobility_mode_check
        CHECK (mobility_mode IS NULL OR mobility_mode IN ('vehicle', 'on_foot'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER TABLE public.teams
        ADD CONSTRAINT teams_vacations_is_array
        CHECK (jsonb_typeof(vacations) = 'array');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
