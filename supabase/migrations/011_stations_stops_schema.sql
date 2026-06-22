-- Stations / Arrêts — schéma canonique (v3)
-- Séparation stricte : stations (lieu voyageur) vs stops (point physique)

CREATE EXTENSION IF NOT EXISTS unaccent;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE public.stop_source AS ENUM ('gtfs', 'manual', 'temporary', 'works', 'community');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE public.stop_transport_mode AS ENUM ('bus', 'tram', 'train', 'ferry', 'metro');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Réseaux
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.networks (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        TEXT NOT NULL,
    code        TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.networks (id, name, code)
VALUES ('00000000-0000-4000-8000-000000000001', 'Naolib Nantes', 'naolib-nantes')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Normalisation des noms de station
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_station_name(p_name TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN lower(trim(regexp_replace(unaccent(coalesce(p_name, '')), '\s+', ' ', 'g')));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ---------------------------------------------------------------------------
-- Stations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stations (
    id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    network_id        UUID NOT NULL REFERENCES public.networks(id) ON DELETE CASCADE,
    name              TEXT NOT NULL,
    name_normalized   TEXT NOT NULL,
    description       TEXT,
    commune           TEXT,
    latitude_center   DOUBLE PRECISION,
    longitude_center  DOUBLE PRECISION,
    status            TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'works', 'relocated')),
    updated_by        UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (network_id, name_normalized)
);

CREATE INDEX IF NOT EXISTS idx_stations_network ON public.stations(network_id);
CREATE INDEX IF NOT EXISTS idx_stations_status ON public.stations(status);
CREATE INDEX IF NOT EXISTS idx_stations_name_normalized ON public.stations(network_id, name_normalized);

CREATE OR REPLACE FUNCTION public.touch_station_name_normalized()
RETURNS TRIGGER AS $$
BEGIN
    NEW.name_normalized := public.normalize_station_name(NEW.name);
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_stations_normalize ON public.stations;
CREATE TRIGGER on_stations_normalize
    BEFORE INSERT OR UPDATE OF name ON public.stations
    FOR EACH ROW EXECUTE FUNCTION public.touch_station_name_normalized();

-- ---------------------------------------------------------------------------
-- Arrêts (points physiques)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.stops (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    network_id      UUID NOT NULL REFERENCES public.networks(id) ON DELETE CASCADE,
    station_id      UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    code            TEXT NOT NULL,
    source          public.stop_source NOT NULL DEFAULT 'gtfs',
    gtfs_source_id  TEXT,
    name            TEXT,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    geom            GEOMETRY(Point, 4326) NOT NULL,
    platform        TEXT,
    transport_mode  public.stop_transport_mode NOT NULL DEFAULT 'bus',
    is_accessible   BOOLEAN NOT NULL DEFAULT FALSE,
    status          TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'inactive', 'works', 'relocated')),
    address         TEXT,
    tariff_zone     TEXT,
    updated_by      UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (network_id, code)
);

CREATE INDEX IF NOT EXISTS idx_stops_station ON public.stops(station_id);
CREATE INDEX IF NOT EXISTS idx_stops_network ON public.stops(network_id);
CREATE INDEX IF NOT EXISTS idx_stops_geom ON public.stops USING gist(geom);
CREATE INDEX IF NOT EXISTS idx_stops_status ON public.stops(status);
CREATE INDEX IF NOT EXISTS idx_stops_source ON public.stops(source);

CREATE OR REPLACE FUNCTION public.touch_stop_geom()
RETURNS TRIGGER AS $$
BEGIN
    NEW.geom := ST_SetSRID(ST_Point(NEW.longitude, NEW.latitude), 4326);
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_stops_geom ON public.stops;
CREATE TRIGGER on_stops_geom
    BEFORE INSERT OR UPDATE OF latitude, longitude ON public.stops
    FOR EACH ROW EXECUTE FUNCTION public.touch_stop_geom();

-- ---------------------------------------------------------------------------
-- Pont GTFS → stops.id
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.gtfs_stop_mapping (
    network_id    UUID NOT NULL REFERENCES public.networks(id) ON DELETE CASCADE,
    gtfs_stop_id  TEXT NOT NULL,
    stop_id       UUID NOT NULL REFERENCES public.stops(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (network_id, gtfs_stop_id),
    UNIQUE (stop_id)
);

CREATE INDEX IF NOT EXISTS idx_gtfs_stop_mapping_stop ON public.gtfs_stop_mapping(stop_id);

-- ---------------------------------------------------------------------------
-- Audit stations
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.station_audit_log (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    station_id    UUID NOT NULL REFERENCES public.stations(id) ON DELETE CASCADE,
    action        TEXT NOT NULL CHECK (action IN (
        'created', 'updated', 'disabled', 'imported'
    )),
    changes       JSONB NOT NULL DEFAULT '{}',
    performed_by  UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_station_audit_log_station
    ON public.station_audit_log(station_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- Étendre stop_audit_log pour UUID (nouvelle colonne, migration données en 012)
-- ---------------------------------------------------------------------------
ALTER TABLE public.stop_audit_log
    ADD COLUMN IF NOT EXISTS stop_uuid UUID REFERENCES public.stops(id) ON DELETE CASCADE;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.networks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.gtfs_stop_mapping ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.station_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS networks_select_public ON public.networks;
CREATE POLICY networks_select_public ON public.networks FOR SELECT USING (true);

DROP POLICY IF EXISTS stations_select_public ON public.stations;
CREATE POLICY stations_select_public ON public.stations FOR SELECT USING (true);

DROP POLICY IF EXISTS stops_select_public ON public.stops;
CREATE POLICY stops_select_public ON public.stops FOR SELECT USING (true);

DROP POLICY IF EXISTS gtfs_stop_mapping_select_public ON public.gtfs_stop_mapping;
CREATE POLICY gtfs_stop_mapping_select_public ON public.gtfs_stop_mapping FOR SELECT USING (true);

DROP POLICY IF EXISTS stations_manage_staff ON public.stations;
CREATE POLICY stations_manage_staff ON public.stations
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['admin', 'regulator']))
    WITH CHECK (public.has_role(ARRAY['admin', 'regulator']));

DROP POLICY IF EXISTS stops_manage_staff ON public.stops;
CREATE POLICY stops_manage_staff ON public.stops
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['admin', 'regulator']))
    WITH CHECK (public.has_role(ARRAY['admin', 'regulator']));

DROP POLICY IF EXISTS station_audit_log_select_staff ON public.station_audit_log;
CREATE POLICY station_audit_log_select_staff ON public.station_audit_log
    FOR SELECT TO authenticated USING (public.is_staff());

DROP POLICY IF EXISTS station_audit_log_insert_staff ON public.station_audit_log;
CREATE POLICY station_audit_log_insert_staff ON public.station_audit_log
    FOR INSERT TO authenticated
    WITH CHECK (public.has_role(ARRAY['admin', 'regulator']));
