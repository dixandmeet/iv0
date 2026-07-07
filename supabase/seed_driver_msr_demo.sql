-- Démo : habilitations MSR sur des conducteurs de test (idempotent).
-- À exécuter après 031_driver_msr_capabilities.sql.
-- Met à jour par e-mail si la fiche existe déjà.

UPDATE public.drivers
SET msr_control = TRUE,
    msr_intervention = FALSE
WHERE lower(email) IN (
    'demo.conducteur@aule.local',
    'demo.msr.controle@aule.local'
);

UPDATE public.drivers
SET msr_control = FALSE,
    msr_intervention = TRUE
WHERE lower(email) = 'demo.msr.intervention@aule.local';

-- Conducteur dual MSR (contrôle + intervention) pour tests UI.
UPDATE public.drivers
SET msr_control = TRUE,
    msr_intervention = TRUE
WHERE lower(email) = 'demo.msr.dual@aule.local';
