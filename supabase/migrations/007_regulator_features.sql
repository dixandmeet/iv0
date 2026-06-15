-- Phase 6 — Fonctionnalités régulateur : communication, info-voyageur, journal incidents

-- Messages staff (conducteurs, MSR, broadcast)
CREATE TABLE IF NOT EXISTS staff_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    recipient_role TEXT CHECK (recipient_role IN ('driver', 'msr_agent', 'msr_supervisor', 'regulator', 'admin')),
    route_id TEXT REFERENCES gtfs_routes(route_id) ON DELETE SET NULL,
    subject TEXT,
    body TEXT NOT NULL,
    message_type TEXT NOT NULL DEFAULT 'direct'
        CHECK (message_type IN ('direct', 'group', 'broadcast')),
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_staff_messages_recipient ON staff_messages(recipient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_staff_messages_route ON staff_messages(route_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_staff_messages_created ON staff_messages(created_at DESC);

-- Annonces info-voyageur
CREATE TABLE IF NOT EXISTS passenger_announcements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    announcement_type TEXT NOT NULL DEFAULT 'info'
        CHECK (announcement_type IN ('info', 'disruption', 'cancellation', 'deviation', 'delay')),
    route_ids TEXT[] NOT NULL DEFAULT '{}',
    severity incident_severity NOT NULL DEFAULT 'info',
    incident_id UUID REFERENCES network_incidents(id) ON DELETE SET NULL,
    published_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    published_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    metadata JSONB NOT NULL DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_passenger_announcements_active ON passenger_announcements(is_active, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_passenger_announcements_incident ON passenger_announcements(incident_id);

-- Journal d'actions incidents (INSERT staff)
CREATE POLICY IF NOT EXISTS incident_actions_insert_staff ON incident_actions_log
    FOR INSERT TO authenticated
    WITH CHECK (public.is_staff());

-- RPC : journaliser une action incident
CREATE OR REPLACE FUNCTION public.log_incident_action(
    p_incident_id UUID,
    p_action_type TEXT,
    p_result JSONB DEFAULT '{}'
)
RETURNS UUID AS $$
DECLARE
    new_id UUID;
BEGIN
    INSERT INTO incident_actions_log (incident_id, action_type, result)
    VALUES (p_incident_id, p_action_type, p_result)
    RETURNING id INTO new_id;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RLS staff_messages
ALTER TABLE staff_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY staff_messages_select ON staff_messages
    FOR SELECT TO authenticated
    USING (
        public.is_staff()
        OR sender_id = auth.uid()
        OR recipient_id = auth.uid()
    );

CREATE POLICY staff_messages_insert ON staff_messages
    FOR INSERT TO authenticated
    WITH CHECK (public.is_staff() AND sender_id = auth.uid());

CREATE POLICY staff_messages_update_read ON staff_messages
    FOR UPDATE TO authenticated
    USING (recipient_id = auth.uid())
    WITH CHECK (recipient_id = auth.uid());

-- RLS passenger_announcements
ALTER TABLE passenger_announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY passenger_announcements_select ON passenger_announcements
    FOR SELECT TO authenticated, anon
    USING (true);

CREATE POLICY passenger_announcements_manage_staff ON passenger_announcements
    FOR ALL TO authenticated
    USING (public.is_staff())
    WITH CHECK (public.is_staff());

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE staff_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE passenger_announcements;
