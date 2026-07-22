-- Grille horaire théorique complète (GTFS Semitan) + positions interpolées.
--
-- Contexte : `gtfs_stop_times` (migration 030) ne contient qu'UNE course
-- représentative par journey pattern (334 courses). Une seule course est en
-- cours à 11h, aucune à 22h : impossible d'en tirer un radar. Le GTFS source
-- couvre la vraie grille (114 483 courses, 2,75 M stop_times) — trop volumineux
-- pour être importé tel quel.
--
-- Compression : les courses d'un même pattern réutilisent un petit nombre de
-- profils de temps relatifs (5 688 profils pour 114 483 courses). On stocke donc
-- le profil une fois (arrêts + offsets depuis le départ) et, par course, sa seule
-- heure de départ. 2,75 M lignes -> ~293 k, sans perte des fréquences réelles.
--
-- `gtfs_stop_times` et `gtfs_trips` restent inchangés : ils servent au plan de
-- ligne (SAE `fetchJourney`) et à la couverture arrêt<->ligne du dashboard.
--
-- Les données sont chargées par tool/build_theoretical_timetable.py (COPY).
-- ---------------------------------------------------------------------------

-- Calendrier GTFS : quels services circulent quel jour.
CREATE TABLE IF NOT EXISTS public.gtfs_calendar (
    service_id TEXT PRIMARY KEY,
    -- Index 1..7 = lundi..dimanche (ISODOW), pour indexer directement par
    -- EXTRACT(ISODOW FROM date) sans sept colonnes ni CASE.
    runs_on BOOLEAN[] NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    CONSTRAINT gtfs_calendar_runs_on_len CHECK (array_length(runs_on, 1) = 7)
);

-- Exceptions : 1 = service ajouté ce jour-là, 2 = service supprimé.
CREATE TABLE IF NOT EXISTS public.gtfs_calendar_dates (
    service_id TEXT NOT NULL,
    service_date DATE NOT NULL,
    exception_type SMALLINT NOT NULL CHECK (exception_type IN (1, 2)),
    PRIMARY KEY (service_id, service_date)
);

-- Tracé d'un pattern, pré-assemblé en LINESTRING : la RPC interpole dessus sans
-- avoir à reconstruire la géométrie depuis gtfs_shapes à chaque appel.
CREATE TABLE IF NOT EXISTS public.gtfs_pattern_shapes (
    pattern_shape_id TEXT PRIMARY KEY,
    geom GEOMETRY(LineString, 4326) NOT NULL
);

-- Profil de circulation : itinéraire + temps relatifs, partagé par N courses.
CREATE TABLE IF NOT EXISTS public.gtfs_trip_profiles (
    profile_id TEXT PRIMARY KEY,
    route_id TEXT NOT NULL REFERENCES public.gtfs_routes(route_id) ON DELETE CASCADE,
    direction_id SMALLINT,
    pattern_shape_id TEXT REFERENCES public.gtfs_pattern_shapes(pattern_shape_id) ON DELETE SET NULL,
    headsign TEXT,
    duration_seconds INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_gtfs_trip_profiles_route ON public.gtfs_trip_profiles(route_id);

-- Arrêts du profil. `offset_seconds` = temps depuis le départ de la course ;
-- `shape_fraction` = position de l'arrêt sur le tracé (0..1), projetée à
-- l'import (shape_dist_traveled du GTFS source est factice : incréments
-- parfaitement réguliers, il ne mesure aucune distance réelle).
CREATE TABLE IF NOT EXISTS public.gtfs_trip_profile_stops (
    profile_id TEXT NOT NULL REFERENCES public.gtfs_trip_profiles(profile_id) ON DELETE CASCADE,
    stop_sequence SMALLINT NOT NULL,
    stop_id TEXT NOT NULL REFERENCES public.gtfs_stops(stop_id) ON DELETE CASCADE,
    offset_seconds INTEGER NOT NULL,
    shape_fraction DOUBLE PRECISION NOT NULL,
    PRIMARY KEY (profile_id, stop_sequence)
);
CREATE INDEX IF NOT EXISTS idx_gtfs_profile_stops_offset
    ON public.gtfs_trip_profile_stops(profile_id, offset_seconds);

