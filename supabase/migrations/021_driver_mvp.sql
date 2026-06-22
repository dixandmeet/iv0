-- Phase MVP conducteur (app mobile) — flux manuel
-- ---------------------------------------------------------------------------
-- Modèle autonome : fiche conducteur (drivers, rôle détecté par e-mail),
-- prise de service manuelle (driver_services), remontée GPS (vehicle_positions),
-- signalements terrain (driver_reports) et messagerie régulateur (driver_messages).
--
-- Écart assumé vs le cahier des charges : line_id / direction_id / vehicle_id
-- sont stockés en TEXT/INTEGER et non en UUID, afin d'interopérer directement
-- avec les identifiants GTFS (route_id TEXT, direction_id 0/1) et un numéro de
-- véhicule libre, sans table « lines » / « vehicles » dédiée (hors périmètre MVP).
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- drivers — fiche conducteur (source de vérité du rôle conducteur)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.drivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    email TEXT NOT NULL UNIQUE,
    first_name TEXT,
    last_name TEXT,
    phone TEXT,
    driver_number TEXT,
    depot_id UUID REFERENCES public.depots(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'off'
        CHECK (status IN ('off', 'available', 'on_service', 'paused')),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_drivers_email ON public.drivers(lower(email));
CREATE INDEX IF NOT EXISTS idx_drivers_user ON public.drivers(user_id);

-- ===========================================================================
-- driver_services — prise de service (planifiée puis réalisée)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.driver_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    vehicle_id TEXT,
    line_id TEXT,
    direction_id INTEGER,
    headsign TEXT,
    start_time_planned TIMESTAMPTZ,
    end_time_planned TIMESTAMPTZ,
    start_time_real TIMESTAMPTZ,
    end_time_real TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'planned'
        CHECK (status IN ('planned', 'active', 'paused', 'completed', 'cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_driver_services_driver
    ON public.driver_services(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_services_active
    ON public.driver_services(status) WHERE status IN ('active', 'paused');

-- ===========================================================================
-- vehicle_positions — remontée GPS pendant un service actif
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.vehicle_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_service_id UUID REFERENCES public.driver_services(id) ON DELETE CASCADE,
    vehicle_id TEXT,
    driver_id UUID REFERENCES public.drivers(id) ON DELETE CASCADE,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    speed DOUBLE PRECISION,
    heading DOUBLE PRECISION,
    accuracy DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_vehicle_positions_service
    ON public.vehicle_positions(driver_service_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_vehicle_positions_driver_time
    ON public.vehicle_positions(driver_id, created_at DESC);

-- ===========================================================================
-- driver_reports — signalements terrain
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.driver_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    driver_service_id UUID REFERENCES public.driver_services(id) ON DELETE SET NULL,
    vehicle_id TEXT,
    type TEXT NOT NULL
        CHECK (type IN ('delay', 'crowded', 'breakdown', 'accident',
            'traffic', 'detour', 'passenger_illness', 'stop_skipped',
            'incivility', 'other')),
    urgency TEXT NOT NULL DEFAULT 'medium'
        CHECK (urgency IN ('low', 'medium', 'high')),
    message TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    photo_url TEXT,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'acknowledged', 'resolved')),
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_driver_reports_driver
    ON public.driver_reports(driver_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_reports_status
    ON public.driver_reports(status, created_at DESC);

-- ===========================================================================
-- driver_messages — messagerie régulateur ↔ conducteur
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.driver_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    driver_id UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    sender_type TEXT NOT NULL DEFAULT 'regulator'
        CHECK (sender_type IN ('driver', 'regulator')),
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_driver_messages_driver
    ON public.driver_messages(driver_id, created_at DESC);

-- ===========================================================================
-- Helper : id de la fiche conducteur de l'utilisateur courant
-- (par user_id si lié, sinon par e-mail du JWT)
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.current_driver_id()
RETURNS UUID AS $$
    SELECT d.id
    FROM public.drivers d
    WHERE d.user_id = auth.uid()
       OR lower(d.email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
    LIMIT 1;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.current_driver_id() TO authenticated;

-- ===========================================================================
-- RLS
-- ===========================================================================
ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_messages ENABLE ROW LEVEL SECURITY;

-- drivers : le conducteur lit/maj sa fiche ; le staff gère tout
DROP POLICY IF EXISTS drivers_select_self ON public.drivers;
CREATE POLICY drivers_select_self ON public.drivers
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR lower(email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
        OR public.is_staff()
    );

DROP POLICY IF EXISTS drivers_update_self ON public.drivers;
CREATE POLICY drivers_update_self ON public.drivers
    FOR UPDATE TO authenticated
    USING (id = public.current_driver_id() OR public.is_staff())
    WITH CHECK (id = public.current_driver_id() OR public.is_staff());

DROP POLICY IF EXISTS drivers_staff_write ON public.drivers;
CREATE POLICY drivers_staff_write ON public.drivers
    FOR ALL TO authenticated
    USING (public.is_staff())
    WITH CHECK (public.is_staff());

-- driver_services : le conducteur gère ses services ; le staff voit tout
DROP POLICY IF EXISTS driver_services_owner ON public.driver_services;
CREATE POLICY driver_services_owner ON public.driver_services
    FOR ALL TO authenticated
    USING (driver_id = public.current_driver_id() OR public.is_staff())
    WITH CHECK (driver_id = public.current_driver_id() OR public.is_staff());

-- vehicle_positions : insertion par le conducteur pour ses services ;
-- lecture par le staff (suivi flotte) et le conducteur (ses points)
DROP POLICY IF EXISTS vehicle_positions_insert_own ON public.vehicle_positions;
CREATE POLICY vehicle_positions_insert_own ON public.vehicle_positions
    FOR INSERT TO authenticated
    WITH CHECK (driver_id = public.current_driver_id());

DROP POLICY IF EXISTS vehicle_positions_select ON public.vehicle_positions;
CREATE POLICY vehicle_positions_select ON public.vehicle_positions
    FOR SELECT TO authenticated
    USING (driver_id = public.current_driver_id() OR public.is_staff());

-- driver_reports : le conducteur crée/lit ses signalements ; le staff gère
DROP POLICY IF EXISTS driver_reports_owner ON public.driver_reports;
CREATE POLICY driver_reports_owner ON public.driver_reports
    FOR ALL TO authenticated
    USING (driver_id = public.current_driver_id() OR public.is_staff())
    WITH CHECK (driver_id = public.current_driver_id() OR public.is_staff());

-- driver_messages : le conducteur lit ses messages, répond (sender_type='driver')
-- et marque comme lus ; le régulateur (staff) envoie et lit tout
DROP POLICY IF EXISTS driver_messages_select ON public.driver_messages;
CREATE POLICY driver_messages_select ON public.driver_messages
    FOR SELECT TO authenticated
    USING (driver_id = public.current_driver_id() OR public.is_staff());

DROP POLICY IF EXISTS driver_messages_driver_reply ON public.driver_messages;
CREATE POLICY driver_messages_driver_reply ON public.driver_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        (driver_id = public.current_driver_id() AND sender_type = 'driver')
        OR public.is_staff()
    );

DROP POLICY IF EXISTS driver_messages_mark_read ON public.driver_messages;
CREATE POLICY driver_messages_mark_read ON public.driver_messages
    FOR UPDATE TO authenticated
    USING (driver_id = public.current_driver_id() OR public.is_staff())
    WITH CHECK (driver_id = public.current_driver_id() OR public.is_staff());

DROP POLICY IF EXISTS driver_messages_staff_all ON public.driver_messages;
CREATE POLICY driver_messages_staff_all ON public.driver_messages
    FOR ALL TO authenticated
    USING (public.is_staff())
    WITH CHECK (public.is_staff());
