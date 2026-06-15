-- Phase 0 — Politiques RLS par rôle

ALTER TABLE depots ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_location_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE network_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident_actions_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE incident_statistics_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE msr_sectors ENABLE ROW LEVEL SECURITY;
ALTER TABLE msr_missions ENABLE ROW LEVEL SECURITY;
ALTER TABLE msr_patrol_proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_fleet_positions ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- depots
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS depots_select_authenticated ON depots;
CREATE POLICY depots_select_authenticated ON depots
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS depots_manage_admin ON depots;
CREATE POLICY depots_manage_admin ON depots
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['admin']))
    WITH CHECK (public.has_role(ARRAY['admin']));

-- ---------------------------------------------------------------------------
-- user_profiles
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS profiles_select_own ON user_profiles;
CREATE POLICY profiles_select_own ON user_profiles
    FOR SELECT TO authenticated
    USING (id = auth.uid() OR public.is_staff());

DROP POLICY IF EXISTS profiles_update_own ON user_profiles;
CREATE POLICY profiles_update_own ON user_profiles
    FOR UPDATE TO authenticated
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS profiles_admin_all ON user_profiles;
CREATE POLICY profiles_admin_all ON user_profiles
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['admin']))
    WITH CHECK (public.has_role(ARRAY['admin']));

-- ---------------------------------------------------------------------------
-- driver_sessions
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS driver_sessions_own ON driver_sessions;
CREATE POLICY driver_sessions_own ON driver_sessions
    FOR ALL TO authenticated
    USING (
        driver_id = auth.uid()
        OR public.has_role(ARRAY['regulator', 'admin'])
    )
    WITH CHECK (
        driver_id = auth.uid()
        OR public.has_role(ARRAY['admin'])
    );

-- ---------------------------------------------------------------------------
-- driver_location_events
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS driver_locations_insert ON driver_location_events;
CREATE POLICY driver_locations_insert ON driver_location_events
    FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM driver_sessions ds
            WHERE ds.id = session_id AND ds.driver_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS driver_locations_select ON driver_location_events;
CREATE POLICY driver_locations_select ON driver_location_events
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM driver_sessions ds
            WHERE ds.id = session_id AND ds.driver_id = auth.uid()
        )
        OR public.has_role(ARRAY['regulator', 'admin'])
    );

-- ---------------------------------------------------------------------------
-- network_incidents
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS incidents_select_all ON network_incidents;
CREATE POLICY incidents_select_all ON network_incidents
    FOR SELECT TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS incidents_insert_all ON network_incidents;
CREATE POLICY incidents_insert_all ON network_incidents
    FOR INSERT TO authenticated, anon
    WITH CHECK (true);

DROP POLICY IF EXISTS incidents_manage_staff ON network_incidents;
CREATE POLICY incidents_manage_staff ON network_incidents
    FOR UPDATE TO authenticated
    USING (public.is_staff() OR public.has_role(ARRAY['driver']))
    WITH CHECK (public.is_staff() OR reported_by = auth.uid());

-- ---------------------------------------------------------------------------
-- incident_rules & logs : staff only
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS incident_rules_staff ON incident_rules;
CREATE POLICY incident_rules_staff ON incident_rules
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['admin', 'regulator']))
    WITH CHECK (public.has_role(ARRAY['admin']));

DROP POLICY IF EXISTS incident_actions_staff ON incident_actions_log;
CREATE POLICY incident_actions_staff ON incident_actions_log
    FOR SELECT TO authenticated
    USING (public.is_staff());

DROP POLICY IF EXISTS incident_stats_staff ON incident_statistics_daily;
CREATE POLICY incident_stats_staff ON incident_statistics_daily
    FOR SELECT TO authenticated
    USING (public.is_staff());

-- ---------------------------------------------------------------------------
-- msr_sectors
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS msr_sectors_select ON msr_sectors;
CREATE POLICY msr_sectors_select ON msr_sectors
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS msr_sectors_admin ON msr_sectors;
CREATE POLICY msr_sectors_admin ON msr_sectors
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['admin']))
    WITH CHECK (public.has_role(ARRAY['admin']));

-- ---------------------------------------------------------------------------
-- msr_missions
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS msr_missions_access ON msr_missions;
CREATE POLICY msr_missions_access ON msr_missions
    FOR ALL TO authenticated
    USING (
        public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin'])
        OR agent_id = auth.uid()
    )
    WITH CHECK (
        public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin'])
        OR agent_id = auth.uid()
    );

-- ---------------------------------------------------------------------------
-- msr_patrol_proposals
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS msr_proposals_read ON msr_patrol_proposals;
CREATE POLICY msr_proposals_read ON msr_patrol_proposals
    FOR SELECT TO authenticated
    USING (
        public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin'])
        OR EXISTS (
            SELECT 1 FROM msr_missions m
            WHERE m.id = mission_id AND m.agent_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS msr_proposals_write ON msr_patrol_proposals;
CREATE POLICY msr_proposals_write ON msr_patrol_proposals
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin']))
    WITH CHECK (public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin']));

-- ---------------------------------------------------------------------------
-- live_fleet_positions
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS live_fleet_select ON live_fleet_positions;
CREATE POLICY live_fleet_select ON live_fleet_positions
    FOR SELECT TO authenticated, anon
    USING (true);

DROP POLICY IF EXISTS live_fleet_write_service ON live_fleet_positions;
CREATE POLICY live_fleet_write_service ON live_fleet_positions
    FOR ALL TO authenticated
    USING (public.has_role(ARRAY['admin']))
    WITH CHECK (public.has_role(ARRAY['admin']));
