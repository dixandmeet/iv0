-- Hub « Activité » — corrections messagerie (Phase 5)
-- 1. Accès canal self-service correct (rôle can_write manquant => envoi bloqué)
-- 2. Compteurs non-lus pour les badges (sans charger les listes)
-- 3. Tout marquer comme lu

-- ---------------------------------------------------------------------------
-- 1. ensure_self_channel_access
--    Remplace l'upsert channel_members brut côté client.
--    - Membre actif déjà présent : on rétablit son rôle can_write si absent.
--    - Canal public (support / network) : auto-adhésion + rôle membre.
--    - Sinon (team, mission, direct…) : aucun octroi (l'invitation reste pilotée
--      par les triggers métier) — la RLS continue de protéger le canal.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ensure_self_channel_access(p_channel_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_resource_type TEXT;
    v_is_member BOOLEAN;
    v_role_id UUID;
    v_public BOOLEAN;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT r.type INTO v_resource_type
    FROM public.channels c
    LEFT JOIN public.resources r ON r.id = c.resource_id
    WHERE c.id = p_channel_id;

    SELECT EXISTS (
        SELECT 1 FROM public.channel_members
        WHERE channel_id = p_channel_id
          AND user_id = v_uid
          AND status = 'active'
    ) INTO v_is_member;

    v_public := v_resource_type IN ('support', 'network');

    -- Canal privé et non-membre : on ne force rien.
    IF NOT v_is_member AND NOT v_public THEN
        RETURN p_channel_id;
    END IF;

    -- Adhésion (idempotente).
    INSERT INTO public.channel_members (channel_id, user_id, status)
    VALUES (p_channel_id, v_uid, 'active')
    ON CONFLICT (channel_id, user_id) DO UPDATE SET status = 'active';

    -- Rôle membre (porte la permission can_write) si absent.
    SELECT id INTO v_role_id FROM public.roles WHERE key = 'channel_member' LIMIT 1;
    IF v_role_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM public.member_roles
        WHERE channel_id = p_channel_id AND user_id = v_uid
    ) THEN
        INSERT INTO public.member_roles (user_id, role_id, channel_id)
        VALUES (v_uid, v_role_id, p_channel_id)
        ON CONFLICT DO NOTHING;
    END IF;

    RETURN p_channel_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_self_channel_access(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 1bis. Backfill : membres existants sans rôle can_write.
--       (canaux créés avant cette migration via l'ancien upsert client)
-- ---------------------------------------------------------------------------
INSERT INTO public.member_roles (user_id, role_id, channel_id)
SELECT cm.user_id, r.id, cm.channel_id
FROM public.channel_members cm
CROSS JOIN public.roles r
WHERE r.key = 'channel_member'
  AND cm.status = 'active'
  AND NOT EXISTS (
      SELECT 1 FROM public.member_roles mr
      WHERE mr.channel_id = cm.channel_id AND mr.user_id = cm.user_id
  )
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. get_unread_counts — alimente les badges (menu, onglets)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_unread_counts()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID := auth.uid();
    v_notifications INT;
    v_discussions INT;
BEGIN
    IF v_uid IS NULL THEN
        RETURN jsonb_build_object('notifications', 0, 'discussions', 0);
    END IF;

    SELECT count(*) INTO v_notifications
    FROM public.user_notifications
    WHERE user_id = v_uid AND read_at IS NULL;

    -- Discussions avec au moins un message postérieur au dernier last_read_at.
    SELECT count(*) INTO v_discussions
    FROM public.channel_members cm
    WHERE cm.user_id = v_uid
      AND cm.status = 'active'
      AND NOT cm.is_archived
      AND EXISTS (
          SELECT 1 FROM public.messages m
          WHERE m.channel_id = cm.channel_id
            AND m.deleted_at IS NULL
            AND m.sender_id IS DISTINCT FROM v_uid
            AND (cm.last_read_at IS NULL OR m.created_at > cm.last_read_at)
      );

    RETURN jsonb_build_object(
        'notifications', coalesce(v_notifications, 0),
        'discussions', coalesce(v_discussions, 0)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_unread_counts() TO authenticated;

-- ---------------------------------------------------------------------------
-- 2bis. get_channel_member_profiles
--       Noms/avatars des membres d'un canal pour l'attribution des messages.
--       (user_profiles est protégé : un conducteur ne lit que sa propre fiche)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_channel_member_profiles(p_channel_id UUID)
RETURNS TABLE (id UUID, display_name TEXT, avatar_url TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_active_channel_member(p_channel_id) AND NOT public.is_staff() THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT up.id, up.display_name, up.avatar_url
    FROM public.channel_members cm
    JOIN public.user_profiles up ON up.id = cm.user_id
    WHERE cm.channel_id = p_channel_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_channel_member_profiles(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. mark_all_notifications_read
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.user_notifications
    SET read_at = NOW()
    WHERE user_id = auth.uid() AND read_at IS NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. get_hub_feed.discussions enrichi : dernier message + non-lus
--    (remplace la version 042 pour la branche discussions)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_hub_feed(
    p_view TEXT DEFAULT 'activity',
    p_limit INT DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
BEGIN
    IF p_view = 'notifications' THEN
        SELECT coalesce(jsonb_agg(row_to_json(n.*) ORDER BY n.created_at DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT * FROM public.user_notifications
            WHERE user_id = auth.uid()
            ORDER BY created_at DESC
            LIMIT p_limit
        ) n;
    ELSIF p_view = 'discussions' THEN
        SELECT coalesce(jsonb_agg(row_to_json(x.*)), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT
                c.id AS channel_id,
                c.resource_id,
                c.type AS channel_type,
                coalesce(r.name, c.name, 'Discussion') AS name,
                coalesce(r.type, c.type) AS type,
                cm.last_read_at,
                lm.body AS last_body,
                lm.created_at AS last_at,
                lm.sender_id AS last_sender_id,
                (
                    SELECT count(*) FROM public.messages m
                    WHERE m.channel_id = c.id
                      AND m.deleted_at IS NULL
                      AND m.sender_id IS DISTINCT FROM auth.uid()
                      AND (cm.last_read_at IS NULL OR m.created_at > cm.last_read_at)
                ) AS unread_count
            FROM public.channel_members cm
            JOIN public.channels c ON c.id = cm.channel_id
            LEFT JOIN public.resources r ON r.id = c.resource_id
            LEFT JOIN LATERAL (
                SELECT body, created_at, sender_id
                FROM public.messages m
                WHERE m.channel_id = c.id AND m.deleted_at IS NULL
                ORDER BY m.created_at DESC
                LIMIT 1
            ) lm ON true
            WHERE cm.user_id = auth.uid()
              AND cm.status = 'active'
              AND NOT cm.is_archived
            ORDER BY coalesce(lm.created_at, c.updated_at) DESC
            LIMIT p_limit
        ) x;
    ELSIF p_view = 'tasks' THEN
        SELECT coalesce(jsonb_agg(row_to_json(t.*) ORDER BY t.updated_at DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT t.* FROM public.channel_tasks t
            JOIN public.channel_members cm ON cm.channel_id = t.channel_id
            WHERE cm.user_id = auth.uid()
              AND cm.status = 'active'
              AND t.status != 'completed'
            ORDER BY t.updated_at DESC
            LIMIT p_limit
        ) t;
    ELSIF p_view = 'documents' THEN
        SELECT coalesce(jsonb_agg(row_to_json(f.*) ORDER BY f.created_at DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT f.* FROM public.channel_files f
            JOIN public.channel_members cm ON cm.channel_id = f.channel_id
            WHERE cm.user_id = auth.uid()
              AND cm.status = 'active'
            ORDER BY f.created_at DESC
            LIMIT p_limit
        ) f;
    ELSE
        SELECT coalesce(jsonb_agg(row_to_json(e.*) ORDER BY e.created_at DESC), '[]'::jsonb)
        INTO v_result
        FROM (
            SELECT re.*, r.name AS resource_name, r.type AS resource_type
            FROM public.resource_events re
            JOIN public.resources r ON r.id = re.resource_id
            WHERE re.resource_id IN (
                SELECT c.resource_id FROM public.channel_members cm
                JOIN public.channels c ON c.id = cm.channel_id
                WHERE cm.user_id = auth.uid() AND cm.status = 'active'
                  AND c.resource_id IS NOT NULL
                UNION
                SELECT rw.resource_id FROM public.resource_watchers rw
                WHERE rw.user_id = auth.uid()
            )
            ORDER BY re.created_at DESC
            LIMIT p_limit
        ) e;
    END IF;

    RETURN coalesce(v_result, '[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_hub_feed(TEXT, INT) TO authenticated;
