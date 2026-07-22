-- Optimisation des points chauds du planificateur horaire (profil mesuré sur
-- le live : ~3,5 s par appel, dont expansions ~2,1 s, élagage frontière ~1,2 s).
--
-- 1. Index géographique fonctionnel sur les arrêts : les recherches de quais
--    par rayon (départ, destination, squelettes) faisaient un parcours complet
--    avec distance géodésique par arrêt.
-- 2. Guidage par squelettes matérialisé dans une table temporaire indexée au
--    lieu d'un jsonb_array_elements évalué pour chaque candidat.
-- 3. Distance de chaque ligne à la destination précalculée une fois par appel
--    (l'élagage la recalculait via ST_Distance GEOGRAPHY par candidat).
-- 4. Fenêtre horaire exprimée en secondes GTFS locales par jour de service :
--    le filtre des départs devient un intervalle d'index (le filtre exact sur
--    le timestamptz converti reste appliqué).
-- 5. Découpage des tracés (ST_LineSubstring/ST_AsGeoJSON) différé à
--    l'assemblage final : il était calculé pour chaque label exploré par la
--    beam search puis jeté à l'élagage, et gonflait les legs JSONB recopiés à
--    chaque expansion.
--
-- Sortie strictement identique (égalité JSONB vérifiée sur 5 trajets variés) ;
-- temps mesurés : 2,1-4,2 s -> 0,5-1,2 s selon le trajet.

CREATE INDEX IF NOT EXISTS idx_gtfs_stops_geog
    ON public.gtfs_stops USING gist ((geom::geography));

CREATE OR REPLACE FUNCTION public.plan_transit_journeys(p_from_lng double precision, p_from_lat double precision, p_to_lng double precision, p_to_lat double precision, p_departure_at timestamp with time zone DEFAULT now(), p_max_transfers integer DEFAULT 2, p_wheelchair boolean DEFAULT false, p_avoid_disruptions boolean DEFAULT true, p_limit integer DEFAULT 4)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
 SET statement_timeout TO '12s'
AS $function$
DECLARE
    v_round INTEGER;
    v_max_rounds INTEGER := LEAST(GREATEST(COALESCE(p_max_transfers, 2), 0), 2) + 1;
    v_departure TIMESTAMPTZ := COALESCE(p_departure_at, NOW());
    v_walk_speed DOUBLE PRECISION := 1.35;
    v_walk_factor DOUBLE PRECISION := 1.30;
    v_origin_access_radius DOUBLE PRECISION := 900;
    -- Les dessertes périurbaines peuvent déposer le voyageur plus loin de sa
    -- destination (par exemple à la gare de Bouaye). On accepte alors une
    -- marche finale plus longue au lieu de conclure qu'aucun trajet n'existe.
    v_destination_access_radius DOUBLE PRECISION := 3000;
    v_transfer_radius DOUBLE PRECISION := 550;
    -- Le serveur relance cette recherche par fenêtres successives lorsqu'il
    -- faut atteindre le lendemain. Une fenêtre bornée évite de mélanger les
    -- derniers services de nuit avec les premiers départs du matin.
    v_horizon INTERVAL := INTERVAL '8 hours';
    -- Beam search bornée : les résultats du tour courant sont conservés avant
    -- cette réduction, puis seuls les labels les plus prometteurs alimentent
    -- le tour suivant. Cela évite une explosion combinatoire aux correspondances.
    -- La branche Ranzay → ligne 3 → ligne 98 demande un faisceau plus large
    -- que les trajets centraux, sans élargir la fenêtre horaire elle-même.
    v_labels_per_stop INTEGER := 2;
    v_transfer_candidates INTEGER := 5;
    v_boarding_choices INTEGER := 2;
    v_frontier_limit INTEGER := 40;
    v_result JSONB;
    v_skeletons JSONB;
