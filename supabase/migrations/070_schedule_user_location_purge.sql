-- Suppression automatique des coordonnées brutes issues du partage
-- communautaire de l'application grand public.

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION public.purge_old_user_locations()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    DELETE FROM public.user_location_events
    WHERE "timestamp" < NOW() - INTERVAL '15 minutes';
END;
$$;

REVOKE ALL ON FUNCTION public.purge_old_user_locations()
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_old_user_locations()
    TO service_role;

REVOKE ALL ON SCHEMA cron FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL TABLES IN SCHEMA cron FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA cron FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA cron FROM PUBLIC, anon, authenticated;

-- Exécution chaque minute : une coordonnée brute est supprimée dès qu'elle
-- dépasse la fenêtre de conservation de quinze minutes.
SELECT cron.schedule(
    'purge-user-location-events',
    '* * * * *',
    $job$SELECT public.purge_old_user_locations();$job$
);
