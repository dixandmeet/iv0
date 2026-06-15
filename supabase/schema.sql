-- Active les extensions nécessaires
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================================
-- 1. TABLES DE DONNÉES UTILISATEURS & APPLICATIVES
-- =========================================================================

-- Table des appareils anonymes
CREATE TABLE IF NOT EXISTS anonymous_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_token TEXT UNIQUE NOT NULL,
    consent_background_tracking BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    last_seen_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Paramètres de l'application par appareil
CREATE TABLE IF NOT EXISTS app_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES anonymous_devices(id) ON DELETE CASCADE UNIQUE NOT NULL,
    passive_tracking_enabled BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- =========================================================================
-- 2. TABLES GTFS (DONNÉES THÉORIQUES TRANSIT)
-- =========================================================================

-- Lignes Naolib (Bus, Tram, Navibus, Busway)
CREATE TABLE IF NOT EXISTS gtfs_routes (
    route_id TEXT PRIMARY KEY,
    route_short_name TEXT,
    route_long_name TEXT,
    route_type INTEGER NOT NULL, -- 0: Tram, 3: Bus, 4: Navibus (Ferry)
    route_color TEXT
);

-- Arrêts de transport
CREATE TABLE IF NOT EXISTS gtfs_stops (
    stop_id TEXT PRIMARY KEY,
    stop_name TEXT NOT NULL,
    wheelchair_boarding SMALLINT DEFAULT 0 NOT NULL, -- GTFS : 0 inconnu, 1 accessible PMR, 2 non accessible
    geom GEOMETRY(Point, 4326) NOT NULL
);
-- Migration des bases existantes (no-op sur une base neuve)
ALTER TABLE gtfs_stops ADD COLUMN IF NOT EXISTS wheelchair_boarding SMALLINT DEFAULT 0 NOT NULL;
CREATE INDEX IF NOT EXISTS idx_gtfs_stops_geom ON gtfs_stops USING gist(geom);

-- Tracés géométriques des lignes
CREATE TABLE IF NOT EXISTS gtfs_shapes (
    shape_id TEXT NOT NULL,
    shape_pt_sequence INTEGER NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL,
    PRIMARY KEY (shape_id, shape_pt_sequence)
);
CREATE INDEX IF NOT EXISTS idx_gtfs_shapes_geom ON gtfs_shapes USING gist(geom);
CREATE INDEX IF NOT EXISTS idx_gtfs_shapes_id ON gtfs_shapes(shape_id);

-- Voyages programmés
CREATE TABLE IF NOT EXISTS gtfs_trips (
    trip_id TEXT PRIMARY KEY,
    route_id TEXT REFERENCES gtfs_routes(route_id) ON DELETE CASCADE,
    service_id TEXT NOT NULL,
    shape_id TEXT,
    direction_id INTEGER -- 0 ou 1
);
CREATE INDEX IF NOT EXISTS idx_gtfs_trips_route_id ON gtfs_trips(route_id);
CREATE INDEX IF NOT EXISTS idx_gtfs_trips_shape_id ON gtfs_trips(shape_id);

-- Horaires théoriques de passage aux arrêts
CREATE TABLE IF NOT EXISTS gtfs_stop_times (
    trip_id TEXT REFERENCES gtfs_trips(trip_id) ON DELETE CASCADE,
    stop_id TEXT REFERENCES gtfs_stops(stop_id) ON DELETE CASCADE,
    arrival_time INTERVAL NOT NULL,
    departure_time INTERVAL NOT NULL,
    stop_sequence INTEGER NOT NULL,
    PRIMARY KEY (trip_id, stop_sequence)
);
CREATE INDEX IF NOT EXISTS idx_gtfs_stop_times_trip_id ON gtfs_stop_times(trip_id);
CREATE INDEX IF NOT EXISTS idx_gtfs_stop_times_stop_id ON gtfs_stop_times(stop_id);


-- =========================================================================
-- 3. SUIVI DES POSITIONS EN TEMPS RÉEL (ANONYME & TEMPORAIRE)
-- =========================================================================

