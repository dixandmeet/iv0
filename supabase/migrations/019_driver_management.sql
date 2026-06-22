-- Gestion conducteurs : demandes d'inscription + promotion par le staff

-- ---------------------------------------------------------------------------
-- Demandes d'inscription conducteur
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.driver_registration_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    message TEXT,
    depot_id UUID REFERENCES public.depots(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_driver_reg_status
    ON public.driver_registration_requests(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_driver_reg_user
    ON public.driver_registration_requests(user_id);

CREATE UNIQUE INDEX IF NOT EXISTS idx_driver_reg_one_pending_per_user
    ON public.driver_registration_requests(user_id)
    WHERE status = 'pending';

ALTER TABLE public.driver_registration_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS driver_reg_select ON public.driver_registration_requests;
CREATE POLICY driver_reg_select ON public.driver_registration_requests
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_staff());

DROP POLICY IF EXISTS driver_reg_insert_own ON public.driver_registration_requests;
CREATE POLICY driver_reg_insert_own ON public.driver_registration_requests
    FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.user_profiles up
            WHERE up.id = auth.uid() AND up.role = 'passenger'
        )
    );

-- Staff peut mettre à jour via RPC SECURITY DEFINER uniquement
DROP POLICY IF EXISTS driver_reg_staff_update ON public.driver_registration_requests;
CREATE POLICY driver_reg_staff_update ON public.driver_registration_requests
    FOR UPDATE TO authenticated
    USING (public.is_staff())
    WITH CHECK (public.is_staff());

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.assert_driver_manager()
RETURNS VOID AS $$
BEGIN
    IF NOT public.has_role(ARRAY['regulator', 'admin']) THEN
        RAISE EXCEPTION 'Accès réservé aux régulateurs et administrateurs';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.promote_profile_to_driver(
    p_user_id UUID,
    p_display_name TEXT DEFAULT NULL,
    p_depot_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    PERFORM public.assert_driver_manager();

    IF NOT EXISTS (SELECT 1 FROM public.user_profiles WHERE id = p_user_id) THEN
        RAISE EXCEPTION 'Utilisateur introuvable';
    END IF;

    UPDATE public.user_profiles
    SET
        role = 'driver',
        display_name = COALESCE(NULLIF(trim(p_display_name), ''), display_name),
        depot_id = COALESCE(p_depot_id, depot_id),
        updated_at = NOW()
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Soumission par un passager (app mobile)
CREATE OR REPLACE FUNCTION public.submit_driver_registration_request(
    p_message TEXT DEFAULT NULL,
    p_depot_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID := auth.uid();
    v_role TEXT;
    v_request_id UUID;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Authentification requise';
    END IF;

    SELECT role INTO v_role FROM public.user_profiles WHERE id = v_user_id;
    IF v_role IS NULL THEN
        RAISE EXCEPTION 'Profil utilisateur introuvable';
    END IF;
    IF v_role <> 'passenger' THEN
        RAISE EXCEPTION 'Seuls les comptes passagers peuvent demander le rôle conducteur';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.driver_registration_requests
        WHERE user_id = v_user_id AND status = 'pending'
    ) THEN
        RAISE EXCEPTION 'Une demande est déjà en cours de traitement';
    END IF;

    INSERT INTO public.driver_registration_requests (user_id, message, depot_id)
    VALUES (v_user_id, NULLIF(trim(p_message), ''), p_depot_id)
    RETURNING id INTO v_request_id;

    RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recherche utilisateur par email (staff)
CREATE OR REPLACE FUNCTION public.find_user_by_email_for_driver(p_email TEXT)
RETURNS TABLE (
    user_id UUID,
    email TEXT,
    display_name TEXT,
    role TEXT,
    depot_id UUID,
    has_pending_request BOOLEAN
) AS $$
DECLARE
    v_email TEXT := lower(trim(p_email));
BEGIN
    PERFORM public.assert_driver_manager();

    IF v_email = '' OR v_email NOT LIKE '%@%' THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT
        up.id AS user_id,
        au.email::TEXT,
        up.display_name,
        up.role,
        up.depot_id,
        EXISTS (
            SELECT 1 FROM public.driver_registration_requests r
            WHERE r.user_id = up.id AND r.status = 'pending'
        ) AS has_pending_request
    FROM auth.users au
    JOIN public.user_profiles up ON up.id = au.id
    WHERE lower(au.email) = v_email
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Ajout / promotion directe d'un conducteur (staff)
CREATE OR REPLACE FUNCTION public.add_or_promote_driver(
    p_email TEXT,
    p_display_name TEXT DEFAULT NULL,
    p_depot_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_email TEXT := lower(trim(p_email));
    v_user_id UUID;
    v_role TEXT;
BEGIN
    PERFORM public.assert_driver_manager();

    IF v_email = '' OR v_email NOT LIKE '%@%' THEN
        RAISE EXCEPTION 'Adresse e-mail invalide';
    END IF;

    SELECT au.id, up.role
    INTO v_user_id, v_role
    FROM auth.users au
    JOIN public.user_profiles up ON up.id = au.id
    WHERE lower(au.email) = v_email
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Aucun compte associé à cette adresse. Invitez le conducteur à créer un compte passager, ou utilisez l''invitation par e-mail.';
    END IF;

    IF v_role = 'driver' THEN
        RAISE EXCEPTION 'Ce compte est déjà conducteur';
    END IF;

    PERFORM public.promote_profile_to_driver(v_user_id, p_display_name, p_depot_id);

    UPDATE public.driver_registration_requests
    SET
        status = 'approved',
        reviewed_by = auth.uid(),
        reviewed_at = NOW(),
        depot_id = COALESCE(p_depot_id, depot_id)
    WHERE user_id = v_user_id AND status = 'pending';

    RETURN v_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Validation / refus d'une demande (staff)
CREATE OR REPLACE FUNCTION public.review_driver_registration_request(
    p_request_id UUID,
    p_action TEXT,
    p_rejection_reason TEXT DEFAULT NULL,
    p_depot_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_request public.driver_registration_requests%ROWTYPE;
BEGIN
    PERFORM public.assert_driver_manager();

    SELECT * INTO v_request
    FROM public.driver_registration_requests
    WHERE id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Demande introuvable';
    END IF;
    IF v_request.status <> 'pending' THEN
        RAISE EXCEPTION 'Cette demande a déjà été traitée';
    END IF;

    IF p_action = 'approve' THEN
        PERFORM public.promote_profile_to_driver(
            v_request.user_id,
            NULL,
            COALESCE(p_depot_id, v_request.depot_id)
        );
        UPDATE public.driver_registration_requests
        SET
            status = 'approved',
            reviewed_by = auth.uid(),
            reviewed_at = NOW(),
            depot_id = COALESCE(p_depot_id, depot_id)
        WHERE id = p_request_id;
    ELSIF p_action = 'reject' THEN
        UPDATE public.driver_registration_requests
        SET
            status = 'rejected',
            reviewed_by = auth.uid(),
            reviewed_at = NOW(),
            rejection_reason = NULLIF(trim(p_rejection_reason), '')
        WHERE id = p_request_id;
    ELSE
        RAISE EXCEPTION 'Action invalide : approve ou reject attendu';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Liste des demandes en attente (staff)
CREATE OR REPLACE FUNCTION public.list_pending_driver_requests()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    email TEXT,
    display_name TEXT,
    message TEXT,
    depot_id UUID,
    depot_name TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    PERFORM public.assert_driver_manager();

    RETURN QUERY
    SELECT
        r.id,
        r.user_id,
        au.email::TEXT,
        up.display_name,
        r.message,
        r.depot_id,
        d.name AS depot_name,
        r.created_at
    FROM public.driver_registration_requests r
    JOIN public.user_profiles up ON up.id = r.user_id
    JOIN auth.users au ON au.id = r.user_id
    LEFT JOIN public.depots d ON d.id = r.depot_id
    WHERE r.status = 'pending'
    ORDER BY r.created_at ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Annuaire conducteurs (staff)
CREATE OR REPLACE FUNCTION public.list_registered_drivers()
RETURNS TABLE (
    id UUID,
    email TEXT,
    display_name TEXT,
    depot_id UUID,
    depot_name TEXT,
    created_at TIMESTAMPTZ,
    active_session_id UUID,
    active_session_status TEXT
) AS $$
BEGIN
    PERFORM public.assert_driver_manager();

    RETURN QUERY
    SELECT
        up.id,
        au.email::TEXT,
        up.display_name,
        up.depot_id,
        d.name AS depot_name,
        up.created_at,
        ds.id AS active_session_id,
        ds.status AS active_session_status
    FROM public.user_profiles up
    JOIN auth.users au ON au.id = up.id
    LEFT JOIN public.depots d ON d.id = up.depot_id
    LEFT JOIN LATERAL (
        SELECT s.id, s.status
        FROM public.driver_sessions s
        WHERE s.driver_id = up.id
          AND s.status IN ('detecting', 'active', 'paused')
        ORDER BY s.started_at DESC
        LIMIT 1
    ) ds ON true
    WHERE up.role = 'driver'
    ORDER BY up.display_name NULLS LAST, au.email;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.submit_driver_registration_request(TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.find_user_by_email_for_driver(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_or_promote_driver(TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_driver_registration_request(UUID, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pending_driver_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_registered_drivers() TO authenticated;