-- Une course = un profil + une heure de départ (secondes depuis minuit ; peut
-- dépasser 86400 pour les courses de nuit, comme le GTFS).
CREATE TABLE IF NOT EXISTS public.gtfs_trip_departures (
    departure_id TEXT PRIMARY KEY,
    profile_id TEXT NOT NULL REFERENCES public.gtfs_trip_profiles(profile_id) ON DELETE CASCADE,
    service_id TEXT NOT NULL,
    start_seconds INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_gtfs_departures_service_start
    ON public.gtfs_trip_departures(service_id, start_seconds);

-- Lecture publique : ce sont des horaires publics, comme le reste du GTFS.
ALTER TABLE public.gtfs_calendar ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtfs_calendar_dates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtfs_pattern_shapes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtfs_trip_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtfs_trip_profile_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtfs_trip_departures ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "lecture_publique_gtfs_calendar" ON public.gtfs_calendar;
CREATE POLICY "lecture_publique_gtfs_calendar" ON public.gtfs_calendar FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_calendar_dates" ON public.gtfs_calendar_dates;
CREATE POLICY "lecture_publique_gtfs_calendar_dates" ON public.gtfs_calendar_dates FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_pattern_shapes" ON public.gtfs_pattern_shapes;
CREATE POLICY "lecture_publique_gtfs_pattern_shapes" ON public.gtfs_pattern_shapes FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_trip_profiles" ON public.gtfs_trip_profiles;
CREATE POLICY "lecture_publique_gtfs_trip_profiles" ON public.gtfs_trip_profiles FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_trip_profile_stops" ON public.gtfs_trip_profile_stops;
CREATE POLICY "lecture_publique_gtfs_trip_profile_stops" ON public.gtfs_trip_profile_stops FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_trip_departures" ON public.gtfs_trip_departures;
CREATE POLICY "lecture_publique_gtfs_trip_departures" ON public.gtfs_trip_departures FOR SELECT USING (true);

-- ---------------------------------------------------------------------------
-- Positions théoriques à l'instant T, autour d'un point.
--
-- Même forme de résultat que `immersive_fleet_positions` (migration 062), plus
-- le prochain arrêt et son ETA. Le radar fusionne les deux sources : une course
-- réellement suivie par un conducteur Aule prime sur sa jumelle théorique.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.theoretical_fleet_positions(
    p_lat DOUBLE PRECISION,
    p_lon DOUBLE PRECISION,
    p_radius_m DOUBLE PRECISION DEFAULT 2000,
    p_limit INTEGER DEFAULT 60
)
RETURNS TABLE (
    public_id TEXT,
    vehicle_type TEXT,
    route_id TEXT,
    destination TEXT,
    next_stop TEXT,
    eta_seconds INTEGER,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    distance_m DOUBLE PRECISION
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH params AS (
        SELECT
            ST_SetSRID(ST_Point(p_lon, p_lat), 4326) AS origin,
            GREATEST(50, LEAST(COALESCE(p_radius_m, 2000), 20000)) AS radius,
            -- Le GTFS raisonne en heure locale du réseau.
            (NOW() AT TIME ZONE 'Europe/Paris') AS local_now
    ),
    -- Une course qui part à 25:10 appartient au service de la veille : les deux
    -- jours de service sont donc candidats.
    service_days AS (
        SELECT
            d::DATE AS service_date,
            EXTRACT(EPOCH FROM (p.local_now - d::TIMESTAMP))::INTEGER AS day_seconds
        FROM params p,
             LATERAL (VALUES (p.local_now::DATE), (p.local_now::DATE - 1)) AS v(d)
    ),
    active_services AS (
        SELECT sd.service_date, sd.day_seconds, c.service_id
        FROM service_days sd
        JOIN gtfs_calendar c
          ON sd.service_date BETWEEN c.start_date AND c.end_date
         AND c.runs_on[EXTRACT(ISODOW FROM sd.service_date)::INTEGER]
        WHERE NOT EXISTS (
            SELECT 1 FROM gtfs_calendar_dates cd
            WHERE cd.service_id = c.service_id
              AND cd.service_date = sd.service_date
              AND cd.exception_type = 2
        )
        UNION
        SELECT sd.service_date, sd.day_seconds, cd.service_id
        FROM service_days sd
        JOIN gtfs_calendar_dates cd
          ON cd.service_date = sd.service_date AND cd.exception_type = 1
    ),
    -- La borne à 2 h permet d'attaquer l'index (service_id, start_seconds) ;
    -- la course la plus longue du réseau dure 60 min.
    running AS (
        SELECT
            d.departure_id,
            d.profile_id,
            s.day_seconds - d.start_seconds AS elapsed,
            pr.route_id,
            pr.headsign,
            pr.pattern_shape_id
        FROM active_services s
        JOIN gtfs_trip_departures d
          ON d.service_id = s.service_id
         AND d.start_seconds BETWEEN s.day_seconds - 7200 AND s.day_seconds
        JOIN gtfs_trip_profiles pr ON pr.profile_id = d.profile_id
        WHERE s.day_seconds <= d.start_seconds + pr.duration_seconds
    ),
    located AS (
        SELECT
            r.*,
            prev.offset_seconds AS prev_offset,
            prev.shape_fraction AS prev_fraction,
            nxt.offset_seconds AS next_offset,
            nxt.shape_fraction AS next_fraction,
            nxt.stop_id AS next_stop_id
        FROM running r
        JOIN LATERAL (
            SELECT ps.offset_seconds, ps.shape_fraction
            FROM gtfs_trip_profile_stops ps
            WHERE ps.profile_id = r.profile_id AND ps.offset_seconds <= r.elapsed
            ORDER BY ps.offset_seconds DESC
            LIMIT 1
        ) prev ON TRUE
        LEFT JOIN LATERAL (
            SELECT ps.offset_seconds, ps.shape_fraction, ps.stop_id
            FROM gtfs_trip_profile_stops ps
            WHERE ps.profile_id = r.profile_id AND ps.offset_seconds > r.elapsed
            ORDER BY ps.offset_seconds ASC
            LIMIT 1
        ) nxt ON TRUE
    ),
    -- Progression linéaire entre les deux arrêts encadrants. Au terminus
    -- (next_* NULL) le véhicule reste sur le dernier arrêt.
    fractions AS (
        SELECT
            l.*,
            CASE
                WHEN l.next_offset IS NULL OR l.next_offset <= l.prev_offset
                    THEN l.prev_fraction
                ELSE l.prev_fraction
                     + (l.next_fraction - l.prev_fraction)
                     * ((l.elapsed - l.prev_offset)::DOUBLE PRECISION
                        / (l.next_offset - l.prev_offset))
            END AS fraction
        FROM located l
    ),
    placed AS (
        SELECT
            f.*,
            ST_LineInterpolatePoint(sh.geom, LEAST(GREATEST(f.fraction, 0), 1)) AS geom,
            -- Un point légèrement en aval donne le cap ; au terminus on recule
            -- pour garder l'orientation de la fin de course.
            ST_LineInterpolatePoint(sh.geom, LEAST(GREATEST(f.fraction, 0) + 0.004, 1)) AS ahead_geom
        FROM fractions f
        JOIN gtfs_pattern_shapes sh ON sh.pattern_shape_id = f.pattern_shape_id
    )
    SELECT
        'th-' || p.departure_id AS public_id,
        CASE
            WHEN gr.route_type IN (0, 1, 2) THEN 'tram'
            WHEN gr.route_type = 4 THEN 'navibus'
            ELSE 'bus'
        END AS vehicle_type,
        p.route_id,
        p.headsign AS destination,
        st.stop_name AS next_stop,
        GREATEST(0, p.next_offset - p.elapsed) AS eta_seconds,
        ST_Y(p.geom) AS latitude,
        ST_X(p.geom) AS longitude,
        CASE
            WHEN ST_Equals(p.geom, p.ahead_geom) THEN NULL
            ELSE DEGREES(ST_Azimuth(p.geom, p.ahead_geom))
        END AS heading,
        ST_Distance(p.geom::GEOGRAPHY, prm.origin::GEOGRAPHY) AS distance_m
    FROM placed p
    CROSS JOIN params prm
    LEFT JOIN gtfs_routes gr ON gr.route_id = p.route_id
    LEFT JOIN gtfs_stops st ON st.stop_id = p.next_stop_id
    WHERE ST_DWithin(p.geom::GEOGRAPHY, prm.origin::GEOGRAPHY, prm.radius)
    ORDER BY distance_m
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 60), 200));
$$;

REVOKE ALL ON FUNCTION public.theoretical_fleet_positions(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.theoretical_fleet_positions(
    DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, INTEGER
) TO anon, authenticated;