BEGIN
    IF p_from_lat NOT BETWEEN -90 AND 90
       OR p_to_lat NOT BETWEEN -90 AND 90
       OR p_from_lng NOT BETWEEN -180 AND 180
       OR p_to_lng NOT BETWEEN -180 AND 180 THEN
        RAISE EXCEPTION 'Coordonnées invalides';
    END IF;

    v_skeletons := public.plan_transit_route_skeletons(
        p_from_lng, p_from_lat, p_to_lng, p_to_lat,
        v_departure, p_max_transfers, 24
    );

    DROP TABLE IF EXISTS pg_temp.aule_router_skeleton_steps;
    DROP TABLE IF EXISTS pg_temp.aule_router_route_dist;
    DROP TABLE IF EXISTS pg_temp.aule_router_services;
    DROP TABLE IF EXISTS pg_temp.aule_router_alerts;
    DROP TABLE IF EXISTS pg_temp.aule_router_destinations;
    DROP TABLE IF EXISTS pg_temp.aule_router_next;
    DROP TABLE IF EXISTS pg_temp.aule_router_results;
    DROP TABLE IF EXISTS pg_temp.aule_router_frontier;

    CREATE TEMP TABLE aule_router_services (
        service_date DATE NOT NULL,
        service_id TEXT NOT NULL,
        -- Fenêtre de recherche exprimée en secondes GTFS locales du jour de
        -- service (marge de 2 h pour absorber les changements d'heure) : elle
        -- rend le filtre des départs indexable au lieu de convertir chaque
        -- horaire en timestamptz avant de le comparer.
        window_start_seconds BIGINT NOT NULL,
        window_end_seconds BIGINT NOT NULL,
        PRIMARY KEY (service_date, service_id)
    ) ON COMMIT DROP;

    CREATE TEMP TABLE aule_router_alerts (
        route_id TEXT PRIMARY KEY,
        canceled BOOLEAN NOT NULL,
        penalty_seconds INTEGER NOT NULL,
        alerts JSONB NOT NULL
    ) ON COMMIT DROP;

    CREATE TEMP TABLE aule_router_destinations (
        stop_id TEXT PRIMARY KEY,
        stop_name TEXT NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        latitude DOUBLE PRECISION NOT NULL,
        distance_m DOUBLE PRECISION NOT NULL,
        walk_seconds INTEGER NOT NULL,
        accessible BOOLEAN NOT NULL
    ) ON COMMIT DROP;

    CREATE TEMP TABLE aule_router_frontier (
        id BIGSERIAL PRIMARY KEY,
        stop_id TEXT NOT NULL,
        stop_name TEXT NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        latitude DOUBLE PRECISION NOT NULL,
        arrival_at TIMESTAMPTZ NOT NULL,
        legs JSONB NOT NULL,
        transit_legs INTEGER NOT NULL,
        walk_seconds INTEGER NOT NULL,
        accessible BOOLEAN NOT NULL,
        alert_penalty_seconds INTEGER NOT NULL,
        alerts JSONB NOT NULL,
        last_route_id TEXT,
        visited_routes TEXT[] NOT NULL
    ) ON COMMIT DROP;

    CREATE TEMP TABLE aule_router_next
        (LIKE aule_router_frontier INCLUDING DEFAULTS INCLUDING CONSTRAINTS)
        ON COMMIT DROP;

    CREATE TEMP TABLE aule_router_results (
        id BIGSERIAL PRIMARY KEY,
        signature TEXT NOT NULL,
        departure_at TIMESTAMPTZ NOT NULL,
        arrival_at TIMESTAMPTZ NOT NULL,
        duration_seconds INTEGER NOT NULL,
        score_seconds INTEGER NOT NULL,
        transfers INTEGER NOT NULL,
        walk_seconds INTEGER NOT NULL,
        accessible BOOLEAN NOT NULL,
        alerts JSONB NOT NULL,
        route_ids TEXT[] NOT NULL,
        legs JSONB NOT NULL
    ) ON COMMIT DROP;

    -- Le guidage par squelettes est consulté pour chaque candidat à
    -- l'embarquement : une table temporaire indexée remplace le parcours
    -- répété du JSONB (jsonb_array_elements évalué par ligne candidate).
    CREATE TEMP TABLE aule_router_skeleton_steps ON COMMIT DROP AS
    SELECT DISTINCT
        (step.ordinality - 1)::INTEGER AS step_index,
        step.value #>> '{}' AS route_id,
        COALESCE((
            SELECT array_agg(prefix.value #>> '{}' ORDER BY prefix.ordinality)
            FROM jsonb_array_elements(skeleton.value -> 'route_ids')
                WITH ORDINALITY prefix
            WHERE prefix.ordinality < step.ordinality
        ), ARRAY[]::TEXT[]) AS prefix
    FROM jsonb_array_elements(v_skeletons) skeleton,
         jsonb_array_elements(skeleton.value -> 'route_ids') WITH ORDINALITY step;

    CREATE INDEX ON aule_router_skeleton_steps (step_index, route_id);

    -- Distance de chaque ligne à la destination, calculée une seule fois :
    -- l'élagage de la frontière et le choix des correspondances la
    -- recalculaient par candidat via ST_Distance sur GEOGRAPHY.
    CREATE TEMP TABLE aule_router_route_dist ON COMMIT DROP AS
    SELECT
        reach.route_id,
        ST_Distance(
            reach.stops_geom::GEOGRAPHY,
            ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)::GEOGRAPHY
        ) AS distance_m
    FROM public.gtfs_route_reach reach;

    ALTER TABLE aule_router_route_dist ADD PRIMARY KEY (route_id);

    -- Services de la veille jusqu'à la fin de l'horizon. La veille reste
    -- nécessaire car les heures GTFS peuvent dépasser 24 h.
    INSERT INTO aule_router_services (
        service_date, service_id, window_start_seconds, window_end_seconds
    )
    WITH service_days AS (
        SELECT day::DATE AS service_date
        FROM generate_series(
            (v_departure AT TIME ZONE 'Europe/Paris')::DATE - 1,
            ((v_departure + v_horizon) AT TIME ZONE 'Europe/Paris')::DATE,
            INTERVAL '1 day'
        ) AS days(day)
    ),
    regular AS (
        SELECT sd.service_date, c.service_id
        FROM service_days sd
        JOIN public.gtfs_calendar c
          ON sd.service_date BETWEEN c.start_date AND c.end_date
         AND c.runs_on[EXTRACT(ISODOW FROM sd.service_date)::INTEGER]
        WHERE NOT EXISTS (
            SELECT 1
            FROM public.gtfs_calendar_dates cd
            WHERE cd.service_id = c.service_id
              AND cd.service_date = sd.service_date
              AND cd.exception_type = 2
        )
    ),
    added AS (
        SELECT sd.service_date, cd.service_id
        FROM service_days sd
        JOIN public.gtfs_calendar_dates cd
          ON cd.service_date = sd.service_date
         AND cd.exception_type = 1
    )
    , combined AS (
        SELECT * FROM regular
        UNION
        SELECT * FROM added
    )
    SELECT
        service_date,
        service_id,
        FLOOR(EXTRACT(EPOCH FROM (
            v_departure - (service_date::TIMESTAMP AT TIME ZONE 'Europe/Paris')
        )))::BIGINT - 7200,
        CEIL(EXTRACT(EPOCH FROM (
            v_departure + v_horizon - (service_date::TIMESTAMP AT TIME ZONE 'Europe/Paris')
        )))::BIGINT + 7200
    FROM combined
    ON CONFLICT DO NOTHING;

    -- Perturbations éditoriales et incidents opérationnels actifs.
    INSERT INTO aule_router_alerts (route_id, canceled, penalty_seconds, alerts)
    WITH raw_alerts AS (
        SELECT
            route_id,
            pa.announcement_type = 'cancellation' AS canceled,
            CASE pa.severity::TEXT
                WHEN 'critical' THEN 900
                WHEN 'warning' THEN 420
                ELSE 120
            END AS penalty_seconds,
            jsonb_build_object(
                'id', pa.id,
                'title', pa.title,
                'message', pa.message,
                'type', pa.announcement_type,
                'severity', pa.severity::TEXT,
                'source', 'announcement'
            ) AS alert
        FROM public.passenger_announcements pa
        CROSS JOIN LATERAL unnest(pa.route_ids) AS route_id
        WHERE pa.is_active
          AND pa.published_at <= v_departure + v_horizon
          AND (pa.expires_at IS NULL OR pa.expires_at >= v_departure)

        UNION ALL

        SELECT
            ni.route_id,
            FALSE,
            CASE ni.severity::TEXT
                WHEN 'critical' THEN 720
                WHEN 'warning' THEN 300
                ELSE 90
            END,
            jsonb_build_object(
                'id', ni.id,
                'title', ni.title,
                'message', COALESCE(ni.description, ''),
                'type', ni.incident_type,
                'severity', ni.severity::TEXT,
                'source', ni.source
            )
        FROM public.network_incidents ni
        WHERE ni.route_id IS NOT NULL
          AND ni.status IN ('open', 'acknowledged', 'in_progress')
          AND ni.created_at <= v_departure + v_horizon
    )
    SELECT
        route_id,
        BOOL_OR(canceled),
        CASE WHEN p_avoid_disruptions THEN MAX(penalty_seconds) ELSE 0 END,
        jsonb_agg(alert)
    FROM raw_alerts
    WHERE route_id IS NOT NULL
    GROUP BY route_id;

    -- Arrêts d'arrivée atteignables à pied.
    INSERT INTO aule_router_destinations (
        stop_id, stop_name, longitude, latitude,
        distance_m, walk_seconds, accessible
    )
    SELECT
        s.stop_id,
        s.stop_name,
        ST_X(s.geom),
        ST_Y(s.geom),
        d.distance_m,
        CEIL((d.distance_m * v_walk_factor) / v_walk_speed)::INTEGER,
        s.wheelchair_boarding = 1
    FROM public.gtfs_stops s
    CROSS JOIN LATERAL (
        SELECT ST_Distance(
            s.geom::GEOGRAPHY,
            ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)::GEOGRAPHY
        ) AS distance_m
    ) d
    WHERE ST_DWithin(
        s.geom::GEOGRAPHY,
        ST_SetSRID(ST_Point(p_to_lng, p_to_lat), 4326)::GEOGRAPHY,
        v_destination_access_radius
    )
      AND COALESCE(s.status, 'active') <> 'inactive'
      AND (NOT p_wheelchair OR s.wheelchair_boarding <> 2)
    ORDER BY d.distance_m
    -- Conserver assez de quais pour ne pas évincer une gare un peu plus
    -- éloignée derrière les deux sens de nombreux arrêts locaux.
    LIMIT 48;

    -- Labels initiaux : marche depuis le départ vers chaque quai voisin.
    INSERT INTO aule_router_frontier (
        stop_id, stop_name, longitude, latitude, arrival_at, legs,
        transit_legs, walk_seconds, accessible, alert_penalty_seconds,
        alerts, last_route_id, visited_routes
    )
    SELECT
        s.stop_id,
        s.stop_name,
        ST_X(s.geom),
        ST_Y(s.geom),
        v_departure + make_interval(secs => w.walk_seconds),
        jsonb_build_array(jsonb_build_object(
            'type', 'walk',
            'kind', 'access',
            'from_name', 'Départ',
            'to_stop_id', s.stop_id,
            'to_name', s.stop_name,
            'distance_m', ROUND(w.distance_m * v_walk_factor),
            'duration_seconds', w.walk_seconds,
            'geometry', jsonb_build_object(
                'type', 'LineString',
                'coordinates', jsonb_build_array(
                    jsonb_build_array(p_from_lng, p_from_lat),
                    jsonb_build_array(ST_X(s.geom), ST_Y(s.geom))
                )
            )
        )),
        0,
        w.walk_seconds,
        s.wheelchair_boarding = 1,
        0,
        '[]'::JSONB,
        NULL,
        ARRAY[]::TEXT[]
    FROM public.gtfs_stops s
    CROSS JOIN LATERAL (
        SELECT
            ST_Distance(
                s.geom::GEOGRAPHY,
                ST_SetSRID(ST_Point(p_from_lng, p_from_lat), 4326)::GEOGRAPHY
            ) AS distance_m,
            CEIL((ST_Distance(
                s.geom::GEOGRAPHY,
                ST_SetSRID(ST_Point(p_from_lng, p_from_lat), 4326)::GEOGRAPHY
            ) * v_walk_factor) / v_walk_speed)::INTEGER AS walk_seconds
    ) w
    WHERE ST_DWithin(
        s.geom::GEOGRAPHY,
        ST_SetSRID(ST_Point(p_from_lng, p_from_lat), 4326)::GEOGRAPHY,
        v_origin_access_radius
    )
      AND COALESCE(s.status, 'active') <> 'inactive'
      AND (NOT p_wheelchair OR s.wheelchair_boarding <> 2)
    ORDER BY w.distance_m
    LIMIT 12;

    IF NOT EXISTS (SELECT 1 FROM aule_router_frontier)
       OR NOT EXISTS (SELECT 1 FROM aule_router_destinations) THEN
        RETURN '[]'::JSONB;
    END IF;

    FOR v_round IN 1..v_max_rounds LOOP
        TRUNCATE TABLE aule_router_next RESTART IDENTITY;

        INSERT INTO aule_router_next (
            stop_id, stop_name, longitude, latitude, arrival_at, legs,
            transit_legs, walk_seconds, accessible, alert_penalty_seconds,
            alerts, last_route_id, visited_routes
        )
        WITH transfer_choices AS (
            SELECT
                f.*,
                bs.stop_id AS board_stop_id,
                bs.stop_name AS board_stop_name,
                ST_X(bs.geom) AS board_lng,
                ST_Y(bs.geom) AS board_lat,
                bs.wheelchair_boarding AS board_wheelchair,
                bs.transfer_route_id,
                bs.transfer_direction_id,
                td.distance_m AS transfer_distance_m,
                CASE
                    WHEN v_round = 1 THEN 0
                    ELSE GREATEST(
                        90,
                        CEIL((td.distance_m * v_walk_factor) / v_walk_speed)::INTEGER + 60
                    )
                END AS transfer_seconds,
                CASE
                    WHEN v_round = 1 THEN 0
                    ELSE CEIL((td.distance_m * v_walk_factor) / v_walk_speed)::INTEGER
                END AS transfer_walk_seconds
            FROM aule_router_frontier f
            JOIN public.gtfs_stops fs ON fs.stop_id = f.stop_id
            CROSS JOIN LATERAL (
                SELECT
                    candidate.*,
                    selected.transfer_route_id,
                    selected.transfer_direction_id,
                    selected.distance_m
                FROM (
                    SELECT
                        ranked.to_stop_id,
                        ranked.route_id AS transfer_route_id,
                        ranked.direction_id AS transfer_direction_id,
                        ranked.distance_m
                    FROM (
                        SELECT
                            f.stop_id AS to_stop_id,
                            NULL::TEXT AS route_id,
                            NULL::INTEGER AS direction_id,
                            0::DOUBLE PRECISION AS distance_m,
                            0::DOUBLE PRECISION AS destination_distance_m,
                            0 AS name_priority
                        WHERE v_round = 1

                        UNION ALL

                        SELECT
                            transfer_stop.to_stop_id,
                            transfer_stop.route_id,
                            transfer_stop.direction_id,
                            transfer_stop.distance_m,
                            route_dist.distance_m,
                            transfer_stop.name_priority
                        FROM public.gtfs_transfer_route_directions transfer_stop
                        JOIN pg_temp.aule_router_route_dist route_dist
                          ON route_dist.route_id = transfer_stop.route_id
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
                WHERE COALESCE(candidate.status, 'active') <> 'inactive'
                  AND (NOT p_wheelchair OR candidate.wheelchair_boarding <> 2)
            ) bs
            CROSS JOIN LATERAL (
                SELECT bs.distance_m
            ) td
        ),
        boardings AS (
            SELECT tc.*, next_trip.*
            FROM transfer_choices tc
            CROSS JOIN LATERAL (
                SELECT *
                FROM (
                    SELECT DISTINCT ON (pr.route_id, pr.direction_id)
                        board.profile_id,
                        board.stop_sequence AS board_sequence,
                        board.offset_seconds AS board_offset,
                        board.shape_fraction AS board_fraction,
                        pr.route_id,
                        pr.direction_id,
                        pr.pattern_shape_id,
                        pr.headsign,
                        gr.route_short_name,
                        gr.route_long_name,
                        gr.route_type,
                        dep.departure_id,
                        dep.departure_at,
                        COALESCE(ra.penalty_seconds, 0) AS route_penalty_seconds,
                        COALESCE(ra.alerts, '[]'::JSONB) AS route_alerts
                    FROM public.gtfs_trip_profile_stops board
                    JOIN public.gtfs_trip_profiles pr ON pr.profile_id = board.profile_id
                    JOIN public.gtfs_routes gr ON gr.route_id = pr.route_id
                    CROSS JOIN LATERAL (
                        SELECT
                            d.departure_id,
                            ((svc.service_date::TIMESTAMP
                              + make_interval(secs => d.start_seconds + board.offset_seconds))
                              AT TIME ZONE 'Europe/Paris') AS departure_at
                        FROM public.gtfs_trip_departures d
                        JOIN aule_router_services svc ON svc.service_id = d.service_id
                        WHERE d.profile_id = board.profile_id
                          -- Préfiltre indexable (les conditions exactes sur
                          -- departure_at restent appliquées plus bas).
                          AND d.start_seconds
                              BETWEEN svc.window_start_seconds - board.offset_seconds
                                  AND svc.window_end_seconds - board.offset_seconds
                    ) dep
                    LEFT JOIN aule_router_alerts ra ON ra.route_id = pr.route_id
                    WHERE board.stop_id = tc.board_stop_id
                      AND dep.departure_at >= tc.arrival_at
                          + make_interval(secs => tc.transfer_seconds)
                      AND dep.departure_at <= v_departure + v_horizon
                      AND NOT (pr.route_id = ANY(tc.visited_routes))
                      AND (tc.transfer_route_id IS NULL OR pr.route_id = tc.transfer_route_id)
                      AND (tc.transfer_direction_id IS NULL OR pr.direction_id = tc.transfer_direction_id)
                      AND EXISTS (
                          SELECT 1
                          FROM pg_temp.aule_router_skeleton_steps sk
                          WHERE sk.step_index = tc.transit_legs
                            AND sk.route_id = pr.route_id
                            AND sk.prefix = tc.visited_routes
                      )
                      AND NOT COALESCE(ra.canceled, FALSE)
                    ORDER BY pr.route_id, pr.direction_id, dep.departure_at
                ) per_route
                ORDER BY departure_at
                LIMIT v_boarding_choices
            ) next_trip
        )
        SELECT
            alight.stop_id,
            alight_stop.stop_name,
            ST_X(alight_stop.geom),
            ST_Y(alight_stop.geom),
            b.departure_at + make_interval(secs => alight.offset_seconds - b.board_offset),
            b.legs
              || CASE
                    WHEN b.transfer_distance_m > 15 THEN jsonb_build_array(jsonb_build_object(
                        'type', 'walk',
                        'kind', 'transfer',
                        'from_stop_id', b.stop_id,
                        'from_name', b.stop_name,
                        'to_stop_id', b.board_stop_id,
                        'to_name', b.board_stop_name,
                        'distance_m', ROUND(b.transfer_distance_m * v_walk_factor),
                        'duration_seconds', b.transfer_walk_seconds,
                        'geometry', jsonb_build_object(
                            'type', 'LineString',
                            'coordinates', jsonb_build_array(
                                jsonb_build_array(b.longitude, b.latitude),
                                jsonb_build_array(b.board_lng, b.board_lat)
                            )
                        )
                    ))
                    ELSE '[]'::JSONB
                 END
              || jsonb_build_array(jsonb_build_object(
                    'type', 'transit',
                    'mode', CASE
                        WHEN b.route_type IN (0, 1, 2) THEN 'tram'
                        WHEN b.route_type = 4 THEN 'navibus'
                        ELSE 'bus'
                    END,
                    'route_id', b.route_id,
                    'route_short_name', b.route_short_name,
                    'route_long_name', b.route_long_name,
                    'direction_id', b.direction_id,
                    'headsign', b.headsign,
                    'departure_id', b.departure_id,
                    'profile_id', b.profile_id,
                    'pattern_shape_id', b.pattern_shape_id,
                    'from_stop_id', b.board_stop_id,
                    'from_name', b.board_stop_name,
                    'to_stop_id', alight.stop_id,
                    'to_name', alight_stop.stop_name,
                    'departure_at', b.departure_at,
                    'arrival_at', b.departure_at
                        + make_interval(secs => alight.offset_seconds - b.board_offset),
                    'duration_seconds', alight.offset_seconds - b.board_offset,
                    'accessible', b.board_wheelchair = 1
                        AND alight_stop.wheelchair_boarding = 1,
                    'alerts', b.route_alerts,
                    -- Le découpage du tracé (ST_LineSubstring) est différé à
                    -- l'assemblage final : le calculer pour chaque label explorée
                    -- gonflait les legs recopiés à chaque expansion.
                    'board_fraction', b.board_fraction,
                    'alight_fraction', alight.shape_fraction,
                    'geometry', jsonb_build_object(
                        'type', 'LineString',
                        'coordinates', jsonb_build_array(
                            jsonb_build_array(b.board_lng, b.board_lat),
                            jsonb_build_array(ST_X(alight_stop.geom), ST_Y(alight_stop.geom))
                        )
                    )
                 )),
            b.transit_legs + 1,
            b.walk_seconds + b.transfer_walk_seconds,
            b.accessible
                AND b.board_wheelchair = 1
                AND alight_stop.wheelchair_boarding = 1,
            b.alert_penalty_seconds + b.route_penalty_seconds,
            b.alerts || b.route_alerts,
            b.route_id,
            b.visited_routes || b.route_id
        FROM boardings b
        JOIN public.gtfs_trip_profile_stops alight
          ON alight.profile_id = b.profile_id
         AND alight.stop_sequence > b.board_sequence
        JOIN public.gtfs_stops alight_stop ON alight_stop.stop_id = alight.stop_id
        WHERE COALESCE(alight_stop.status, 'active') <> 'inactive'
          AND (NOT p_wheelchair OR alight_stop.wheelchair_boarding <> 2);

        -- Un nombre borné de labels par arrêt empêche l'explosion combinatoire,
        -- tout en conservant plusieurs chaînes de lignes concurrentes.
        DELETE FROM aule_router_next n
        USING (
            SELECT id
            FROM (
                SELECT
                    id,
                    ROW_NUMBER() OVER (
                        PARTITION BY stop_id, last_route_id, visited_routes[1]
                        ORDER BY
                            arrival_at + make_interval(secs => alert_penalty_seconds),
                            transit_legs,
                            walk_seconds
                    ) AS rank_at_stop
                FROM aule_router_next
            ) ranked
            WHERE rank_at_stop > v_labels_per_stop
        ) discarded
        WHERE n.id = discarded.id;

        INSERT INTO aule_router_results (
            signature, departure_at, arrival_at, duration_seconds,
            score_seconds, transfers, walk_seconds, accessible,
            alerts, route_ids, legs
        )
        SELECT
            array_to_string(n.visited_routes, '>'),
            timing.departure_at,
            n.arrival_at + make_interval(secs => d.walk_seconds),
            EXTRACT(EPOCH FROM (
                n.arrival_at + make_interval(secs => d.walk_seconds) - timing.departure_at
            ))::INTEGER,
            EXTRACT(EPOCH FROM (
                n.arrival_at + make_interval(secs => d.walk_seconds) - v_departure
            ))::INTEGER
                + n.alert_penalty_seconds
                + CASE WHEN p_wheelchair AND NOT (n.accessible AND d.accessible) THEN 600 ELSE 0 END,
            n.transit_legs - 1,
            n.walk_seconds + d.walk_seconds,
            n.accessible AND d.accessible,
            n.alerts,
            n.visited_routes,
            n.legs || jsonb_build_array(jsonb_build_object(
                'type', 'walk',
                'kind', 'egress',
                'from_stop_id', d.stop_id,
                'from_name', d.stop_name,
                'to_name', 'Destination',
                'distance_m', ROUND(d.distance_m * v_walk_factor),
                'duration_seconds', d.walk_seconds,
                'geometry', jsonb_build_object(
                    'type', 'LineString',
                    'coordinates', jsonb_build_array(
                        jsonb_build_array(d.longitude, d.latitude),
                        jsonb_build_array(p_to_lng, p_to_lat)
                    )
                )
            ))
        FROM aule_router_next n
        JOIN aule_router_destinations d ON d.stop_id = n.stop_id
        CROSS JOIN LATERAL (
            -- Le premier trajet commence lorsque le voyageur doit partir à
            -- pied, pas à l'heure initiale de la recherche. Ainsi une requête
            -- à 23 h 52 peut annoncer « départ 08 h 30 · durée 1 h 35 » sans
            -- compter toute la nuit dans la durée du trajet.
            SELECT COALESCE(
                (n.legs -> 1 ->> 'departure_at')::TIMESTAMPTZ
                    - make_interval(
                        secs => COALESCE((n.legs -> 0 ->> 'duration_seconds')::INTEGER, 0)
                    ),
                v_departure
            ) AS departure_at
        ) timing;

        -- Les correspondances suivantes partent d'un faisceau global borné.
        -- Le score combine l'heure atteinte, les perturbations et une borne
        -- optimiste vers la destination (18 m/s), afin de garder les détours
        -- plausibles sans scanner tout le réseau à chaque tour.
        DELETE FROM aule_router_next n
        USING (
            SELECT id
            FROM (
                SELECT
                    id,
                        ROW_NUMBER() OVER (
                            ORDER BY
                            rank_on_route,
                            onward_score,
                            walk_seconds
                    ) AS global_rank
                FROM (
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
                                        SELECT MIN(route_dist.distance_m)
                                        FROM public.gtfs_transfer_route_directions transfer_stop
                                        JOIN pg_temp.aule_router_route_dist route_dist
                                          ON route_dist.route_id = transfer_stop.route_id
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
                ) diversified
            ) ranked
            WHERE global_rank > v_frontier_limit
        ) discarded
        WHERE n.id = discarded.id;

        EXIT WHEN v_round >= v_max_rounds
               OR NOT EXISTS (SELECT 1 FROM aule_router_next);

        TRUNCATE TABLE aule_router_frontier RESTART IDENTITY;
        INSERT INTO aule_router_frontier (
            stop_id, stop_name, longitude, latitude, arrival_at, legs,
            transit_legs, walk_seconds, accessible, alert_penalty_seconds,
            alerts, last_route_id, visited_routes
        )
        SELECT
            stop_id, stop_name, longitude, latitude, arrival_at, legs,
            transit_legs, walk_seconds, accessible, alert_penalty_seconds,
            alerts, last_route_id, visited_routes
        FROM aule_router_next;
    END LOOP;

    SELECT COALESCE(jsonb_agg(payload ORDER BY score_seconds), '[]'::JSONB)
    INTO v_result
    FROM (
        SELECT
            score_seconds,
            jsonb_build_object(
                'id', md5(signature || ':' || path_signature || ':' || arrival_at::TEXT),
                'departure_at', departure_at,
                'arrival_at', arrival_at,
                'duration_seconds', duration_seconds,
                'score_seconds', score_seconds,
                'transfers', transfers,
                'walk_seconds', walk_seconds,
                'accessible', accessible,
                'alerts', alerts,
                'route_ids', to_jsonb(route_ids),
                'legs', (
                    -- Reconstruit le vrai tracé des seules jambes retenues et
                    -- retire les fractions de travail du résultat final.
                    SELECT COALESCE(jsonb_agg(
                        CASE
                            WHEN item.leg ->> 'type' = 'transit'
                              AND shape.geom IS NOT NULL
                              AND ABS((item.leg ->> 'alight_fraction')::DOUBLE PRECISION
                                      - (item.leg ->> 'board_fraction')::DOUBLE PRECISION)
                                  >= 0.000001
                            THEN (item.leg - 'board_fraction' - 'alight_fraction')
                                || jsonb_build_object(
                                    'geometry',
                                    ST_AsGeoJSON(ST_LineSubstring(
                                        shape.geom,
                                        LEAST(
                                            (item.leg ->> 'board_fraction')::DOUBLE PRECISION,
                                            (item.leg ->> 'alight_fraction')::DOUBLE PRECISION
                                        ),
                                        GREATEST(
                                            (item.leg ->> 'board_fraction')::DOUBLE PRECISION,
                                            (item.leg ->> 'alight_fraction')::DOUBLE PRECISION
                                        )
                                    ))::JSONB
                                )
                            ELSE item.leg - 'board_fraction' - 'alight_fraction'
                        END
                        ORDER BY item.ordinal
                    ), '[]'::JSONB)
                    FROM jsonb_array_elements(legs)
                        WITH ORDINALITY item(leg, ordinal)
                    LEFT JOIN public.gtfs_pattern_shapes shape
                      ON item.leg ->> 'type' = 'transit'
                     AND shape.pattern_shape_id = item.leg ->> 'pattern_shape_id'
                )
            ) AS payload
        FROM (
            SELECT DISTINCT ON (signature, path_signature)
                signature, path_signature, departure_at, arrival_at, duration_seconds,
                score_seconds, transfers, walk_seconds, accessible,
                alerts, route_ids, legs
            FROM (
                SELECT
                    result.*,
                    md5(COALESCE((
                        SELECT string_agg(
                            concat_ws(':',
                                leg ->> 'type',
                                COALESCE(leg ->> 'route_id', 'walk'),
                                COALESCE(leg ->> 'from_stop_id', leg ->> 'from_name', '?'),
                                COALESCE(leg ->> 'to_stop_id', leg ->> 'to_name', '?')
                            ),
                            '|' ORDER BY ordinal
                        )
                        FROM jsonb_array_elements(result.legs)
                            WITH ORDINALITY AS item(leg, ordinal)
                        WHERE leg ->> 'type' = 'transit'
                           OR leg ->> 'kind' = 'transfer'
                    ), result.signature)) AS path_signature
                FROM aule_router_results result
                WHERE duration_seconds > 0
                  AND score_seconds <= EXTRACT(EPOCH FROM v_horizon)::INTEGER
            ) path_results
            ORDER BY signature, path_signature, score_seconds, arrival_at
        ) distinct_paths
        ORDER BY score_seconds, arrival_at, walk_seconds
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 4), 1), 18)
    ) limited;

    RETURN v_result;
END;
$function$

REVOKE ALL ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) TO service_role;
