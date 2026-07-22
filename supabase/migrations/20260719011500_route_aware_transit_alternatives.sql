-- Conserve des itinéraires alternatifs réellement distincts par ligne.
--
-- Les deux vues matérialisées transforment les recherches géographiques
-- répétées en petits index :
--   - un quai de correspondance par ligne autour de chaque arrêt ;
--   - l'emprise des arrêts de chaque ligne pour estimer sa progression.

CREATE MATERIALIZED VIEW IF NOT EXISTS public.gtfs_transfer_route_stops AS
WITH route_stops AS (
    SELECT DISTINCT
        profile_stop.stop_id,
        profile.route_id
    FROM public.gtfs_trip_profile_stops profile_stop
    JOIN public.gtfs_trip_profiles profile
      ON profile.profile_id = profile_stop.profile_id
)
SELECT DISTINCT ON (origin.stop_id, route_stops.route_id)
    origin.stop_id AS from_stop_id,
    route_stops.route_id,
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
    CASE WHEN candidate.stop_name = origin.stop_name THEN 0 ELSE 1 END,
    ST_Distance(candidate.geom::GEOGRAPHY, origin.geom::GEOGRAPHY);

CREATE UNIQUE INDEX IF NOT EXISTS gtfs_transfer_route_stops_from_route_idx
    ON public.gtfs_transfer_route_stops (from_stop_id, route_id);

CREATE INDEX IF NOT EXISTS gtfs_transfer_route_stops_lookup_idx
    ON public.gtfs_transfer_route_stops (from_stop_id, name_priority, distance_m);

CREATE MATERIALIZED VIEW IF NOT EXISTS public.gtfs_route_reach AS
SELECT
    route_stops.route_id,
    ST_Multi(ST_Collect(route_stops.geom)) AS stops_geom
FROM (
    SELECT DISTINCT
        profile.route_id,
        profile_stop.stop_id,
        stop.geom
    FROM public.gtfs_trip_profiles profile
    JOIN public.gtfs_trip_profile_stops profile_stop
      ON profile_stop.profile_id = profile.profile_id
    JOIN public.gtfs_stops stop ON stop.stop_id = profile_stop.stop_id
    WHERE COALESCE(stop.status, 'active') <> 'inactive'
) route_stops
GROUP BY route_stops.route_id;

CREATE UNIQUE INDEX IF NOT EXISTS gtfs_route_reach_route_idx
    ON public.gtfs_route_reach (route_id);

