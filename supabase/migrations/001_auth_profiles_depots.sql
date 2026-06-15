-- Phase 0 — Auth nominative, profils utilisateurs, dépôts
-- À exécuter après schema.sql sur une base Supabase existante.

-- ---------------------------------------------------------------------------
-- Dépôts Naolib (coordonnées approximatives — à affiner avec données internes)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS depots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    geom GEOMETRY(Point, 4326) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_depots_geom ON depots USING gist(geom);

INSERT INTO depots (code, name, geom) VALUES
    ('haluchere', 'Dépôt Haluchâtre', ST_SetSRID(ST_Point(-1.5215, 47.2650), 4326)),
    ('chantenay', 'Dépôt Chantenay', ST_SetSRID(ST_Point(-1.5930, 47.1978), 4326)),
    ('pirmil', 'Dépôt Pirmil', ST_SetSRID(ST_Point(-1.5480, 47.1980), 4326))
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Profils utilisateurs (liés à auth.users Supabase)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN (
        'passenger', 'driver', 'msr_agent',
        'msr_supervisor', 'regulator', 'admin'
    )),
    display_name TEXT,
    depot_id UUID REFERENCES depots(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_role ON user_profiles(role);
CREATE INDEX IF NOT EXISTS idx_user_profiles_depot ON user_profiles(depot_id);

-- Création automatique d'un profil passager à l'inscription auth
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (id, role, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'role', 'passenger'),
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email)
    )
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- Helpers RLS
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT AS $$
    SELECT role FROM public.user_profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.has_role(allowed_roles TEXT[])
RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_profiles
        WHERE id = auth.uid() AND role = ANY(allowed_roles)
    );
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN AS $$
    SELECT public.has_role(ARRAY['msr_supervisor', 'regulator', 'admin']);
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- Extension app_settings pour le mode applicatif (mobile)
ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS app_mode TEXT DEFAULT 'passenger';
ALTER TABLE app_settings ADD COLUMN IF NOT EXISTS last_driver_session_id UUID;
