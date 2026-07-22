-- Pré-calcul topologique utilisé par le chargement progressif des itinéraires.
-- Cette première réponse propose des chaînes de lignes plausibles en attendant
-- que le planificateur horaire valide les passages, les sens et les durées.

CREATE MATERIALIZED VIEW public.gtfs_route_stop_index AS
SELECT DISTINCT
    profile.route_id,
    profile_stop.stop_id
FROM public.gtfs_trip_profiles profile
JOIN public.gtfs_trip_profile_stops profile_stop
  ON profile_stop.profile_id = profile.profile_id;

CREATE UNIQUE INDEX gtfs_route_stop_index_route_stop_idx
    ON public.gtfs_route_stop_index (route_id, stop_id);

CREATE INDEX gtfs_route_stop_index_stop_route_idx
    ON public.gtfs_route_stop_index (stop_id, route_id);

CREATE MATERIALIZED VIEW public.gtfs_route_transfer_graph AS
SELECT
    route_stop.route_id AS from_route_id,
    transfer_stop.route_id AS to_route_id,
    MIN(transfer_stop.distance_m) AS transfer_distance_m
FROM public.gtfs_route_stop_index route_stop
JOIN public.gtfs_transfer_route_stops transfer_stop
  ON transfer_stop.from_stop_id = route_stop.stop_id
WHERE route_stop.route_id <> transfer_stop.route_id
GROUP BY route_stop.route_id, transfer_stop.route_id;

CREATE UNIQUE INDEX gtfs_route_transfer_graph_from_to_idx
    ON public.gtfs_route_transfer_graph (from_route_id, to_route_id);

