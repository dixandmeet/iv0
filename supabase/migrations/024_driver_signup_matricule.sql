-- Inscription conducteur par matricule (app Aule Pro)
-- ---------------------------------------------------------------------------
-- L'agent s'inscrit (e-mail + mot de passe) et saisit son matricule. Le
-- matricule est confronté à la liste de référence `driver_roster` (import RH) :
--   • matricule présent (et libre)   → fiche `drivers` créée, accès validé ;
--   • matricule déjà revendiqué       → refus (« immatriculation déjà utilisée ») ;
--   • matricule inconnu de la liste    → demande déposée dans
--     `driver_access_requests` (liste de vérification), accès bloqué jusqu'à
--     validation manuelle par le staff.
--
-- Le roster contient des données RH (noms de 1491 agents) : il reste privé
-- (RLS staff only). La validation côté app passe par des RPC SECURITY DEFINER
-- qui contournent le RLS de façon contrôlée.
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- driver_roster — liste de référence des agents autorisés (import RH / CSV)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.driver_roster (
    employee_id     TEXT PRIMARY KEY,
    last_name       TEXT,
    first_name      TEXT,
    seniority_date  DATE,
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    default_depot   TEXT,
    default_service TEXT,
    depots          TEXT,
    services        TEXT,
    divisions       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ===========================================================================
-- drivers.employee_id — matricule revendiqué (lien fiche ↔ roster)
-- ===========================================================================
ALTER TABLE public.drivers
    ADD COLUMN IF NOT EXISTS employee_id TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_drivers_employee_id
    ON public.drivers(employee_id)
    WHERE employee_id IS NOT NULL;

-- ===========================================================================
-- driver_access_requests — liste de vérification (matricules hors roster)
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.driver_access_requests (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_id      TEXT NOT NULL,
    email            TEXT NOT NULL,
    first_name       TEXT,
    last_name        TEXT,
    phone            TEXT,
    status           TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by      UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    reviewed_at      TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_driver_access_req_status
    ON public.driver_access_requests(status, created_at DESC);

-- Une seule demande active par utilisateur, et un matricule donné ne peut
-- être réclamé qu'une fois tant qu'il est en attente / approuvé.
CREATE UNIQUE INDEX IF NOT EXISTS idx_driver_access_req_one_per_user
    ON public.driver_access_requests(user_id)
    WHERE status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS idx_driver_access_req_employee_active
    ON public.driver_access_requests(employee_id)
    WHERE status IN ('pending', 'approved');

-- ===========================================================================
-- RLS
-- ===========================================================================
ALTER TABLE public.driver_roster ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_access_requests ENABLE ROW LEVEL SECURITY;

-- driver_roster : données RH privées — lecture staff uniquement (les RPC
-- SECURITY DEFINER ci-dessous y accèdent pour la validation côté app).
DROP POLICY IF EXISTS driver_roster_staff_read ON public.driver_roster;
CREATE POLICY driver_roster_staff_read ON public.driver_roster
    FOR SELECT TO authenticated
    USING (public.is_staff());

DROP POLICY IF EXISTS driver_roster_staff_write ON public.driver_roster;
CREATE POLICY driver_roster_staff_write ON public.driver_roster
    FOR ALL TO authenticated
    USING (public.is_staff()) WITH CHECK (public.is_staff());

-- driver_access_requests : l'agent lit sa demande, le staff voit/gère tout.
-- L'insertion se fait exclusivement via la RPC claim_driver_access (DEFINER).
DROP POLICY IF EXISTS driver_access_req_select ON public.driver_access_requests;
CREATE POLICY driver_access_req_select ON public.driver_access_requests
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_staff());

DROP POLICY IF EXISTS driver_access_req_staff_write ON public.driver_access_requests;
CREATE POLICY driver_access_req_staff_write ON public.driver_access_requests
    FOR UPDATE TO authenticated
    USING (public.is_staff()) WITH CHECK (public.is_staff());

-- ===========================================================================
-- check_driver_matricule — pré-vérification (appelable avant la création de
-- compte). Retourne le statut du matricule et, s'il est connu, le nom du
-- titulaire pour pré-remplissage / réassurance.
--   status : 'available' | 'already_used' | 'unknown'
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.check_driver_matricule(p_employee_id TEXT)
RETURNS TABLE (status TEXT, first_name TEXT, last_name TEXT) AS $$
DECLARE
    v_mat   TEXT := upper(trim(COALESCE(p_employee_id, '')));
    v_used  BOOLEAN;
    v_row   public.driver_roster%ROWTYPE;
BEGIN
    IF v_mat = '' THEN
        RETURN QUERY SELECT 'unknown'::TEXT, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    -- Déjà revendiqué : fiche conducteur existante ou demande active.
    SELECT EXISTS (
        SELECT 1 FROM public.drivers d WHERE upper(d.employee_id) = v_mat
        UNION ALL
        SELECT 1 FROM public.driver_access_requests r
        WHERE upper(r.employee_id) = v_mat AND r.status IN ('pending', 'approved')
    ) INTO v_used;

    IF v_used THEN
        RETURN QUERY SELECT 'already_used'::TEXT, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;

    SELECT * INTO v_row FROM public.driver_roster
    WHERE upper(employee_id) = v_mat AND active LIMIT 1;

    IF FOUND THEN
        RETURN QUERY SELECT 'available'::TEXT, v_row.first_name, v_row.last_name;
    ELSE
        RETURN QUERY SELECT 'unknown'::TEXT, NULL::TEXT, NULL::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ===========================================================================
-- claim_driver_access — revendication atomique du matricule par l'utilisateur
-- connecté (après création/connexion du compte). Idempotente.
--   retour : 'validated' | 'pending' | 'already_used' | 'invalid'
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.claim_driver_access(
    p_employee_id TEXT,
    p_phone       TEXT DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
    v_uid   UUID := auth.uid();
    v_email TEXT := lower(COALESCE(auth.jwt() ->> 'email', ''));
    v_mat   TEXT := upper(trim(COALESCE(p_employee_id, '')));
    v_meta  JSONB := COALESCE(auth.jwt() -> 'user_metadata', '{}'::jsonb);
    v_row   public.driver_roster%ROWTYPE;
BEGIN
    IF v_uid IS NULL OR v_email = '' THEN
        RAISE EXCEPTION 'Authentification requise';
    END IF;
    IF v_mat = '' THEN
        RETURN 'invalid';
    END IF;

    -- Idempotence : déjà conducteur ou déjà en attente pour cet utilisateur.
    IF EXISTS (SELECT 1 FROM public.drivers WHERE user_id = v_uid) THEN
        RETURN 'validated';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.driver_access_requests
        WHERE user_id = v_uid AND status = 'pending'
    ) THEN
        RETURN 'pending';
    END IF;

    -- Matricule déjà revendiqué par quelqu'un d'autre → refus.
    IF EXISTS (
        SELECT 1 FROM public.drivers WHERE upper(employee_id) = v_mat
        UNION ALL
        SELECT 1 FROM public.driver_access_requests
        WHERE upper(employee_id) = v_mat AND status IN ('pending', 'approved')
    ) THEN
        RETURN 'already_used';
    END IF;

    SELECT * INTO v_row FROM public.driver_roster
    WHERE upper(employee_id) = v_mat AND active LIMIT 1;

    IF FOUND THEN
        -- Matricule reconnu : création de la fiche conducteur + promotion.
        INSERT INTO public.drivers (user_id, email, employee_id,
                                    first_name, last_name, phone, status)
        VALUES (v_uid, v_email, v_row.employee_id,
                v_row.first_name, v_row.last_name, NULLIF(trim(p_phone), ''),
                'available');

        UPDATE public.user_profiles
        SET role = 'driver',
            display_name = COALESCE(
                NULLIF(trim(COALESCE(v_row.first_name, '') || ' ' ||
                            COALESCE(v_row.last_name, '')), ''),
                display_name),
            updated_at = NOW()
        WHERE id = v_uid;

        RETURN 'validated';
    ELSE
        -- Matricule inconnu : dépôt d'une demande de vérification.
        INSERT INTO public.driver_access_requests (
            user_id, employee_id, email, first_name, last_name, phone)
        VALUES (
            v_uid, v_mat, v_email,
            NULLIF(trim(v_meta ->> 'first_name'), ''),
            NULLIF(trim(v_meta ->> 'last_name'), ''),
            NULLIF(trim(p_phone), ''));

        RETURN 'pending';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================================================
-- my_driver_access_status — état de l'utilisateur courant pour le routage app.
--   retour : 'driver' | 'pending' | 'rejected' | 'none'
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.my_driver_access_status()
RETURNS TEXT AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_status TEXT;
BEGIN
    IF v_uid IS NULL THEN
        RETURN 'none';
    END IF;
    IF EXISTS (SELECT 1 FROM public.drivers WHERE user_id = v_uid) THEN
        RETURN 'driver';
    END IF;
    SELECT status INTO v_status FROM public.driver_access_requests
    WHERE user_id = v_uid
    ORDER BY created_at DESC LIMIT 1;
    RETURN COALESCE(v_status, 'none');
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- ===========================================================================
-- Staff : liste des demandes en attente + traitement
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.list_pending_driver_access_requests()
RETURNS TABLE (
    id          UUID,
    user_id     UUID,
    employee_id TEXT,
    email       TEXT,
    first_name  TEXT,
    last_name   TEXT,
    phone       TEXT,
    created_at  TIMESTAMPTZ
) AS $$
BEGIN
    PERFORM public.assert_driver_manager();
    RETURN QUERY
    SELECT r.id, r.user_id, r.employee_id, r.email,
           r.first_name, r.last_name, r.phone, r.created_at
    FROM public.driver_access_requests r
    WHERE r.status = 'pending'
    ORDER BY r.created_at ASC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.review_driver_access_request(
    p_request_id      UUID,
    p_action          TEXT,
    p_rejection_reason TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_req public.driver_access_requests%ROWTYPE;
BEGIN
    PERFORM public.assert_driver_manager();

    SELECT * INTO v_req FROM public.driver_access_requests
    WHERE id = p_request_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Demande introuvable';
    END IF;
    IF v_req.status <> 'pending' THEN
        RAISE EXCEPTION 'Cette demande a déjà été traitée';
    END IF;

    IF p_action = 'approve' THEN
        INSERT INTO public.drivers (user_id, email, employee_id,
                                    first_name, last_name, phone, status)
        VALUES (v_req.user_id, v_req.email, v_req.employee_id,
                v_req.first_name, v_req.last_name, v_req.phone, 'available')
        ON CONFLICT (email) DO NOTHING;

        UPDATE public.user_profiles
        SET role = 'driver', updated_at = NOW()
        WHERE id = v_req.user_id;

        UPDATE public.driver_access_requests
        SET status = 'approved', reviewed_by = auth.uid(), reviewed_at = NOW()
        WHERE id = p_request_id;
    ELSIF p_action = 'reject' THEN
        UPDATE public.driver_access_requests
        SET status = 'rejected', reviewed_by = auth.uid(), reviewed_at = NOW(),
            rejection_reason = NULLIF(trim(p_rejection_reason), '')
        WHERE id = p_request_id;
    ELSE
        RAISE EXCEPTION 'Action invalide : approve ou reject attendu';
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================================================
-- Droits d'exécution
-- ===========================================================================
GRANT EXECUTE ON FUNCTION public.check_driver_matricule(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_driver_access(TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.my_driver_access_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pending_driver_access_requests() TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_driver_access_request(UUID, TEXT, TEXT) TO authenticated;
