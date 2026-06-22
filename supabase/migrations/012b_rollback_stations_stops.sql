-- Rollback stations/stops (restaure gtfs_stops_legacy si archivé)
-- Usage manuel en cas de problème post-migration.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'gtfs_stops_legacy'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'gtfs_stops'
    ) THEN
        ALTER TABLE public.gtfs_stops_legacy RENAME TO gtfs_stops;
    END IF;
END $$;

TRUNCATE public.gtfs_stop_mapping CASCADE;
TRUNCATE public.stops CASCADE;
TRUNCATE public.stations CASCADE;
-- networks conservé (seed naolib-nantes)
