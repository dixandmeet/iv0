-- Accélère le calcul d'itinéraire de la carte immersive.
-- Les recherches concernées filtrent gtfs_stop_mapping par gtfs_stop_id sans
-- connaître network_id, donc la clé primaire (network_id, gtfs_stop_id) ne
-- peut pas servir efficacement à elle seule.

CREATE INDEX IF NOT EXISTS idx_gtfs_stop_mapping_gtfs_stop_id
    ON public.gtfs_stop_mapping (gtfs_stop_id);

-- Couvre les lectures de get_stop_serving_lines qui partent d'un arrêt puis
-- récupèrent les courses et leur position dans la séquence.
CREATE INDEX IF NOT EXISTS idx_gtfs_stop_times_stop_trip_sequence
    ON public.gtfs_stop_times (stop_id, trip_id, stop_sequence);

-- Couvre la sélection d'une course représentative par ligne et sens.
CREATE INDEX IF NOT EXISTS idx_gtfs_trips_route_direction
    ON public.gtfs_trips (route_id, direction_id, trip_id);
