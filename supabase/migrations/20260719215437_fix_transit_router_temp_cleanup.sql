-- Une table créée avec LIKE ... INCLUDING DEFAULTS réutilise la séquence de
-- la table source. Il faut donc supprimer aule_router_next avant sa source
-- aule_router_frontier lorsqu'une connexion du pool exécute plusieurs calculs.

DO $migration$
DECLARE
    planner_signature REGPROCEDURE :=
        'public.plan_transit_journeys(double precision,double precision,double precision,double precision,timestamp with time zone,integer,boolean,boolean,integer)'::REGPROCEDURE;
    original_definition TEXT;
    updated_definition TEXT;
BEGIN
    SELECT pg_get_functiondef(planner_signature)
    INTO original_definition;

    updated_definition := replace(
        original_definition,
        E'    DROP TABLE IF EXISTS pg_temp.aule_router_destinations;\n    DROP TABLE IF EXISTS pg_temp.aule_router_frontier;\n    DROP TABLE IF EXISTS pg_temp.aule_router_next;\n    DROP TABLE IF EXISTS pg_temp.aule_router_results;',
        E'    DROP TABLE IF EXISTS pg_temp.aule_router_destinations;\n    DROP TABLE IF EXISTS pg_temp.aule_router_next;\n    DROP TABLE IF EXISTS pg_temp.aule_router_results;\n    DROP TABLE IF EXISTS pg_temp.aule_router_frontier;'
    );

    IF updated_definition NOT LIKE E'%DROP TABLE IF EXISTS pg_temp.aule_router_next;\n    DROP TABLE IF EXISTS pg_temp.aule_router_results;\n    DROP TABLE IF EXISTS pg_temp.aule_router_frontier;%' THEN
        RAISE EXCEPTION 'L''ordre de nettoyage des tables temporaires est incorrect';
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
