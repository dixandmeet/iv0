-- Plans de contrôle MSR — hiérarchie Plan → Missions → Équipes → Agents

CREATE TABLE IF NOT EXISTS control_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    objective TEXT NOT NULL,
    priority TEXT NOT NULL DEFAULT 'medium'
        CHECK (priority IN ('high', 'medium', 'low')),
    status TEXT NOT NULL DEFAULT 'draft'
        CHECK (status IN ('draft', 'active', 'completed', 'suspended')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    created_by UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT control_plans_dates_check CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_control_plans_status ON control_plans(status);
CREATE INDEX IF NOT EXISTS idx_control_plans_dates ON control_plans(start_date, end_date);

CREATE TABLE IF NOT EXISTS control_plan_teams (
    plan_id UUID REFERENCES control_plans(id) ON DELETE CASCADE NOT NULL,
    team_id TEXT NOT NULL,
    PRIMARY KEY (plan_id, team_id)
);

CREATE TABLE IF NOT EXISTS control_plan_agents (
    plan_id UUID REFERENCES control_plans(id) ON DELETE CASCADE NOT NULL,
    agent_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE NOT NULL,
    PRIMARY KEY (plan_id, agent_id)
);

CREATE TABLE IF NOT EXISTS control_plan_lines (
    plan_id UUID REFERENCES control_plans(id) ON DELETE CASCADE NOT NULL,
    line_id TEXT NOT NULL,
    PRIMARY KEY (plan_id, line_id)
);

CREATE TABLE IF NOT EXISTS control_plan_stations (
    plan_id UUID REFERENCES control_plans(id) ON DELETE CASCADE NOT NULL,
    station_id TEXT NOT NULL,
    PRIMARY KEY (plan_id, station_id)
);

CREATE TABLE IF NOT EXISTS control_plan_zones (
    plan_id UUID REFERENCES control_plans(id) ON DELETE CASCADE NOT NULL,
    zone_id TEXT NOT NULL,
    PRIMARY KEY (plan_id, zone_id)
);

CREATE TABLE IF NOT EXISTS control_plan_instructions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id UUID REFERENCES control_plans(id) ON DELETE CASCADE NOT NULL,
    content TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_control_plan_instructions_plan
    ON control_plan_instructions(plan_id, sort_order);

-- Lien missions ↔ plan de contrôle (extension msr_missions)
ALTER TABLE msr_missions
    ADD COLUMN IF NOT EXISTS control_plan_id UUID REFERENCES control_plans(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS team_id TEXT,
    ADD COLUMN IF NOT EXISTS zone_id TEXT,
    ADD COLUMN IF NOT EXISTS scheduled_start TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS scheduled_end TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_msr_missions_control_plan
    ON msr_missions(control_plan_id);

COMMENT ON TABLE control_plans IS 'Plans de contrôle MSR — niveau supérieur des missions';
COMMENT ON COLUMN msr_missions.control_plan_id IS 'Plan de contrôle parent (optionnel)';
