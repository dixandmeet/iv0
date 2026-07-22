-- Sélecteur de réseau côté conducteur (app mobile SAE / Aule Pro)
-- ---------------------------------------------------------------------------
-- Les conducteurs (`drivers`) n'appartiennent pas à `network_memberships` —
-- cette table sert à l'auto-provisioning des comptes Studio/dashboard
-- (migration 064). Ils ont pourtant besoin de déclarer sur quel réseau ils
-- roulent depuis leur profil app :
--   1. `drivers.network_id` : réseau choisi par le conducteur (auto-écrit
--      via la RLS `drivers_update_self` déjà en place, aucun changement
--      nécessaire côté écriture).
--   2. Un annuaire en lecture (id/name/code/operator/territory, réseaux
--      actifs uniquement) pour peupler le sélecteur — les données
--      opérationnelles réelles (network_depots, network_lines,
--      network_incidents, ...) restent verrouillées par can_access_network()
--      et ne sont pas concernées par ce changement.
-- ---------------------------------------------------------------------------

ALTER TABLE public.drivers
    ADD COLUMN IF NOT EXISTS network_id UUID REFERENCES public.networks(id) ON DELETE SET NULL;

UPDATE public.drivers
SET network_id = '00000000-0000-4000-8000-000000000001'
WHERE network_id IS NULL;

DROP POLICY IF EXISTS networks_select_active_directory ON public.networks;
CREATE POLICY networks_select_active_directory ON public.networks
    FOR SELECT TO authenticated
    USING (status = 'active');
