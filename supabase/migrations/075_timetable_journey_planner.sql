-- Moteur d'itinéraires horaires Aule.
--
-- Exploite la grille GTFS complète compressée par la migration 067. La
-- recherche fonctionne par tours, sur le principe de RAPTOR :
--   tour 1 = trajet direct ; tour 2 = une correspondance ;
--   tour 3 = deux correspondances.
-- Chaque tour conserve plusieurs labels par arrêt afin de produire des
-- alternatives réellement différentes, et non de simples variantes de tracé.

CREATE INDEX IF NOT EXISTS idx_gtfs_profile_stops_stop_profile_sequence
    ON public.gtfs_trip_profile_stops (stop_id, profile_id, stop_sequence);

CREATE INDEX IF NOT EXISTS idx_gtfs_departures_profile_service_start
    ON public.gtfs_trip_departures (profile_id, service_id, start_seconds);

CREATE INDEX IF NOT EXISTS idx_gtfs_calendar_dates_date_service
    ON public.gtfs_calendar_dates (service_date, service_id, exception_type);

CREATE INDEX IF NOT EXISTS idx_passenger_announcements_routes_active
    ON public.passenger_announcements USING gin (route_ids)
    WHERE is_active = TRUE;

CREATE OR REPLACE FUNCTION public.plan_transit_journeys(
    p_from_lng DOUBLE PRECISION,
    p_from_lat DOUBLE PRECISION,
    p_to_lng DOUBLE PRECISION,
    p_to_lat DOUBLE PRECISION,
    p_departure_at TIMESTAMPTZ DEFAULT NOW(),
    p_max_transfers INTEGER DEFAULT 2,
    p_wheelchair BOOLEAN DEFAULT FALSE,
    p_avoid_disruptions BOOLEAN DEFAULT TRUE,
    p_limit INTEGER DEFAULT 4
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET statement_timeout = '12s'
AS $$
DECLARE
    v_round INTEGER;
    v_max_rounds INTEGER := LEAST(GREATEST(COALESCE(p_max_transfers, 2), 0), 2) + 1;
    v_departure TIMESTAMPTZ := COALESCE(p_departure_at, NOW());
    v_walk_speed DOUBLE PRECISION := 1.35;
    v_walk_factor DOUBLE PRECISION := 1.30;
    v_access_radius DOUBLE PRECISION := 900;
    v_transfer_radius DOUBLE PRECISION := 550;
    v_horizon INTERVAL := INTERVAL '4 hours';
    -- Beam search bornée : les résultats du tour courant sont conservés avant
    -- cette réduction, puis seuls les labels les plus prometteurs alimentent
    -- le tour suivant. Cela évite une explosion combinatoire aux correspondances.
    v_labels_per_stop INTEGER := 2;
    v_transfer_candidates INTEGER := 5;
    v_boarding_choices INTEGER := 2;
    v_frontier_limit INTEGER := 32;
    v_result JSONB;
BEGIN
    IF p_from_lat NOT BETWEEN -90 AND 90
       OR p_to_lat NOT BETWEEN -90 AND 90
       OR p_from_lng NOT BETWEEN -180 AND 180
       OR p_to_lng NOT BETWEEN -180 AND 180 THEN
        RAISE EXCEPTION 'Coordonnées invalides';
    END IF;

    DROP TABLE IF EXISTS pg_temp.aule_router_services;
    DROP TABLE IF EXISTS pg_temp.aule_router_alerts;
    DROP TABLE IF EXISTS pg_temp.aule_router_destinations;
    DROP TABLE IF EXISTS pg_temp.aule_router_frontier;
    DROP TABLE IF EXISTS pg_temp.aule_router_next;
    DROP TABLE IF EXISTS pg_temp.aule_router_results;

    CREATE TEMP TABLE aule_router_services (
        service_date DATE NOT NULL,
        service_id TEXT NOT NULL,
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

    -- Services du jour et de la veille : les heures GTFS peuvent dépasser 24 h.
    INSERT INTO aule_router_services (service_date, service_id)
    WITH service_days AS (
        SELECT d::DATE AS service_date
        FROM (VALUES
            ((v_departure AT TIME ZONE 'Europe/Paris')::DATE),
            ((v_departure AT TIME ZONE 'Europe/Paris')::DATE - 1)
        ) AS days(d)
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
    SELECT * FROM regular
    UNION
    SELECT * FROM added
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
        v_access_radius
    )
      AND COALESCE(s.status, 'active') <> 'inactive'
      AND (NOT p_wheelchair OR s.wheelchair_boarding <> 2)
    ORDER BY d.distance_m
    LIMIT 12;

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
        v_access_radius
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
                  AND COALESCE(candidate.status, 'active') <> 'inactive'
                  AND (NOT p_wheelchair OR candidate.wheelchair_boarding <> 2)
                ORDER BY
                    CASE WHEN candidate.stop_name = fs.stop_name THEN 0 ELSE 1 END,
                    distance_m
                LIMIT CASE WHEN v_round = 1 THEN 1 ELSE v_transfer_candidates END
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
                    ) dep
                    LEFT JOIN aule_router_alerts ra ON ra.route_id = pr.route_id
                    WHERE board.stop_id = tc.board_stop_id
                      AND dep.departure_at >= tc.arrival_at
                          + make_interval(secs => tc.transfer_seconds)
                      AND dep.departure_at <= v_departure + v_horizon
                      AND NOT (pr.route_id = ANY(tc.visited_routes))
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
                    'geometry', CASE
                        WHEN shape.geom IS NULL
                          OR ABS(alight.shape_fraction - b.board_fraction) < 0.000001
                        THEN jsonb_build_object(
                            'type', 'LineString',
                            'coordinates', jsonb_build_array(
                                jsonb_build_array(b.board_lng, b.board_lat),
                                jsonb_build_array(ST_X(alight_stop.geom), ST_Y(alight_stop.geom))
                            )
                        )
                        ELSE ST_AsGeoJSON(ST_LineSubstring(
                            shape.geom,
                            LEAST(b.board_fraction, alight.shape_fraction),
                            GREATEST(b.board_fraction, alight.shape_fraction)
                        ))::JSONB
                    END
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
        LEFT JOIN public.gtfs_pattern_shapes shape
          ON shape.pattern_shape_id = b.pattern_shape_id
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
                        PARTITION BY stop_id
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
            v_departure,
            n.arrival_at + make_interval(secs => d.walk_seconds),
            EXTRACT(EPOCH FROM (
                n.arrival_at + make_interval(secs => d.walk_seconds) - v_departure
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
        JOIN aule_router_destinations d ON d.stop_id = n.stop_id;

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
                'id', md5(signature || ':' || arrival_at::TEXT),
                'departure_at', departure_at,
                'arrival_at', arrival_at,
                'duration_seconds', duration_seconds,
                'score_seconds', score_seconds,
                'transfers', transfers,
                'walk_seconds', walk_seconds,
                'accessible', accessible,
                'alerts', alerts,
                'route_ids', to_jsonb(route_ids),
                'legs', legs
            ) AS payload
        FROM (
            SELECT DISTINCT ON (signature)
                signature, departure_at, arrival_at, duration_seconds,
                score_seconds, transfers, walk_seconds, accessible,
                alerts, route_ids, legs
            FROM aule_router_results
            WHERE duration_seconds > 0
              AND duration_seconds <= EXTRACT(EPOCH FROM v_horizon)::INTEGER
            ORDER BY signature, score_seconds, arrival_at
        ) distinct_paths
        ORDER BY score_seconds, arrival_at
        LIMIT LEAST(GREATEST(COALESCE(p_limit, 4), 1), 6)
    ) limited;

    RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.plan_transit_journeys(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION,
    TIMESTAMPTZ, INTEGER, BOOLEAN, BOOLEAN, INTEGER
) TO service_role;
