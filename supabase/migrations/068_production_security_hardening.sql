-- Durcissement production : rôles, habilitations et RPC SECURITY DEFINER.
--
-- Cette migration est volontairement additive : elle corrige aussi bien une
-- base créée de zéro qu'un projet ayant déjà appliqué 001..067.

-- ---------------------------------------------------------------------------
-- 1. Une inscription publique ne peut jamais choisir son rôle applicatif.
--    Les invitations métier promeuvent ensuite le profil avec la service_role.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, role, display_name)
    VALUES (
        NEW.id,
        'passenger',
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

REVOKE ALL ON FUNCTION public.handle_new_auth_user() FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. RLS filtre les lignes, pas les colonnes. Sans privilèges de colonnes, la
--    policy historique profiles_update_own permettait de modifier `role`.
-- ---------------------------------------------------------------------------
REVOKE UPDATE ON TABLE public.user_profiles FROM PUBLIC, anon, authenticated;
GRANT UPDATE (display_name) ON TABLE public.user_profiles TO authenticated;

-- Même principe pour la fiche conducteur : les habilitations MSR, l'identité
-- Auth et le matricule RH ne sont jamais auto-déclaratifs.
REVOKE UPDATE ON TABLE public.drivers FROM PUBLIC, anon, authenticated;
GRANT UPDATE (
    first_name,
    last_name,
    phone,
    driver_number,
    depot_id,
    network_id,
    avatar_url,
    status
) ON TABLE public.drivers TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Les fonctions SECURITY DEFINER ne doivent pas conserver le privilège
--    EXECUTE accordé implicitement à PUBLIC lors de leur création.
-- ---------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.current_user_role() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.has_role(TEXT[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_staff() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_driver_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_driver_is_control() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.has_role(TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_driver_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_driver_is_control() TO authenticated;

REVOKE ALL ON FUNCTION public.current_network_id() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_access_network(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.can_manage_network(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.network_slug(TEXT) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.provision_network_for_user(UUID, JSONB) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ensure_current_user_network() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_active_network(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.complete_network_setup(UUID, TEXT, TEXT, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.replace_network_gtfs_lines(UUID, TEXT, JSONB, INTEGER) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.publish_line_trace(TEXT, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unpublish_line_trace(TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_published_line_traces() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.current_network_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_access_network(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_network(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.ensure_current_user_network() TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_active_network(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_network_setup(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.replace_network_gtfs_lines(UUID, TEXT, JSONB, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.publish_line_trace(TEXT, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unpublish_line_trace(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_published_line_traces() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Une position ne peut viser que le service actif du conducteur courant.
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS vehicle_positions_insert_own ON public.vehicle_positions;
CREATE POLICY vehicle_positions_insert_own ON public.vehicle_positions
    FOR INSERT TO authenticated
    WITH CHECK (
        driver_id = public.current_driver_id()
        AND driver_service_id IS NOT NULL
        AND EXISTS (
            SELECT 1
            FROM public.driver_services ds
            WHERE ds.id = driver_service_id
              AND ds.driver_id = public.current_driver_id()
              AND ds.status = 'active'
        )
    );

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'vehicle_positions_valid_coordinates'
          AND conrelid = 'public.vehicle_positions'::regclass
    ) THEN
        ALTER TABLE public.vehicle_positions
            ADD CONSTRAINT vehicle_positions_valid_coordinates CHECK (
                latitude BETWEEN -90 AND 90
                AND longitude BETWEEN -180 AND 180
                AND (accuracy IS NULL OR accuracy >= 0)
                AND (speed IS NULL OR speed >= 0)
            ) NOT VALID;
    END IF;
END $$;

ALTER TABLE public.vehicle_positions
    VALIDATE CONSTRAINT vehicle_positions_valid_coordinates;

-- Les points précis ne servent qu'au temps réel. Une rétention courte limite
-- l'impact d'un incident et doit être planifiée via pg_cron en production.
CREATE OR REPLACE FUNCTION public.purge_old_vehicle_positions(
    p_retention INTERVAL DEFAULT INTERVAL '24 hours'
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_deleted BIGINT;
BEGIN
    IF p_retention < INTERVAL '15 minutes' OR p_retention > INTERVAL '30 days' THEN
        RAISE EXCEPTION 'Rétention invalide';
    END IF;

    DELETE FROM public.vehicle_positions
    WHERE created_at < NOW() - p_retention;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted;
END;
$$;

REVOKE ALL ON FUNCTION public.purge_old_vehicle_positions(INTERVAL)
    FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_old_vehicle_positions(INTERVAL)
    TO service_role;
