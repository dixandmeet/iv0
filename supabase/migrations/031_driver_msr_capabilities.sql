-- Habilitations MSR terrain sur la fiche conducteur
-- ---------------------------------------------------------------------------
-- Permet à un conducteur habilité de basculer en mode Contrôle ou Intervention
-- dans l'app mobile, indépendamment du rôle user_profiles.msr_agent.
-- ---------------------------------------------------------------------------

ALTER TABLE public.drivers
    ADD COLUMN IF NOT EXISTS msr_control BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS msr_intervention BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.drivers.msr_control IS
    'Habilitation MSR service Contrôle (bascule mode terrain).';
COMMENT ON COLUMN public.drivers.msr_intervention IS
    'Habilitation MSR service Intervention (bascule mode terrain).';

CREATE INDEX IF NOT EXISTS idx_drivers_msr_capabilities
    ON public.drivers(msr_control, msr_intervention)
    WHERE msr_control OR msr_intervention;