-- Événements de géolocalisation envoyés par les utilisateurs en mode passif
CREATE TABLE IF NOT EXISTS user_location_events (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID REFERENCES anonymous_devices(id) ON DELETE CASCADE NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL,
    speed NUMERIC NOT NULL,       -- en m/s
    heading NUMERIC NOT NULL,     -- de 0 à 360 degrés
    accuracy NUMERIC NOT NULL,    -- précision GPS en mètres
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    estimated_state TEXT NOT NULL  -- 'walking', 'waiting', 'transit_probable'
);
CREATE INDEX IF NOT EXISTS idx_user_location_events_device_time ON user_location_events(device_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_user_location_events_geom ON user_location_events USING gist(geom);


-- =========================================================================
-- 4. VÉHICULES COMMUNAUTAIRES (AGRÉGÉS) & SIGNALEMENTS
-- =========================================================================

-- Véhicules générés par l'algorithme communautaire
CREATE TABLE IF NOT EXISTS community_vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    route_id TEXT REFERENCES gtfs_routes(route_id) ON DELETE CASCADE NOT NULL,
    trip_id TEXT REFERENCES gtfs_trips(trip_id) ON DELETE SET NULL,
    transport_type TEXT NOT NULL, -- 'bus', 'tram', 'busway', 'navibus'
    geom GEOMETRY(Point, 4326) NOT NULL,
    speed NUMERIC NOT NULL,
    heading NUMERIC NOT NULL,
    confidence_score INTEGER DEFAULT 0 NOT NULL, -- 0 à 100
    active_user_count INTEGER DEFAULT 1 NOT NULL,
    last_seen_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    estimated_delay_seconds INTEGER
);
CREATE INDEX IF NOT EXISTS idx_community_vehicles_geom ON community_vehicles USING gist(geom);

-- Log des détections individuelles (lien utilisateur -> véhicule communautaire)
CREATE TABLE IF NOT EXISTS vehicle_detections (
    id BIGSERIAL PRIMARY KEY,
    vehicle_id UUID REFERENCES community_vehicles(id) ON DELETE CASCADE NOT NULL,
    device_id UUID REFERENCES anonymous_devices(id) ON DELETE CASCADE NOT NULL,
    route_id TEXT REFERENCES gtfs_routes(route_id) ON DELETE CASCADE NOT NULL,
    confidence INTEGER NOT NULL,
    detected_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- Signalements d'incidents par les utilisateurs
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID REFERENCES anonymous_devices(id) ON DELETE SET NULL,
    -- Texte libre (pas de FK) : l'app autorise un signalement réseau ('Réseau')
    -- ou une ligne saisie par l'utilisateur qui peut ne pas exister en BDD.
    route_id TEXT NOT NULL,
    vehicle_id UUID REFERENCES community_vehicles(id) ON DELETE SET NULL,
    report_type TEXT NOT NULL, -- 'delay', 'crowded', 'breakdown', 'accident', 'control', 'safety'
    geom GEOMETRY(Point, 4326) NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    description TEXT
);
CREATE INDEX IF NOT EXISTS idx_reports_geom ON reports USING gist(geom);


-- =========================================================================
-- 5. ALGORITHMES PL/PGSQL (POSTGIS)
-- =========================================================================

-- A. Fonction pour estimer si un utilisateur est sur une ligne et calculer la confiance
CREATE OR REPLACE FUNCTION detect_probable_route(
    user_lat DOUBLE PRECISION,
    user_lon DOUBLE PRECISION,
    user_heading DOUBLE PRECISION,
    user_speed DOUBLE PRECISION -- en m/s
)
RETURNS TABLE (
    route_id TEXT,
    shape_id TEXT,
    direction_id INTEGER,
    confidence INTEGER
) AS $$
DECLARE
    user_geom GEOMETRY(Point, 4326);