REVOKE ALL ON public.gtfs_transfer_route_stops FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.gtfs_route_reach FROM PUBLIC, anon, authenticated;

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
        '                SELECT
                    candidate.*,
                    ST_Distance(candidate.geom::GEOGRAPHY, fs.geom::GEOGRAPHY) AS distance_m
                FROM public.gtfs_stops candidate
                WHERE (
                    (v_round = 1 AND candidate.stop_id = f.stop_id)
                    OR
                    (v_round > 1 AND ST_DWithin(
                        candidate.geom::GEOGRAPHY,
                        fs.geom::GEOGRAPHY,
                        v_transfer_radius
                    ))
                )
                  AND COALESCE(candidate.status, ''active'') <> ''inactive''
                  AND (NOT p_wheelchair OR candidate.wheelchair_boarding <> 2)
                ORDER BY
                    CASE WHEN candidate.stop_name = fs.stop_name THEN 0 ELSE 1 END,
                    distance_m
                LIMIT CASE WHEN v_round = 1 THEN 1 ELSE v_transfer_candidates END',
        '                SELECT
                    candidate.*,
                    selected.transfer_route_id,
                    selected.distance_m
                FROM (
                    SELECT
                        ranked.to_stop_id,
                        ranked.route_id AS transfer_route_id,
                        ranked.distance_m
                    FROM (
                        SELECT
                            f.stop_id AS to_stop_id,
                            NULL::TEXT AS route_id,
                            0::DOUBLE PRECISION AS distance_m,
                            0::DOUBLE PRECISION AS destination_distance_m,
                            0 AS name_priority
                        WHERE v_round = 1

                        UNION ALL

                        SELECT
                            transfer_stop.to_stop_id,
                            transfer_stop.route_id,
                            transfer_stop.distance_m,
                            ST_Distance(
                                reach.stops_geom::GEOGRAPHY,
                                ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)::GEOGRAPHY
                            ),
                            transfer_stop.name_priority
                        FROM public.gtfs_transfer_route_stops transfer_stop
                        JOIN public.gtfs_route_reach reach
                          ON reach.route_id = transfer_stop.route_id
                        WHERE v_round > 1
                          AND transfer_stop.from_stop_id = fs.stop_id
                          AND NOT (transfer_stop.route_id = ANY(f.visited_routes))
                    ) ranked
                    ORDER BY
                        ranked.destination_distance_m,
                        ranked.name_priority,
                        ranked.distance_m
                    LIMIT CASE WHEN v_round = 1 THEN 1 ELSE v_transfer_candidates END
                ) selected
                JOIN public.gtfs_stops candidate
                  ON candidate.stop_id = selected.to_stop_id
                WHERE COALESCE(candidate.status, ''active'') <> ''inactive''
                  AND (NOT p_wheelchair OR candidate.wheelchair_boarding <> 2)'
    );

    updated_definition := replace(
        updated_definition,
        '                bs.wheelchair_boarding AS board_wheelchair,
                td.distance_m AS transfer_distance_m,',
        '                bs.wheelchair_boarding AS board_wheelchair,
                bs.transfer_route_id,
                td.distance_m AS transfer_distance_m,'
    );

    updated_definition := replace(
        updated_definition,
        '                      AND NOT (pr.route_id = ANY(tc.visited_routes))
                      AND NOT COALESCE(ra.canceled, FALSE)',
        '                      AND NOT (pr.route_id = ANY(tc.visited_routes))
                      AND (tc.transfer_route_id IS NULL OR pr.route_id = tc.transfer_route_id)
                      AND NOT COALESCE(ra.canceled, FALSE)'
    );

    updated_definition := replace(
        updated_definition,
        '                        PARTITION BY stop_id
                        ORDER BY',
        '                        PARTITION BY stop_id, last_route_id, visited_routes[1]
                        ORDER BY'
    );

    updated_definition := replace(
        updated_definition,
        '                FROM (
                    SELECT
                        scored.*,
                        ROW_NUMBER() OVER (
                            PARTITION BY last_route_id
                            ORDER BY onward_score, walk_seconds
                        ) AS rank_on_route
                    FROM (
                        SELECT
                            candidate.*,
                            EXTRACT(EPOCH FROM (arrival_at - v_departure))
                                + alert_penalty_seconds
                                + ST_DistanceSphere(
                                    ST_SetSRID(ST_Point(longitude, latitude), 4326),
                                    ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)
                                  ) / 18.0 AS onward_score
                        FROM aule_router_next candidate
                    ) scored
                ) diversified',
        '                FROM (
                    SELECT
                        strategy_ranked.*,
                        ROW_NUMBER() OVER (
                            PARTITION BY last_route_id, visited_routes[1]
                            ORDER BY
                                LEAST(arrival_rank, progress_rank, transfer_progress_rank),
                                onward_score,
                                walk_seconds
                        ) AS rank_on_route
                    FROM (
                        SELECT
                            scored.*,
                            ROW_NUMBER() OVER (
                                PARTITION BY last_route_id, visited_routes[1]
                                ORDER BY
                                    arrival_at + make_interval(secs => alert_penalty_seconds),
                                    walk_seconds
                            ) AS arrival_rank,
                            ROW_NUMBER() OVER (
                                PARTITION BY last_route_id, visited_routes[1]
                                ORDER BY destination_distance_m, arrival_at
                            ) AS progress_rank,
                            ROW_NUMBER() OVER (
                                PARTITION BY last_route_id, visited_routes[1]
                                ORDER BY transfer_destination_distance_m, arrival_at
                            ) AS transfer_progress_rank
                        FROM (
                            SELECT
                                candidate.*,
                                ST_DistanceSphere(
                                    ST_SetSRID(ST_Point(longitude, latitude), 4326),
                                    ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)
                                ) AS destination_distance_m,
                                COALESCE(
                                    (
                                        SELECT MIN(ST_Distance(
                                            reach.stops_geom::GEOGRAPHY,
                                            ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)::GEOGRAPHY
                                        ))
                                        FROM public.gtfs_transfer_route_stops transfer_stop
                                        JOIN public.gtfs_route_reach reach
                                          ON reach.route_id = transfer_stop.route_id
                                        WHERE transfer_stop.from_stop_id = candidate.stop_id
                                          AND NOT (transfer_stop.route_id = ANY(candidate.visited_routes))
                                    ),
                                    ST_DistanceSphere(
                                        ST_SetSRID(ST_Point(longitude, latitude), 4326),
                                        ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)
                                    )
                                ) AS transfer_destination_distance_m,
                                EXTRACT(EPOCH FROM (arrival_at - v_departure))
                                    + alert_penalty_seconds
                                    + ST_DistanceSphere(
                                        ST_SetSRID(ST_Point(longitude, latitude), 4326),
                                        ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)
                                      ) / 18.0 AS onward_score
                            FROM aule_router_next candidate
                        ) scored
                    ) strategy_ranked
                ) diversified'
    );

    updated_definition := replace(
        updated_definition,
        'v_frontier_limit INTEGER := 64;',
        'v_frontier_limit INTEGER := 80;'
    );

    IF updated_definition = original_definition
       OR updated_definition NOT LIKE '%selected.transfer_route_id%'
       OR updated_definition NOT LIKE '%transfer_progress_rank%'
       OR updated_definition NOT LIKE '%v_frontier_limit INTEGER := 80;%'
    THEN
        RAISE EXCEPTION 'La réécriture du planificateur par ligne est incomplète';
    END IF;

    EXECUTE updated_definition;
END
$migration$;

DROP FUNCTION IF EXISTS public.plan_transit_transfer_stops(
    TEXT, DOUBLE PRECISION, INTEGER, TEXT[], BOOLEAN
);

REVOKE ALL ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) TO service_role;
