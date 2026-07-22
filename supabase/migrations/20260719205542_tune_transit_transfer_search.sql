-- Le premier faisceau multi-quais dépasse la fenêtre interactive de 12 s.
-- Les arrêts de descente distincts (Saint-Pierre, Place du Cirque...) existent
-- déjà comme labels séparés : deux labels par arrêt suffisent dès lors que le
-- bon quai directionnel est utilisé, et gardent la recherche sous 12 secondes.

CREATE MATERIALIZED VIEW IF NOT EXISTS public.gtfs_transfer_route_directions AS
WITH route_stops AS (
    SELECT DISTINCT
        profile_stop.stop_id,
        profile.route_id,
        profile.direction_id
    FROM public.gtfs_trip_profile_stops profile_stop
    JOIN public.gtfs_trip_profiles profile
      ON profile.profile_id = profile_stop.profile_id
)
SELECT DISTINCT ON (origin.stop_id, route_stops.route_id, route_stops.direction_id)
    origin.stop_id AS from_stop_id,
    route_stops.route_id,
    route_stops.direction_id,
    candidate.stop_id AS to_stop_id,
    CASE WHEN candidate.stop_name = origin.stop_name THEN 0 ELSE 1 END AS name_priority,
    ST_Distance(candidate.geom::GEOGRAPHY, origin.geom::GEOGRAPHY) AS distance_m
FROM public.gtfs_stops origin
JOIN public.gtfs_stops candidate
  ON ST_DWithin(
      candidate.geom::GEOGRAPHY,
      origin.geom::GEOGRAPHY,
      550::DOUBLE PRECISION
  )
JOIN route_stops ON route_stops.stop_id = candidate.stop_id
WHERE COALESCE(origin.status, 'active') <> 'inactive'
  AND COALESCE(candidate.status, 'active') <> 'inactive'
ORDER BY
    origin.stop_id,
    route_stops.route_id,
    route_stops.direction_id,
    CASE WHEN candidate.stop_name = origin.stop_name THEN 0 ELSE 1 END,
    ST_Distance(candidate.geom::GEOGRAPHY, origin.geom::GEOGRAPHY),
    candidate.stop_id;

CREATE UNIQUE INDEX IF NOT EXISTS gtfs_transfer_route_directions_unique_idx
    ON public.gtfs_transfer_route_directions
    (from_stop_id, route_id, direction_id);

CREATE INDEX IF NOT EXISTS gtfs_transfer_route_directions_lookup_idx
    ON public.gtfs_transfer_route_directions
    (from_stop_id, route_id, direction_id, distance_m)
    INCLUDE (to_stop_id, name_priority);

REVOKE ALL ON public.gtfs_transfer_route_directions FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
    function_signature REGPROCEDURE :=
        'public.plan_transit_journeys(double precision,double precision,double precision,double precision,timestamp with time zone,integer,boolean,boolean,integer)'::REGPROCEDURE;
    original_definition TEXT;
    updated_definition TEXT;
BEGIN
    SELECT pg_get_functiondef(function_signature)
    INTO original_definition;

    updated_definition := replace(
        original_definition,
        'v_labels_per_stop INTEGER := 4;',
        'v_labels_per_stop INTEGER := 2;'
    );
    updated_definition := replace(
        updated_definition,
        'v_labels_per_stop INTEGER := 3;',
        'v_labels_per_stop INTEGER := 2;'
    );
    updated_definition := replace(
        updated_definition,
        'v_transfer_candidates INTEGER := 12;',
        'v_transfer_candidates INTEGER := 5;'
    );
    updated_definition := replace(
        updated_definition,
        'v_transfer_candidates INTEGER := 8;',
        'v_transfer_candidates INTEGER := 5;'
    );
    updated_definition := replace(
        updated_definition,
        '(SELECT * FROM public.gtfs_transfer_route_candidates WHERE candidate_rank <= 2) transfer_stop',
        'public.gtfs_transfer_route_directions transfer_stop'
    );
    updated_definition := replace(
        updated_definition,
        'public.gtfs_transfer_route_candidates transfer_stop',
        'public.gtfs_transfer_route_directions transfer_stop'
    );
    updated_definition := replace(
        updated_definition,
        'public.gtfs_transfer_route_stops transfer_stop',
        'public.gtfs_transfer_route_directions transfer_stop'
    );

    updated_definition := replace(
        updated_definition,
        '                    candidate.*,
                    selected.transfer_route_id,
                    selected.distance_m',
        '                    candidate.*,
                    selected.transfer_route_id,
                    selected.transfer_direction_id,
                    selected.distance_m'
    );
    updated_definition := replace(
        updated_definition,
        '                        ranked.route_id AS transfer_route_id,
                        ranked.distance_m',
        '                        ranked.route_id AS transfer_route_id,
                        ranked.direction_id AS transfer_direction_id,
                        ranked.distance_m'
    );
    updated_definition := replace(
        updated_definition,
        '                            NULL::TEXT AS route_id,
                            0::DOUBLE PRECISION AS distance_m,',
        '                            NULL::TEXT AS route_id,
                            NULL::INTEGER AS direction_id,
                            0::DOUBLE PRECISION AS distance_m,'
    );
    updated_definition := replace(
        updated_definition,
        '                            transfer_stop.route_id,
                            transfer_stop.distance_m,',
        '                            transfer_stop.route_id,
                            transfer_stop.direction_id,
                            transfer_stop.distance_m,'
    );
    updated_definition := replace(
        updated_definition,
        '                bs.transfer_route_id,
                td.distance_m AS transfer_distance_m,',
        '                bs.transfer_route_id,
                bs.transfer_direction_id,
                td.distance_m AS transfer_distance_m,'
    );
    updated_definition := replace(
        updated_definition,
        '                      AND (tc.transfer_route_id IS NULL OR pr.route_id = tc.transfer_route_id)
                      AND NOT COALESCE(ra.canceled, FALSE)',
        '                      AND (tc.transfer_route_id IS NULL OR pr.route_id = tc.transfer_route_id)
                      AND (tc.transfer_direction_id IS NULL OR pr.direction_id = tc.transfer_direction_id)
                      AND NOT COALESCE(ra.canceled, FALSE)'
    );

    IF updated_definition NOT LIKE '%v_labels_per_stop INTEGER := 2;%'
       OR updated_definition NOT LIKE '%v_transfer_candidates INTEGER := 5;%'
       OR updated_definition NOT LIKE '%gtfs_transfer_route_directions transfer_stop%'
       OR updated_definition LIKE '%gtfs_transfer_route_candidates transfer_stop%'
       OR updated_definition NOT LIKE '%selected.transfer_direction_id%'
       OR updated_definition NOT LIKE '%tc.transfer_direction_id IS NULL%'
    THEN
        RAISE EXCEPTION 'Le réglage du faisceau de correspondances est incomplet';
    END IF;

    IF updated_definition <> original_definition THEN
        EXECUTE updated_definition;
    END IF;
END
$migration$;

DROP MATERIALIZED VIEW IF EXISTS public.gtfs_transfer_route_candidates;

REVOKE ALL ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) TO service_role;
