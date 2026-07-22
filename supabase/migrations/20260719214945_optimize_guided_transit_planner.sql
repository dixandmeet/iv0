-- Guide d'abord le calcul horaire avec un petit ensemble de chaînes de lignes
-- topologiquement plausibles. La recherche détaillée évite ainsi de scanner
-- toutes les lignes à chaque tour, tout en conservant plusieurs points de
-- correspondance pour une même chaîne (Place du Cirque / Bretagne notamment).

DO $migration$
DECLARE
    skeleton_signature REGPROCEDURE :=
        'public.plan_transit_route_skeletons(double precision,double precision,double precision,double precision,timestamp with time zone,integer,integer)'::REGPROCEDURE;
    planner_signature REGPROCEDURE :=
        'public.plan_transit_journeys(double precision,double precision,double precision,double precision,timestamp with time zone,integer,boolean,boolean,integer)'::REGPROCEDURE;
    original_definition TEXT;
    updated_definition TEXT;
BEGIN
    SELECT pg_get_functiondef(skeleton_signature)
    INTO original_definition;

    updated_definition := replace(
        original_definition,
        'LEAST(GREATEST(COALESCE(p_limit, 10), 1), 12)',
        'LEAST(GREATEST(COALESCE(p_limit, 10), 1), 24)'
    );
    updated_definition := replace(
        updated_definition,
        E'limited_paths AS (\n    SELECT route_ids, score\n    FROM distinct_paths\n    ORDER BY score, cardinality(route_ids), route_ids\n    LIMIT (SELECT result_limit FROM settings)\n)',
        E'pair_ranked_paths AS (\n    SELECT\n        route_ids,\n        score,\n        ROW_NUMBER() OVER (\n            PARTITION BY route_ids[1], route_ids[cardinality(route_ids)]\n            ORDER BY cardinality(route_ids), score, route_ids\n        ) AS pair_rank\n    FROM distinct_paths\n),\norigin_ranked_paths AS (\n    SELECT\n        route_ids,\n        score,\n        ROW_NUMBER() OVER (\n            PARTITION BY route_ids[1]\n            ORDER BY cardinality(route_ids), score, route_ids\n        ) AS origin_rank\n    FROM pair_ranked_paths\n    WHERE pair_rank = 1\n),\nlimited_paths AS (\n    SELECT route_ids, score\n    FROM origin_ranked_paths\n    WHERE origin_rank <= 4\n    ORDER BY score, cardinality(route_ids), route_ids\n    LIMIT (SELECT result_limit FROM settings)\n)'
    );

    IF updated_definition NOT LIKE '%p_limit, 10), 1), 24)%'
       OR updated_definition NOT LIKE '%PARTITION BY route_ids[1], route_ids[cardinality(route_ids)]%'
       OR updated_definition NOT LIKE '%origin_rank <= 4%'
    THEN
        RAISE EXCEPTION 'La diversification des chaînes de lignes est incomplète';
    END IF;

    IF updated_definition <> original_definition THEN
        EXECUTE updated_definition;
    END IF;

    SELECT pg_get_functiondef(planner_signature)
    INTO original_definition;

    updated_definition := replace(
        original_definition,
        'v_frontier_limit INTEGER := 80;',
        'v_frontier_limit INTEGER := 40;'
    );
    IF updated_definition NOT LIKE '%v_skeletons JSONB;%' THEN
        updated_definition := replace(
            updated_definition,
            E'    v_result JSONB;\nBEGIN',
            E'    v_result JSONB;\n    v_skeletons JSONB;\nBEGIN'
        );
    END IF;
    IF updated_definition NOT LIKE '%v_skeletons := public.plan_transit_route_skeletons(%' THEN
        updated_definition := replace(
            updated_definition,
            '    DROP TABLE IF EXISTS pg_temp.aule_router_services;',
            E'    v_skeletons := public.plan_transit_route_skeletons(\n        p_from_lng, p_from_lat, p_to_lng, p_to_lat,\n        v_departure, p_max_transfers, 24\n    );\n\n    DROP TABLE IF EXISTS pg_temp.aule_router_services;'
        );
    END IF;
    IF updated_definition NOT LIKE '%jsonb_array_elements(v_skeletons)%' THEN
        updated_definition := replace(
            updated_definition,
            E'                      AND (tc.transfer_direction_id IS NULL OR pr.direction_id = tc.transfer_direction_id)\n                      AND NOT COALESCE(ra.canceled, FALSE)',
            E'                      AND (tc.transfer_direction_id IS NULL OR pr.direction_id = tc.transfer_direction_id)\n                      AND EXISTS (\n                          SELECT 1\n                          FROM jsonb_array_elements(v_skeletons) skeleton\n                          WHERE skeleton -> ''route_ids'' ->> tc.transit_legs = pr.route_id\n                            AND NOT EXISTS (\n                                SELECT 1\n                                FROM generate_series(0, tc.transit_legs - 1) route_index\n                                WHERE skeleton -> ''route_ids'' ->> route_index\n                                      IS DISTINCT FROM tc.visited_routes[route_index + 1]\n                            )\n                      )\n                      AND NOT COALESCE(ra.canceled, FALSE)'
        );
    END IF;

    IF updated_definition NOT LIKE '%v_frontier_limit INTEGER := 40;%'
       OR updated_definition NOT LIKE '%v_skeletons := public.plan_transit_route_skeletons(%'
       OR updated_definition NOT LIKE '%jsonb_array_elements(v_skeletons)%'
       OR updated_definition NOT LIKE '%tc.visited_routes[route_index + 1]%'
    THEN
        RAISE EXCEPTION 'Le guidage du planificateur horaire est incomplet';
    END IF;

    IF updated_definition <> original_definition THEN
        EXECUTE updated_definition;
    END IF;
END
$migration$;

REVOKE ALL ON FUNCTION public.plan_transit_route_skeletons(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.plan_transit_route_skeletons(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, INTEGER
) TO service_role;

REVOKE ALL ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) TO service_role;