REVOKE ALL ON public.gtfs_route_stop_index FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.gtfs_route_transfer_graph FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.plan_transit_route_skeletons(
    p_from_lng DOUBLE PRECISION,
    p_from_lat DOUBLE PRECISION,
    p_to_lng DOUBLE PRECISION,
    p_to_lat DOUBLE PRECISION,
    p_departure_at TIMESTAMPTZ DEFAULT NOW(),
    p_max_transfers INTEGER DEFAULT 2,
    p_limit INTEGER DEFAULT 10
)
RETURNS JSONB
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
SET statement_timeout = '2s'
AS $function$
WITH settings AS (
    SELECT
        COALESCE(p_departure_at, NOW()) AS departure_at,
        LEAST(GREATEST(COALESCE(p_max_transfers, 2), 0), 2) AS max_transfers,
        LEAST(GREATEST(COALESCE(p_limit, 10), 1), 12) AS result_limit,
        ST_SetSRID(ST_Point(p_from_lng, p_from_lat), 4326)::GEOGRAPHY AS origin,
        ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)::GEOGRAPHY AS destination
),
service_days AS (
    SELECT day::DATE AS service_date
    FROM settings
    CROSS JOIN LATERAL generate_series(
        (settings.departure_at AT TIME ZONE 'Europe/Paris')::DATE - 1,
        ((settings.departure_at + INTERVAL '8 hours') AT TIME ZONE 'Europe/Paris')::DATE,
        INTERVAL '1 day'
    ) day
),
services AS (
    SELECT service_day.service_date, calendar.service_id
    FROM service_days service_day
    JOIN public.gtfs_calendar calendar
      ON service_day.service_date BETWEEN calendar.start_date AND calendar.end_date
     AND calendar.runs_on[EXTRACT(ISODOW FROM service_day.service_date)::INTEGER]
    WHERE NOT EXISTS (
        SELECT 1
        FROM public.gtfs_calendar_dates exception
        WHERE exception.service_id = calendar.service_id
          AND exception.service_date = service_day.service_date
          AND exception.exception_type = 2
    )

    UNION

    SELECT service_day.service_date, exception.service_id
    FROM service_days service_day
    JOIN public.gtfs_calendar_dates exception
      ON exception.service_date = service_day.service_date
     AND exception.exception_type = 1
),
active_routes AS MATERIALIZED (
    SELECT DISTINCT profile.route_id
    FROM public.gtfs_trip_profiles profile
    JOIN public.gtfs_trip_departures departure
      ON departure.profile_id = profile.profile_id
    JOIN services service ON service.service_id = departure.service_id
    CROSS JOIN settings
    WHERE (
        (service.service_date::TIMESTAMP
          + make_interval(secs => departure.start_seconds))
          AT TIME ZONE 'Europe/Paris'
    ) BETWEEN settings.departure_at AND settings.departure_at + INTERVAL '8 hours'
),
origin_routes AS MATERIALIZED (
    SELECT
        route_stop.route_id,
        MIN(ST_Distance(stop.geom::GEOGRAPHY, settings.origin)) AS access_distance_m
    FROM settings
    JOIN public.gtfs_stops stop
      ON ST_DWithin(stop.geom::GEOGRAPHY, settings.origin, 900)
    JOIN public.gtfs_route_stop_index route_stop ON route_stop.stop_id = stop.stop_id
    JOIN active_routes active ON active.route_id = route_stop.route_id
    WHERE COALESCE(stop.status, 'active') <> 'inactive'
    GROUP BY route_stop.route_id
),
destination_routes AS MATERIALIZED (
    SELECT
        route_stop.route_id,
        MIN(ST_Distance(stop.geom::GEOGRAPHY, settings.destination)) AS egress_distance_m
    FROM settings
    JOIN public.gtfs_stops stop
      ON ST_DWithin(stop.geom::GEOGRAPHY, settings.destination, 3000)
    JOIN public.gtfs_route_stop_index route_stop ON route_stop.stop_id = stop.stop_id
    JOIN active_routes active ON active.route_id = route_stop.route_id
    WHERE COALESCE(stop.status, 'active') <> 'inactive'
    GROUP BY route_stop.route_id
),
active_graph AS MATERIALIZED (
    SELECT graph.*
    FROM public.gtfs_route_transfer_graph graph
    JOIN active_routes from_active ON from_active.route_id = graph.from_route_id
    JOIN active_routes to_active ON to_active.route_id = graph.to_route_id
),
candidate_paths AS (
    SELECT
        ARRAY[origin.route_id]::TEXT[] AS route_ids,
        origin.access_distance_m + destination.egress_distance_m AS score
    FROM origin_routes origin
    JOIN destination_routes destination ON destination.route_id = origin.route_id

    UNION ALL

    SELECT
        ARRAY[origin.route_id, destination.route_id]::TEXT[],
        origin.access_distance_m
            + graph.transfer_distance_m
            + destination.egress_distance_m
    FROM settings
    JOIN origin_routes origin ON settings.max_transfers >= 1
    JOIN active_graph graph ON graph.from_route_id = origin.route_id
    JOIN destination_routes destination ON destination.route_id = graph.to_route_id
    WHERE origin.route_id <> destination.route_id

    UNION ALL

    SELECT
        ARRAY[origin.route_id, first_graph.to_route_id, destination.route_id]::TEXT[],
        origin.access_distance_m
            + first_graph.transfer_distance_m
            + second_graph.transfer_distance_m
            + destination.egress_distance_m
    FROM settings
    JOIN origin_routes origin ON settings.max_transfers >= 2
    JOIN active_graph first_graph ON first_graph.from_route_id = origin.route_id
    JOIN active_graph second_graph ON second_graph.from_route_id = first_graph.to_route_id
    JOIN destination_routes destination ON destination.route_id = second_graph.to_route_id
    WHERE origin.route_id <> first_graph.to_route_id
      AND first_graph.to_route_id <> destination.route_id
      AND origin.route_id <> destination.route_id
),
distinct_paths AS (
    SELECT DISTINCT ON (route_ids)
        route_ids,
        score
    FROM candidate_paths
    ORDER BY route_ids, score
),
limited_paths AS (
    SELECT route_ids, score
    FROM distinct_paths
    ORDER BY score, cardinality(route_ids), route_ids
    LIMIT (SELECT result_limit FROM settings)
)
SELECT COALESCE(
    jsonb_agg(
        jsonb_build_object(
            'id', md5(array_to_string(route_ids, '>')),
            'route_ids', to_jsonb(route_ids),
            'summary', array_to_string(route_ids, ' → '),
            'transfers', cardinality(route_ids) - 1,
            'provisional', TRUE
        )
        ORDER BY score, route_ids
    ),
    '[]'::JSONB
)
FROM limited_paths;
$function$;

REVOKE ALL ON FUNCTION public.plan_transit_route_skeletons(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.plan_transit_route_skeletons(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, INTEGER
) TO service_role;