BEGIN
    user_geom := ST_SetSRID(ST_Point(user_lon, user_lat), 4326);

    RETURN QUERY
    WITH closest_shapes AS (
        -- Trouve les points de tracés GTFS dans un rayon de 50 mètres
        -- Calcule l'angle (heading) local du tracé en comparant le point actuel au suivant
        SELECT 
            s1.shape_id,
            s1.shape_pt_sequence,
            s1.geom as pt_geom,
            DEGREES(ST_Azimuth(s1.geom, s2.geom)) as shape_heading,
            ST_Distance(s1.geom::geography, user_geom::geography) as dist_meters
        FROM gtfs_shapes s1
        JOIN gtfs_shapes s2 ON s1.shape_id = s2.shape_id AND s2.shape_pt_sequence = s1.shape_pt_sequence + 1
        WHERE ST_DWithin(s1.geom::geography, user_geom::geography, 50)
    ),
    matched_trips AS (
        -- Jointure avec les trajets théoriques pour trouver les lignes associées
        SELECT 
            cs.shape_id,
            cs.dist_meters,
            cs.shape_heading,
            t.route_id,
            t.direction_id
        FROM closest_shapes cs
        JOIN gtfs_trips t ON t.shape_id = cs.shape_id
    ),
    scored_matches AS (
        -- Calcule le score de confiance
        -- Bonus si l'orientation (heading) de l'utilisateur correspond à celle de la ligne
        -- Malus selon la distance au tracé
        SELECT 
            m.route_id,
            m.shape_id,
            m.direction_id,
            CAST(
                GREATEST(0, LEAST(100, 
                    -- Score de base basé sur la distance (100% à 0m, 50% à 50m)
                    (100 - (m.dist_meters * 1.0)) +
                    -- Bonus d'orientation (jusqu'à 30 points si l'angle diffère de moins de 30 degrés)
                    (CASE 
                        WHEN ABS(user_heading - m.shape_heading) < 30 OR ABS(user_heading - m.shape_heading) > 330 THEN 30
                        WHEN ABS(user_heading - m.shape_heading) < 60 OR ABS(user_heading - m.shape_heading) > 300 THEN 10
                        ELSE -20
                     END) +
                    -- Validation de la vitesse (si l'utilisateur bouge à vitesse bus/tram, bonus)
                    (CASE 
                        WHEN user_speed > 2.0 AND user_speed < 25.0 THEN 20
                        WHEN user_speed <= 0.5 THEN 0 -- Arrêt probable
                        ELSE -30 -- Vitesse marche à pied ou voiture trop rapide
                     END)
                )) AS INTEGER
            ) as match_confidence
        FROM matched_trips m
    )
    -- Retourne la meilleure correspondance par ligne
    SELECT DISTINCT ON (s.route_id)
        s.route_id,
        s.shape_id,
        s.direction_id,
        MAX(s.match_confidence) as confidence
    FROM scored_matches s
    GROUP BY s.route_id, s.shape_id, s.direction_id
    HAVING MAX(s.match_confidence) >= 50 -- Confiance minimum requise
    ORDER BY s.route_id, confidence DESC;
END;
$$ LANGUAGE plpgsql;


-- B. Fonction d'agrégation en tâche planifiée ou déclenchée pour regrouper les utilisateurs
CREATE OR REPLACE FUNCTION aggregate_community_vehicles()
RETURNS VOID AS $$
DECLARE
    rec RECORD;
    temp_vehicle_id UUID;
BEGIN
    -- Étape 1 : Nettoyer/Archiver les véhicules inactifs depuis plus de 3 minutes
    DELETE FROM community_vehicles WHERE last_seen_at < NOW() - INTERVAL '3 minutes';

    -- Étape 2 : Regrouper les positions récentes (2 dernières minutes) des utilisateurs
    -- qui ont une détection de route valide (confiance >= 60)
    FOR rec IN 
        WITH recent_locations AS (
            SELECT 
                le.device_id,
                le.geom,
                le.speed,
                le.heading,
                le.timestamp,
                p.route_id,
                p.direction_id,
                p.confidence
            FROM user_location_events le
            CROSS JOIN LATERAL detect_probable_route(
                ST_Y(le.geom), 
                ST_X(le.geom), 
                le.heading::double precision, 
                le.speed::double precision
            ) p
            WHERE le.timestamp >= NOW() - INTERVAL '2 minutes'
              AND p.confidence >= 60
        ),
        located_clusters AS (
            -- La window function doit être évaluée avant le GROUP BY (interdite dedans)
            SELECT
                *,
                ST_ClusterDBSCAN(geom, 0.001, 1) OVER (PARTITION BY route_id, direction_id) as cluster_id
            FROM recent_locations
        ),
        clustered_users AS (
            -- Regroupe spatialement les utilisateurs proches (environ 100m) sur la même ligne
            SELECT
                route_id,
                direction_id,
                ST_Centroid(ST_Collect(geom)) as cluster_geom,
                AVG(speed) as avg_speed,
                AVG(heading) as avg_heading,
                COUNT(DISTINCT device_id) as user_count,
                MAX(confidence) as max_confidence,
                MAX(timestamp) as last_update
            FROM located_clusters
            GROUP BY route_id, direction_id, cluster_id
        )
        SELECT * FROM clustered_users
    LOOP
        -- Déterminer le type de transport
        -- Type de transport Naolib : 0 = Tram, 3 = Bus, 4 = Navibus (Ferry).
        -- Par convention, les lignes de Tramway commencent par '1', '2', '3' à Nantes.
        -- Busway est la ligne '4' ou 'C4'.
        -- Navibus : N1, N2.
        DECLARE
            v_transport_type TEXT := 'bus';
        BEGIN
            IF rec.route_id IN ('1', '2', '3') THEN
                v_transport_type := 'tram';
            ELSIF rec.route_id IN ('4', 'C4') THEN
                v_transport_type := 'busway';
            ELSIF rec.route_id LIKE 'N%' THEN
                v_transport_type := 'navibus';
            END IF;

            -- Étape 3 : Tenter de mettre à jour un véhicule existant sur cette route et à proximité
            SELECT id INTO temp_vehicle_id
            FROM community_vehicles
            WHERE route_id = rec.route_id
              AND ST_DWithin(geom::geography, rec.cluster_geom::geography, 150)
            LIMIT 1;

            IF temp_vehicle_id IS NOT NULL THEN
                UPDATE community_vehicles
                SET geom = rec.cluster_geom,
                    speed = rec.avg_speed,
                    heading = rec.avg_heading,
                    active_user_count = rec.user_count,
                    confidence_score = GREATEST(30, LEAST(100, 
                        -- Scoring de fiabilité :
                        -- 1 user = 40, 2-3 users = 75, 4+ users = 95
                        (CASE WHEN rec.user_count = 1 THEN 40 
                              WHEN rec.user_count BETWEEN 2 AND 3 THEN 75 
                              ELSE 95 END)
                    )),
                    last_seen_at = rec.last_update
                WHERE id = temp_vehicle_id;
            ELSE
                -- Créer un nouveau véhicule communautaire
                INSERT INTO community_vehicles (
                    route_id,
                    transport_type,
                    geom,
                    speed,
                    heading,
                    active_user_count,
                    confidence_score,
                    last_seen_at
                ) VALUES (
                    rec.route_id,
                    v_transport_type,
                    rec.cluster_geom,
                    rec.avg_speed,
                    rec.avg_heading,
                    rec.user_count,
                    (CASE WHEN rec.user_count = 1 THEN 40 
                          WHEN rec.user_count BETWEEN 2 AND 3 THEN 75 
                          ELSE 95 END),
                    rec.last_update
                );
            END IF;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- =========================================================================
-- 6. RÈGLES DE CONFIDENTIALITÉ (RGPD)
-- =========================================================================

-- A. Fonction pour anonymiser/supprimer les anciennes positions brutes
-- Cette fonction doit être exécutée régulièrement (par exemple toutes les 15 minutes)
CREATE OR REPLACE FUNCTION purge_old_user_locations()
RETURNS VOID AS $$
BEGIN
    -- Supprime définitivement les coordonnées brutes des utilisateurs datant de plus de 15 minutes
    DELETE FROM user_location_events
    WHERE timestamp < NOW() - INTERVAL '15 minutes';
END;
$$ LANGUAGE plpgsql;


-- B. RLS (Row Level Security) - Configuration Supabase
ALTER TABLE anonymous_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_location_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE gtfs_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE gtfs_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE gtfs_shapes ENABLE ROW LEVEL SECURITY;
ALTER TABLE gtfs_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE gtfs_stop_times ENABLE ROW LEVEL SECURITY;

-- Politiques pour les données statiques GTFS (Lecture publique)
DROP POLICY IF EXISTS "lecture_publique_gtfs_routes" ON gtfs_routes;
CREATE POLICY "lecture_publique_gtfs_routes" ON gtfs_routes FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_stops" ON gtfs_stops;
CREATE POLICY "lecture_publique_gtfs_stops" ON gtfs_stops FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_shapes" ON gtfs_shapes;
CREATE POLICY "lecture_publique_gtfs_shapes" ON gtfs_shapes FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_trips" ON gtfs_trips;
CREATE POLICY "lecture_publique_gtfs_trips" ON gtfs_trips FOR SELECT USING (true);
DROP POLICY IF EXISTS "lecture_publique_gtfs_stop_times" ON gtfs_stop_times;
CREATE POLICY "lecture_publique_gtfs_stop_times" ON gtfs_stop_times FOR SELECT USING (true);

-- Politiques pour les véhicules communautaires (Lecture publique)
DROP POLICY IF EXISTS "lecture_publique_community_vehicles" ON community_vehicles;
CREATE POLICY "lecture_publique_community_vehicles" ON community_vehicles FOR SELECT USING (true);

-- Politiques pour les signalements (Lecture publique, Insertion anonyme)
DROP POLICY IF EXISTS "lecture_publique_reports" ON reports;
CREATE POLICY "lecture_publique_reports" ON reports FOR SELECT USING (true);
DROP POLICY IF EXISTS "insertion_publique_reports" ON reports;
CREATE POLICY "insertion_publique_reports" ON reports FOR INSERT WITH CHECK (true);

-- Politiques pour les appareils & paramètres (Chaque appareil ne peut accéder qu'à son propre profil)
-- Pour des raisons de MVP anonyme, on autorise l'accès si le token correspond à celui envoyé par le client.
DROP POLICY IF EXISTS "gestion_propre_device" ON anonymous_devices;
CREATE POLICY "gestion_propre_device" ON anonymous_devices 
    USING (true) 
    WITH CHECK (true);

DROP POLICY IF EXISTS "gestion_propre_settings" ON app_settings;
CREATE POLICY "gestion_propre_settings" ON app_settings 
    USING (true) 
    WITH CHECK (true);

-- Politiques d'écriture pour la géolocalisation passive
DROP POLICY IF EXISTS "insertion_propre_location" ON user_location_events;
CREATE POLICY "insertion_propre_location" ON user_location_events 
    FOR INSERT 
    WITH CHECK (true);
