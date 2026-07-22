-- Aule Pro — réseaux autonomes, isolation multi-tenant et configuration initiale.

ALTER TABLE public.networks
    ADD COLUMN IF NOT EXISTS operator TEXT,
    ADD COLUMN IF NOT EXISTS territory TEXT,
    ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS setup_completed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

UPDATE public.networks
SET operator = COALESCE(operator, 'Semitan'),
    territory = COALESCE(territory, 'Nantes Métropole'),
    setup_completed_at = COALESCE(setup_completed_at, created_at)
WHERE code = 'naolib-nantes';

ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS active_network_id UUID REFERENCES public.networks(id) ON DELETE SET NULL;

-- Profil applicatif distinct de l'administration globale Aule Studio.
DO $$
BEGIN
    IF to_regclass('public.profile_assignments') IS NOT NULL THEN
        ALTER TABLE public.profile_assignments
            DROP CONSTRAINT IF EXISTS profile_assignments_profile_key_check;
        ALTER TABLE public.profile_assignments
            ADD CONSTRAINT profile_assignments_profile_key_check CHECK (
                profile_key IN (
                    'driver', 'vtc', 'controller', 'operations', 'supervisor',
                    'merchant', 'network_admin', 'platform_admin', 'super_admin', 'admin'
                )
            );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.network_memberships (
    network_id UUID NOT NULL REFERENCES public.networks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    membership_role TEXT NOT NULL DEFAULT 'member'
        CHECK (membership_role IN ('owner', 'admin', 'member')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (network_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_network_memberships_user
    ON public.network_memberships(user_id);

CREATE TABLE IF NOT EXISTS public.network_depots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    network_id UUID NOT NULL REFERENCES public.networks(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (network_id, code)
);

-- Catalogue éditable propre à un réseau. `data` reprend la forme RegulationLine
-- afin de permettre une migration progressive du dashboard historique Naolib.
CREATE TABLE IF NOT EXISTS public.network_lines (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    network_id UUID NOT NULL REFERENCES public.networks(id) ON DELETE CASCADE,
    line_id TEXT NOT NULL,
    short_name TEXT NOT NULL,
    long_name TEXT,
    transport_mode TEXT NOT NULL DEFAULT 'bus',
    color TEXT NOT NULL DEFAULT '#2563EB',
    source TEXT NOT NULL DEFAULT 'manual' CHECK (source IN ('manual', 'gtfs')),
    data JSONB NOT NULL DEFAULT '{}'::jsonb,
    editor_state JSONB,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (network_id, line_id)
);

CREATE INDEX IF NOT EXISTS idx_network_lines_network
    ON public.network_lines(network_id, short_name);

CREATE TABLE IF NOT EXISTS public.network_gtfs_imports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    network_id UUID NOT NULL REFERENCES public.networks(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('completed', 'failed')),
    route_count INTEGER NOT NULL DEFAULT 0,
    stop_count INTEGER NOT NULL DEFAULT 0,
    errors JSONB NOT NULL DEFAULT '[]'::jsonb,
    imported_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Les flux opérationnels historiques sont attribués à Naolib. Les nouveaux
-- réseaux ne peuvent donc jamais voir ces données par défaut.
ALTER TABLE public.depots ADD COLUMN IF NOT EXISTS network_id UUID REFERENCES public.networks(id) ON DELETE CASCADE;
ALTER TABLE public.network_incidents ADD COLUMN IF NOT EXISTS network_id UUID REFERENCES public.networks(id) ON DELETE CASCADE;
ALTER TABLE public.live_fleet_positions ADD COLUMN IF NOT EXISTS network_id UUID REFERENCES public.networks(id) ON DELETE CASCADE;
ALTER TABLE public.driver_sessions ADD COLUMN IF NOT EXISTS network_id UUID REFERENCES public.networks(id) ON DELETE CASCADE;

UPDATE public.depots SET network_id = '00000000-0000-4000-8000-000000000001' WHERE network_id IS NULL;
UPDATE public.network_incidents SET network_id = '00000000-0000-4000-8000-000000000001' WHERE network_id IS NULL;
UPDATE public.live_fleet_positions SET network_id = '00000000-0000-4000-8000-000000000001' WHERE network_id IS NULL;
UPDATE public.driver_sessions SET network_id = '00000000-0000-4000-8000-000000000001' WHERE network_id IS NULL;

ALTER TABLE public.line_editor_traces ADD COLUMN IF NOT EXISTS network_id UUID REFERENCES public.networks(id) ON DELETE CASCADE;
UPDATE public.line_editor_traces SET network_id = '00000000-0000-4000-8000-000000000001' WHERE network_id IS NULL;
ALTER TABLE public.line_editor_traces ALTER COLUMN network_id SET NOT NULL;
ALTER TABLE public.line_editor_traces DROP CONSTRAINT IF EXISTS line_editor_traces_pkey;
ALTER TABLE public.line_editor_traces ADD PRIMARY KEY (network_id, line_id);

CREATE OR REPLACE FUNCTION public.current_network_id()
RETURNS UUID
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT COALESCE(
        (SELECT active_network_id FROM public.user_profiles WHERE id = auth.uid()),
        (SELECT network_id FROM public.network_memberships WHERE user_id = auth.uid() ORDER BY created_at LIMIT 1)
    );
$$;

CREATE OR REPLACE FUNCTION public.can_access_network(p_network_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.network_memberships
        WHERE network_id = p_network_id AND user_id = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION public.can_manage_network(p_network_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.network_memberships
        WHERE network_id = p_network_id
          AND user_id = auth.uid()
          AND membership_role IN ('owner', 'admin')
    );
$$;

CREATE OR REPLACE FUNCTION public.network_slug(p_name TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
    SELECT trim(both '-' from regexp_replace(lower(unaccent(coalesce(p_name, 'reseau'))), '[^a-z0-9]+', '-', 'g'));
$$;

CREATE OR REPLACE FUNCTION public.provision_network_for_user(
    p_user_id UUID,
    p_request JSONB DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_network_id UUID;
    v_code TEXT;
    v_name TEXT;
BEGIN
    SELECT network_id INTO v_network_id
    FROM public.network_memberships
    WHERE user_id = p_user_id
    ORDER BY (membership_role = 'owner') DESC, created_at
    LIMIT 1;

    IF v_network_id IS NOT NULL THEN
        UPDATE public.user_profiles SET active_network_id = v_network_id WHERE id = p_user_id;
        RETURN v_network_id;
    END IF;

    IF p_request IS NOT NULL AND nullif(trim(p_request->>'name'), '') IS NOT NULL THEN
        v_name := trim(p_request->>'name');
        v_code := COALESCE(NULLIF(public.network_slug(v_name), ''), 'reseau') || '-' || substr(replace(p_user_id::text, '-', ''), 1, 8);

        INSERT INTO public.networks (name, code, operator, territory, status, created_by)
        VALUES (
            v_name,
            v_code,
            NULLIF(trim(p_request->>'operator'), ''),
            NULLIF(trim(p_request->>'territory'), ''),
            'active',
            p_user_id
        )
        ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name
        RETURNING id INTO v_network_id;

        INSERT INTO public.network_memberships (network_id, user_id, membership_role)
        VALUES (v_network_id, p_user_id, 'owner')
        ON CONFLICT (network_id, user_id) DO UPDATE SET membership_role = 'owner';

        IF to_regclass('public.profile_assignments') IS NOT NULL THEN
            EXECUTE 'INSERT INTO public.profile_assignments (user_id, profile_key, context)
                     VALUES ($1, ''network_admin'', jsonb_build_object(''network_id'', $2))
                     ON CONFLICT (user_id, profile_key) DO UPDATE
                     SET context = EXCLUDED.context, is_active = true'
            USING p_user_id, v_network_id;
        END IF;
    ELSE
        v_network_id := '00000000-0000-4000-8000-000000000001';
        INSERT INTO public.network_memberships (network_id, user_id, membership_role)
        VALUES (v_network_id, p_user_id, 'member')
        ON CONFLICT (network_id, user_id) DO NOTHING;
    END IF;

    UPDATE public.user_profiles SET active_network_id = v_network_id WHERE id = p_user_id;
    RETURN v_network_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.ensure_current_user_network()
RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_request JSONB;
BEGIN
    SELECT raw_user_meta_data->'onboarding_network_request'
    INTO v_request FROM auth.users WHERE id = auth.uid();
    RETURN public.provision_network_for_user(auth.uid(), v_request);
END;
$$;

CREATE OR REPLACE FUNCTION public.set_active_network(p_network_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    IF NOT public.can_access_network(p_network_id) THEN
        RAISE EXCEPTION 'Accès refusé à ce réseau';
    END IF;
    UPDATE public.user_profiles SET active_network_id = p_network_id WHERE id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.complete_network_setup(
    p_network_id UUID,
    p_name TEXT,
    p_operator TEXT,
    p_territory TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    IF NOT public.can_manage_network(p_network_id) THEN
        RAISE EXCEPTION 'Accès administrateur requis';
    END IF;
    UPDATE public.networks
    SET name = trim(p_name), operator = trim(p_operator), territory = trim(p_territory),
        setup_completed_at = NOW(), updated_at = NOW()
    WHERE id = p_network_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.replace_network_gtfs_lines(
    p_network_id UUID,
    p_filename TEXT,
    p_lines JSONB,
    p_stop_count INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_count INTEGER;
BEGIN
    IF NOT public.can_manage_network(p_network_id) THEN
        RAISE EXCEPTION 'Accès administrateur requis';
    END IF;
    IF jsonb_typeof(p_lines) <> 'array' THEN
        RAISE EXCEPTION 'Catalogue de lignes invalide';
    END IF;

    DELETE FROM public.network_lines WHERE network_id = p_network_id AND source = 'gtfs';
    INSERT INTO public.network_lines (
        network_id, line_id, short_name, long_name, transport_mode, color, source, data, created_by
    )
    SELECT p_network_id, x.line_id, x.short_name, x.long_name, x.transport_mode,
           x.color, 'gtfs', x.data, auth.uid()
    FROM jsonb_to_recordset(p_lines) AS x(
        line_id TEXT, short_name TEXT, long_name TEXT, transport_mode TEXT, color TEXT, data JSONB
    );
    GET DIAGNOSTICS v_count = ROW_COUNT;

    INSERT INTO public.network_gtfs_imports (
        network_id, filename, status, route_count, stop_count, imported_by
    ) VALUES (p_network_id, p_filename, 'completed', v_count, p_stop_count, auth.uid());
    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.publish_line_trace(
    p_line_id TEXT, p_editor_state_id TEXT, p_transport_mode TEXT, p_color TEXT, p_variants JSONB
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_network_id UUID := public.current_network_id();
BEGIN
    IF NOT public.can_manage_network(v_network_id) THEN RAISE EXCEPTION 'Accès administrateur requis'; END IF;
    INSERT INTO public.line_editor_traces (network_id, line_id, editor_state_id, transport_mode, color, variants, updated_at)
    VALUES (v_network_id, p_line_id, p_editor_state_id, p_transport_mode, p_color, p_variants, NOW())
    ON CONFLICT (network_id, line_id) DO UPDATE SET
        editor_state_id = EXCLUDED.editor_state_id, transport_mode = EXCLUDED.transport_mode,
        color = EXCLUDED.color, variants = EXCLUDED.variants, updated_at = NOW();
END;
$$;

CREATE OR REPLACE FUNCTION public.unpublish_line_trace(p_line_id TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_network_id UUID := public.current_network_id();
BEGIN
    IF NOT public.can_manage_network(v_network_id) THEN RAISE EXCEPTION 'Accès administrateur requis'; END IF;
    DELETE FROM public.line_editor_traces WHERE network_id = v_network_id AND line_id = p_line_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_published_line_traces()
RETURNS TABLE (line_id TEXT, transport_mode TEXT, color TEXT, variants JSONB)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
    SELECT t.line_id, t.transport_mode, t.color, t.variants
    FROM public.line_editor_traces t
    WHERE t.network_id = public.current_network_id();
$$;

REVOKE EXECUTE ON FUNCTION public.publish_line_trace(TEXT, TEXT, TEXT, TEXT, JSONB) FROM anon;
REVOKE EXECUTE ON FUNCTION public.unpublish_line_trace(TEXT) FROM anon;
REVOKE EXECUTE ON FUNCTION public.get_published_line_traces() FROM anon;

-- Les RPC stations historiques étaient SECURITY DEFINER et pouvaient contourner
-- les nouvelles politiques réseau lorsqu'un UUID étranger était fourni.
ALTER FUNCTION public.get_station_detail(UUID, DOUBLE PRECISION, DOUBLE PRECISION, TEXT) SECURITY INVOKER;
ALTER FUNCTION public.resolve_gtfs_stop_id(UUID) SECURITY INVOKER;
ALTER FUNCTION public.get_nearby_stops(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, UUID, TEXT) SECURITY INVOKER;

-- Rebranche le trigger Auth afin que la création du profil et du réseau soit
-- atomique pour toutes les nouvelles inscriptions.
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, role, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'role', 'passenger'),
        COALESCE(NEW.raw_user_meta_data->>'display_name', NEW.email)
    ) ON CONFLICT (id) DO NOTHING;

    IF COALESCE(NEW.raw_user_meta_data->>'requested_access', '') = 'pro' THEN
        PERFORM public.provision_network_for_user(
            NEW.id,
            NEW.raw_user_meta_data->'onboarding_network_request'
        );
    END IF;
    RETURN NEW;
END;
$$;

-- Récupération idempotente des comptes créés avant cette migration.
DO $$
DECLARE u RECORD;
BEGIN
    FOR u IN
        SELECT id, raw_user_meta_data->'onboarding_network_request' AS request
        FROM auth.users
        WHERE COALESCE(raw_user_meta_data->>'requested_access', '') = 'pro'
    LOOP
        PERFORM public.provision_network_for_user(u.id, u.request);
    END LOOP;
END $$;

ALTER TABLE public.network_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.network_depots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.network_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.network_gtfs_imports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS memberships_select_own ON public.network_memberships;
CREATE POLICY memberships_select_own ON public.network_memberships FOR SELECT TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS networks_select_members ON public.networks;
DROP POLICY IF EXISTS networks_select_public ON public.networks;
CREATE POLICY networks_select_members ON public.networks FOR SELECT TO authenticated
    USING (public.can_access_network(id));
DROP POLICY IF EXISTS networks_update_managers ON public.networks;
CREATE POLICY networks_update_managers ON public.networks FOR UPDATE TO authenticated
    USING (public.can_manage_network(id)) WITH CHECK (public.can_manage_network(id));

DROP POLICY IF EXISTS network_depots_members ON public.network_depots;
CREATE POLICY network_depots_members ON public.network_depots FOR SELECT TO authenticated
    USING (public.can_access_network(network_id));
DROP POLICY IF EXISTS network_depots_managers ON public.network_depots;
CREATE POLICY network_depots_managers ON public.network_depots FOR ALL TO authenticated
    USING (public.can_manage_network(network_id)) WITH CHECK (public.can_manage_network(network_id));

DROP POLICY IF EXISTS network_lines_members ON public.network_lines;
CREATE POLICY network_lines_members ON public.network_lines FOR SELECT TO authenticated
    USING (public.can_access_network(network_id));
DROP POLICY IF EXISTS network_lines_managers ON public.network_lines;
CREATE POLICY network_lines_managers ON public.network_lines FOR ALL TO authenticated
    USING (public.can_manage_network(network_id)) WITH CHECK (public.can_manage_network(network_id));

DROP POLICY IF EXISTS network_gtfs_imports_members ON public.network_gtfs_imports;
CREATE POLICY network_gtfs_imports_members ON public.network_gtfs_imports FOR SELECT TO authenticated
    USING (public.can_access_network(network_id));

DROP POLICY IF EXISTS stations_select_public ON public.stations;
DROP POLICY IF EXISTS stations_manage_staff ON public.stations;
CREATE POLICY stations_select_network ON public.stations FOR SELECT TO authenticated
    USING (public.can_access_network(network_id));
CREATE POLICY stations_select_pilot_public ON public.stations FOR SELECT TO anon
    USING (network_id = '00000000-0000-4000-8000-000000000001');
CREATE POLICY stations_manage_network ON public.stations FOR ALL TO authenticated
    USING (public.can_manage_network(network_id)) WITH CHECK (public.can_manage_network(network_id));

DROP POLICY IF EXISTS stops_select_public ON public.stops;
DROP POLICY IF EXISTS stops_manage_staff ON public.stops;
CREATE POLICY stops_select_network ON public.stops FOR SELECT TO authenticated
    USING (public.can_access_network(network_id));
CREATE POLICY stops_select_pilot_public ON public.stops FOR SELECT TO anon
    USING (network_id = '00000000-0000-4000-8000-000000000001');
CREATE POLICY stops_manage_network ON public.stops FOR ALL TO authenticated
    USING (public.can_manage_network(network_id)) WITH CHECK (public.can_manage_network(network_id));

DROP POLICY IF EXISTS gtfs_stop_mapping_select_public ON public.gtfs_stop_mapping;
CREATE POLICY gtfs_stop_mapping_select_network ON public.gtfs_stop_mapping FOR SELECT TO authenticated
    USING (public.can_access_network(network_id));
CREATE POLICY gtfs_stop_mapping_manage_network ON public.gtfs_stop_mapping FOR ALL TO authenticated
    USING (public.can_manage_network(network_id)) WITH CHECK (public.can_manage_network(network_id));

DROP POLICY IF EXISTS depots_select_authenticated ON public.depots;
CREATE POLICY depots_select_network ON public.depots FOR SELECT TO authenticated
    USING (public.can_access_network(network_id));

-- Les tables historiques ne sont plus lisibles globalement par les comptes Pro.
DROP POLICY IF EXISTS incidents_select_all ON public.network_incidents;
CREATE POLICY incidents_select_network ON public.network_incidents FOR SELECT TO authenticated
    USING (network_id = public.current_network_id());
DROP POLICY IF EXISTS incidents_insert_all ON public.network_incidents;
CREATE POLICY incidents_insert_network ON public.network_incidents FOR INSERT TO authenticated
    WITH CHECK (network_id = public.current_network_id());
DROP POLICY IF EXISTS incidents_manage_staff ON public.network_incidents;
CREATE POLICY incidents_manage_network ON public.network_incidents FOR UPDATE TO authenticated
    USING (network_id = public.current_network_id())
    WITH CHECK (network_id = public.current_network_id());
DROP POLICY IF EXISTS live_fleet_select ON public.live_fleet_positions;
CREATE POLICY live_fleet_select_network ON public.live_fleet_positions FOR SELECT TO authenticated
    USING (network_id = public.current_network_id());

DROP POLICY IF EXISTS driver_sessions_own ON public.driver_sessions;
CREATE POLICY driver_sessions_network ON public.driver_sessions FOR SELECT TO authenticated
    USING (driver_id = auth.uid() OR network_id = public.current_network_id());
CREATE POLICY driver_sessions_write_network ON public.driver_sessions FOR ALL TO authenticated
    USING (driver_id = auth.uid() OR public.can_manage_network(network_id))
    WITH CHECK (network_id = public.current_network_id() AND (driver_id = auth.uid() OR public.can_manage_network(network_id)));

DROP POLICY IF EXISTS station_audit_log_select_staff ON public.station_audit_log;
CREATE POLICY station_audit_log_select_network ON public.station_audit_log FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.stations s WHERE s.id = station_id AND public.can_access_network(s.network_id)));
DROP POLICY IF EXISTS station_audit_log_insert_staff ON public.station_audit_log;
CREATE POLICY station_audit_log_insert_network ON public.station_audit_log FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM public.stations s WHERE s.id = station_id AND public.can_manage_network(s.network_id)));

DROP POLICY IF EXISTS stop_audit_log_select_staff ON public.stop_audit_log;
CREATE POLICY stop_audit_log_select_network ON public.stop_audit_log FOR SELECT TO authenticated
    USING (EXISTS (SELECT 1 FROM public.stops s WHERE s.id = stop_uuid AND public.can_access_network(s.network_id)));
DROP POLICY IF EXISTS stop_audit_log_insert_staff ON public.stop_audit_log;
CREATE POLICY stop_audit_log_insert_network ON public.stop_audit_log FOR INSERT TO authenticated
    WITH CHECK (EXISTS (SELECT 1 FROM public.stops s WHERE s.id = stop_uuid AND public.can_manage_network(s.network_id)));

GRANT EXECUTE ON FUNCTION public.ensure_current_user_network() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_active_network(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_network_setup(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.replace_network_gtfs_lines(UUID, TEXT, JSONB, INTEGER) TO authenticated;
