-- Le rayon destination étendu doit rester disponible pour les adresses
-- éloignées d'un arrêt, mais conserver 128 labels à chaque tour double le
-- coût des recherches à deux correspondances. 64 garde une marge confortable
-- tout en bornant davantage les jointures des tours suivants.
DO $$
DECLARE
    function_definition TEXT;
    optimized_definition TEXT;
BEGIN
    SELECT pg_get_functiondef(
        'public.plan_transit_journeys(double precision,double precision,double precision,double precision,timestamp with time zone,integer,boolean,boolean,integer)'::REGPROCEDURE
    )
    INTO function_definition;

    optimized_definition := replace(
        function_definition,
        'v_frontier_limit INTEGER := 128;',
        'v_frontier_limit INTEGER := 64;'
    );

    IF optimized_definition = function_definition THEN
        RAISE EXCEPTION 'La limite 128 du planificateur est introuvable';
    END IF;

    EXECUTE optimized_definition;
END;
$$;
