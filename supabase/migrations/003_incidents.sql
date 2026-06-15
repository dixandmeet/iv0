-- Phase 0 — Socle incidents réseau (hub central des automatisations futures)

DO $$ BEGIN
    CREATE TYPE incident_severity AS ENUM ('info', 'warning', 'critical');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE TYPE incident_status AS ENUM (
        'open', 'acknowledged', 'in_progress', 'resolved', 'closed'
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS network_incidents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_type TEXT NOT NULL,
    severity incident_severity NOT NULL DEFAULT 'warning',
    status incident_status NOT NULL DEFAULT 'open',
    title TEXT NOT NULL,
    description TEXT,
    route_id TEXT REFERENCES gtfs_routes(route_id) ON DELETE SET NULL,
    geom GEOMETRY(Geometry, 4326),
    reported_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    device_id UUID REFERENCES anonymous_devices(id) ON DELETE SET NULL,
    source TEXT NOT NULL DEFAULT 'community'
        CHECK (source IN ('community', 'driver', 'regulator', 'operator', 'system')),
    related_session_id UUID,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_network_incidents_status ON network_incidents(status);
CREATE INDEX IF NOT EXISTS idx_network_incidents_type ON network_incidents(incident_type);
CREATE INDEX IF NOT EXISTS idx_network_incidents_route ON network_incidents(route_id);
CREATE INDEX IF NOT EXISTS idx_network_incidents_geom ON network_incidents USING gist(geom);
CREATE INDEX IF NOT EXISTS idx_network_incidents_created ON network_incidents(created_at DESC);

-- Règles d'automatisation (Phase 6 — structure prête dès Phase 0)
CREATE TABLE IF NOT EXISTS incident_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    incident_type TEXT NOT NULL,
    min_severity incident_severity NOT NULL DEFAULT 'warning',
    action_type TEXT NOT NULL
        CHECK (action_type IN (
            'alert_passenger', 'notify_regulator',
            'create_msr_mission', 'adjust_service'
        )),
    action_config JSONB NOT NULL DEFAULT '{}',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE TABLE IF NOT EXISTS incident_actions_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    incident_id UUID REFERENCES network_incidents(id) ON DELETE CASCADE NOT NULL,
    rule_id UUID REFERENCES incident_rules(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL,
    result JSONB NOT NULL DEFAULT '{}',
    executed_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_incident_actions_incident ON incident_actions_log(incident_id);

-- Statistiques quotidiennes (Phase 6+)
CREATE TABLE IF NOT EXISTS incident_statistics_daily (
    date DATE NOT NULL,
    incident_type TEXT NOT NULL,
    route_id TEXT NOT NULL DEFAULT '',
    count INTEGER NOT NULL DEFAULT 0,
    avg_resolution_minutes NUMERIC,
    PRIMARY KEY (date, incident_type, route_id)
);

-- Vue de compatibilité : expose les anciens reports comme incidents
CREATE OR REPLACE VIEW legacy_reports_as_incidents AS
SELECT
    r.id,
    r.report_type AS incident_type,
    CASE r.report_type
        WHEN 'accident' THEN 'critical'::incident_severity
        WHEN 'breakdown' THEN 'warning'::incident_severity
        WHEN 'safety' THEN 'critical'::incident_severity
        ELSE 'info'::incident_severity
    END AS severity,
    'open'::incident_status AS status,
    r.report_type AS title,
    r.description,
    NULLIF(r.route_id, 'Réseau') AS route_id,
    r.geom,
    NULL::UUID AS reported_by,
    r.device_id,
    'community'::TEXT AS source,
    r.timestamp AS created_at
FROM reports r;

-- Moteur de règles minimal (stub — exécution complète en Phase 6)
CREATE OR REPLACE FUNCTION public.process_incident_rules(p_incident_id UUID)
RETURNS VOID AS $$
DECLARE
    inc RECORD;
    rule RECORD;
BEGIN
    SELECT * INTO inc FROM network_incidents WHERE id = p_incident_id;
    IF NOT FOUND THEN RETURN; END IF;

    FOR rule IN
        SELECT * FROM incident_rules
        WHERE enabled = TRUE
          AND incident_type = inc.incident_type
          AND min_severity <= inc.severity
    LOOP
        INSERT INTO incident_actions_log (incident_id, rule_id, action_type, result)
        VALUES (
            p_incident_id,
            rule.id,
            rule.action_type,
            jsonb_build_object('status', 'queued', 'note', 'Execution complete en Phase 6')
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.trg_process_incident_rules()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM public.process_incident_rules(NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_network_incident_created ON network_incidents;
CREATE TRIGGER on_network_incident_created
    AFTER INSERT ON network_incidents
    FOR EACH ROW EXECUTE FUNCTION public.trg_process_incident_rules();
