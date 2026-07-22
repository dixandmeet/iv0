-- Rattache chaque ligne GTFS à son réseau, pour que la prise de service
-- (app SAE / Aule Pro) ne propose au conducteur que les lignes de son réseau
-- (`drivers.network_id`, migration 065). Toutes les lignes importées à ce
-- jour sont Naolib : backfill sur ce réseau, comme pour les autres tables
-- historiques (migration 064).
-- ---------------------------------------------------------------------------

ALTER TABLE public.gtfs_routes
    ADD COLUMN IF NOT EXISTS network_id UUID REFERENCES public.networks(id) ON DELETE CASCADE;

UPDATE public.gtfs_routes
SET network_id = '00000000-0000-4000-8000-000000000001'
WHERE network_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_gtfs_routes_network ON public.gtfs_routes(network_id);
