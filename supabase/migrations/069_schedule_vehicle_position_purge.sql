-- Purge automatique des positions GPS précises.
--
-- Supabase Cron repose sur pg_cron. Le job nommé est idempotent : un nouvel
-- appel à cron.schedule avec le même nom et le même propriétaire met à jour
-- sa planification et sa commande au lieu de créer un doublon.

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Le planificateur reste une capacité d'administration de la base. Les rôles
-- exposés par PostgREST ne doivent ni voir les jobs ni en créer.
REVOKE ALL ON SCHEMA cron FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA cron FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA cron FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA cron FROM PUBLIC, anon, authenticated;

-- Exécution toutes les heures à :17 UTC. La fonction, créée en 068, refuse
-- elle-même les rétentions inférieures à 15 minutes ou supérieures à 30 jours.
SELECT cron.schedule(
    'purge-vehicle-positions-hourly',
    '17 * * * *',
    $job$SELECT public.purge_old_vehicle_positions(INTERVAL '24 hours');$job$
);
