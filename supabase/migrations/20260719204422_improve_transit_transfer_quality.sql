-- Conserve plusieurs quais possibles par ligne autour de chaque arrêt. Le
-- routeur applicatif recalculera ensuite chaque chemin piéton sur le réseau
-- réel et pourra éliminer les variantes dominées.

CREATE MATERIALIZED VIEW IF NOT EXISTS public.gtfs_transfer_route_candidates AS
WITH route_stops AS (
    SELECT DISTINCT
        profile_stop.stop_id,
        profile.route_id
    FROM public.gtfs_trip_profile_stops profile_stop
    JOIN public.gtfs_trip_profiles profile
      ON profile.profile_id = profile_stop.profile_id
), ranked AS (
    SELECT
        origin.stop_id AS from_stop_id,
        route_stops.route_id,
        candidate.stop_id AS to_stop_id,
        CASE WHEN candidate.stop_name = origin.stop_name THEN 0 ELSE 1 END AS name_priority,
        ST_Distance(candidate.geom::GEOGRAPHY, origin.geom::GEOGRAPHY) AS distance_m,
        ROW_NUMBER() OVER (
            PARTITION BY origin.stop_id, route_stops.route_id
            ORDER BY
                CASE WHEN candidate.stop_name = origin.stop_name THEN 0 ELSE 1 END,
                ST_Distance(candidate.geom::GEOGRAPHY, origin.geom::GEOGRAPHY),
                candidate.stop_id
        ) AS candidate_rank
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
)
SELECT
    from_stop_id,
    route_id,
    to_stop_id,
    name_priority,
    distance_m,
    candidate_rank
FROM ranked
WHERE candidate_rank <= 3;

CREATE UNIQUE INDEX IF NOT EXISTS gtfs_transfer_route_candidates_unique_idx
    ON public.gtfs_transfer_route_candidates (from_stop_id, route_id, to_stop_id);

CREATE INDEX IF NOT EXISTS gtfs_transfer_route_candidates_lookup_idx
    ON public.gtfs_transfer_route_candidates
    (from_stop_id, route_id, candidate_rank)
    INCLUDE (to_stop_id, distance_m, name_priority);

REVOKE ALL ON public.gtfs_transfer_route_candidates FROM PUBLIC, anon, authenticated;

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
        'v_labels_per_stop INTEGER := 2;',
        'v_labels_per_stop INTEGER := 4;'
    );
    updated_definition := replace(
        updated_definition,
        'v_transfer_candidates INTEGER := 5;',
        'v_transfer_candidates INTEGER := 12;'
    );
    updated_definition := replace(
        updated_definition,
        'public.gtfs_transfer_route_stops transfer_stop',
        'public.gtfs_transfer_route_candidates transfer_stop'
    );

    updated_definition := replace(
        updated_definition,
        '''id'', md5(signature || '':'' || arrival_at::TEXT),',
        '''id'', md5(signature || '':'' || path_signature || '':'' || arrival_at::TEXT),'
    );

    updated_definition := replace(
        updated_definition,
        '            SELECT DISTINCT ON (signature)
                signature, departure_at, arrival_at, duration_seconds,
                score_seconds, transfers, walk_seconds, accessible,
                alerts, route_ids, legs
            FROM aule_router_results
            WHERE duration_seconds > 0
              AND score_seconds <= EXTRACT(EPOCH FROM v_horizon)::INTEGER
            ORDER BY signature, score_seconds, arrival_at
        ) distinct_paths
        ORDER BY score_seconds, arrival_at
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 4), 1), 6)',
        '            SELECT DISTINCT ON (signature, path_signature)
                signature, path_signature, departure_at, arrival_at, duration_seconds,
                score_seconds, transfers, walk_seconds, accessible,
                alerts, route_ids, legs
            FROM (
                SELECT
                    result.*,
                    md5(COALESCE((
                        SELECT string_agg(
                            concat_ws('':'',
                                leg ->> ''type'',
                                COALESCE(leg ->> ''route_id'', ''walk''),
                                COALESCE(leg ->> ''from_stop_id'', leg ->> ''from_name'', ''?''),
                                COALESCE(leg ->> ''to_stop_id'', leg ->> ''to_name'', ''?'')
                            ),
                            ''|'' ORDER BY ordinal
                        )
                        FROM jsonb_array_elements(result.legs)
                            WITH ORDINALITY AS item(leg, ordinal)
                        WHERE leg ->> ''type'' = ''transit''
                           OR leg ->> ''kind'' = ''transfer''
                    ), result.signature)) AS path_signature
                FROM aule_router_results result
                WHERE duration_seconds > 0
                  AND score_seconds <= EXTRACT(EPOCH FROM v_horizon)::INTEGER
            ) path_results
            ORDER BY signature, path_signature, score_seconds, arrival_at
        ) distinct_paths
        ORDER BY score_seconds, arrival_at, walk_seconds
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 4), 1), 18)'
    );

    IF updated_definition NOT LIKE '%v_labels_per_stop INTEGER := 4;%'
       OR updated_definition NOT LIKE '%v_transfer_candidates INTEGER := 12;%'
       OR updated_definition NOT LIKE '%gtfs_transfer_route_candidates transfer_stop%'
       OR updated_definition NOT LIKE '%DISTINCT ON (signature, path_signature)%'
       OR updated_definition NOT LIKE '%COALESCE(p_limit, 4), 1), 18)%'
    THEN
        RAISE EXCEPTION 'La mise à niveau du planificateur de correspondances est incomplète';
    END IF;

    IF updated_definition <> original_definition THEN
        EXECUTE updated_definition;
    END IF;
END
$migration$;

REVOKE ALL ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) TO service_role;
