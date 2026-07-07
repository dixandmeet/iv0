-- Roulements / services conducteurs (import des 5 PDF dépôt × période)
-- ---------------------------------------------------------------------------
-- Référence en lecture seule pour la prise de service. Le conducteur saisit sa
-- ligne + son n° de train ; ce couple correspond au champ « first_vehicle »
-- formaté « ligne - train » (ex. « 1 - 31 » = ligne 1, tram 31). L'app propose
-- alors les services qui DÉMARRENT sur ce véhicule, le conducteur choisit le
-- sien (début → fin). Périodes = edition : VERT / BLEU / HIVER.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.service_sources (
    source_key TEXT PRIMARY KEY,
    source_file TEXT NOT NULL,
    depot_code TEXT NOT NULL,
    depot_name TEXT,
    edition TEXT
);

CREATE TABLE IF NOT EXISTS public.transport_services (
    service_key TEXT PRIMARY KEY,
    source_key TEXT REFERENCES public.service_sources(source_key) ON DELETE CASCADE,
    source_page INT,
    rlt_code TEXT,
    service_no TEXT,
    depot_code TEXT NOT NULL,
    depot_name TEXT,
    edition TEXT,            -- période : VERT / BLEU / HIVER
    page_label TEXT,
    source_file TEXT,
    amplitude TEXT,
    temps_conduite TEXT,
    convocation TEXT,
    coupure TEXT,
    pause TEXT,
    nbre_voyages TEXT,
    deplacement TEXT,
    temps_travail TEXT,
    dp TEXT,
    temps_recup TEXT,
    prime_payee TEXT,
    summary_raw TEXT,
    segment_count INT,
    first_vehicle TEXT,     -- « ligne - train » du 1er segment (ex. « 1 - 31 »)
    start_time TEXT,
    start_place TEXT,
    end_time TEXT,
    end_place TEXT,
    vehicle_key TEXT        -- first_vehicle normalisé (maj, sans espaces) : « 1-31 »
);

CREATE INDEX IF NOT EXISTS idx_transport_services_vehicle_key
    ON public.transport_services(vehicle_key);
CREATE INDEX IF NOT EXISTS idx_transport_services_edition
    ON public.transport_services(edition);

-- N° de service de roulement retenu à la prise de service.
ALTER TABLE public.driver_services
    ADD COLUMN IF NOT EXISTS service_code TEXT;

COMMENT ON COLUMN public.driver_services.service_code IS
    'N° de service de roulement choisi à la prise de service (ex. « 01TD-3 »).';

-- ===========================================================================
-- RLS : données de référence, lisibles par tout utilisateur authentifié ;
-- écriture réservée au staff.
-- ===========================================================================
ALTER TABLE public.service_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transport_services ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS service_sources_read ON public.service_sources;
CREATE POLICY service_sources_read ON public.service_sources
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS service_sources_staff_write ON public.service_sources;
CREATE POLICY service_sources_staff_write ON public.service_sources
    FOR ALL TO authenticated
    USING (public.is_staff()) WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS transport_services_read ON public.transport_services;
CREATE POLICY transport_services_read ON public.transport_services
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS transport_services_staff_write ON public.transport_services;
CREATE POLICY transport_services_staff_write ON public.transport_services
    FOR ALL TO authenticated
    USING (public.is_staff()) WITH CHECK (public.is_staff());
