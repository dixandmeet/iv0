-- Bourse d'échanges de service — Aule Pro
-- ---------------------------------------------------------------------------
-- La messagerie reste le cœur : une annonce d'échange est un *contexte* de
-- conversation, branché sur la plateforme via deux primitives génériques :
--   • conversation_contexts : lie un canal à un objet métier (annonce, mission,
--     équipe, véhicule…) — réutilisable par tous les domaines.
--   • resource_events       : timeline générique déjà existante (042).
--
-- Modèle de conversation : 1 conversation privée 1:1 par contacteur, rattachée
-- à l'annonce. Les contacteurs ne se voient pas entre eux. Les événements
-- globaux (publiée / modifiée / résolue) ont channel_id = NULL (visibles dans
-- toutes les conversations) ; l'événement « contacté » est scellé au canal.
--
-- Toute la logique passe par des RPC SECURITY DEFINER ; les habilitations
-- conduite/umtc ne sont pas stockées en base (SharedPreferences côté app), le
-- client les transmet donc à la lecture du feed.
-- ===========================================================================

-- ===========================================================================
-- 0. Primitive générique : conversation_contexts
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.conversation_contexts (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id   UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    context_type TEXT NOT NULL,   -- 'service_exchange' | 'mission' | 'control_plan' | 'team' | 'vehicle' | 'incident'
    context_id   UUID NOT NULL,   -- pointe vers l'objet métier
    role         TEXT,            -- rôle du canal dans ce contexte (ex. 'negotiation')
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (channel_id, context_type, context_id)
);

CREATE INDEX IF NOT EXISTS idx_conversation_contexts_ctx
    ON public.conversation_contexts (context_type, context_id);
CREATE INDEX IF NOT EXISTS idx_conversation_contexts_channel
    ON public.conversation_contexts (channel_id);

-- ===========================================================================
-- 1. service_exchange_posts — annonces
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.service_exchange_posts (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    author_driver_id    UUID REFERENCES public.drivers(id) ON DELETE SET NULL,
    network_id          UUID,
    network_code        TEXT NOT NULL DEFAULT 'naolib',
    depot_id            UUID REFERENCES public.depots(id) ON DELETE SET NULL,
    depot_name          TEXT,
    profile_type        TEXT NOT NULL DEFAULT 'reseau',
    post_kind           TEXT NOT NULL DEFAULT 'request'
                        CHECK (post_kind IN ('request', 'can_replace')),
    service_type        TEXT NOT NULL
                        CHECK (service_type IN ('BUS', 'TRAM', 'CONTROLE', 'INTERVENTION', 'UMTC')),
    required_habilitation TEXT NOT NULL
                        CHECK (required_habilitation IN ('conduite', 'controle', 'intervention', 'umtc')),
    service_date        DATE NOT NULL,
    start_time          TIME NOT NULL,
    end_time            TIME NOT NULL,
    service_number      TEXT,
    line_code           TEXT,
    vehicle_code        TEXT,
    service_label       TEXT,
    message             TEXT,
    title               TEXT NOT NULL,
    status              TEXT NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active', 'in_discussion', 'agreed', 'cancelled', 'expired')),
    visibility          TEXT NOT NULL DEFAULT 'public'
                        CHECK (visibility IN ('public', 'depot', 'team', 'group')),
    audience_id         UUID,
    expires_at          TIMESTAMPTZ,
    is_urgent           BOOLEAN NOT NULL DEFAULT FALSE,
    contact_count       INT NOT NULL DEFAULT 0,
    view_count          INT NOT NULL DEFAULT 0,
    bumped_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    relanced_at         TIMESTAMPTZ,
    resolved_at         TIMESTAMPTZ,
    resource_id         UUID REFERENCES public.resources(id) ON DELETE SET NULL,
    author_display_name TEXT,
    author_avatar_url   TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_se_posts_feed
    ON public.service_exchange_posts (status, service_date);
CREATE INDEX IF NOT EXISTS idx_se_posts_author
    ON public.service_exchange_posts (author_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_se_posts_depot
    ON public.service_exchange_posts (depot_id, status);

-- ===========================================================================
-- 2. Tables métier annexes
-- ===========================================================================
CREATE TABLE IF NOT EXISTS public.service_exchange_favorites (
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id    UUID NOT NULL REFERENCES public.service_exchange_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

CREATE TABLE IF NOT EXISTS public.service_exchange_views (
    post_id   UUID NOT NULL REFERENCES public.service_exchange_posts(id) ON DELETE CASCADE,
    viewer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, viewer_id)
);

CREATE TABLE IF NOT EXISTS public.service_exchange_reactions (
    post_id    UUID NOT NULL REFERENCES public.service_exchange_posts(id) ON DELETE CASCADE,
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reaction   TEXT NOT NULL CHECK (reaction IN ('like', 'seen')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id, reaction)
);

CREATE TABLE IF NOT EXISTS public.service_exchange_notifications_sent (
    post_id           UUID NOT NULL REFERENCES public.service_exchange_posts(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_kind TEXT NOT NULL CHECK (notification_kind IN ('created', 'relanced', 'urgent')),
    notified_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id, notification_kind)
);

-- ===========================================================================
-- 3. Triggers de cohérence
-- ===========================================================================
-- contact_count = nb de conversations liées à l'annonce.
CREATE OR REPLACE FUNCTION public.se_sync_contact_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.context_type = 'service_exchange' THEN
        UPDATE public.service_exchange_posts
           SET contact_count = contact_count + 1
         WHERE id = NEW.context_id;
    ELSIF TG_OP = 'DELETE' AND OLD.context_type = 'service_exchange' THEN
        UPDATE public.service_exchange_posts
           SET contact_count = GREATEST(contact_count - 1, 0)
         WHERE id = OLD.context_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_se_contact_count ON public.conversation_contexts;
CREATE TRIGGER trg_se_contact_count
    AFTER INSERT OR DELETE ON public.conversation_contexts
    FOR EACH ROW EXECUTE FUNCTION public.se_sync_contact_count();

-- ===========================================================================
-- 4. Helpers
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.se_deduce_required_habilitation(p_service_type TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE p_service_type
        WHEN 'BUS' THEN 'conduite'
        WHEN 'TRAM' THEN 'conduite'
        WHEN 'CONTROLE' THEN 'controle'
        WHEN 'INTERVENTION' THEN 'intervention'
        WHEN 'UMTC' THEN 'umtc'
        ELSE 'conduite'
    END;
$$;

CREATE OR REPLACE FUNCTION public.se_generate_title(
    p_post_kind TEXT,
    p_service_type TEXT,
    p_service_number TEXT,
    p_line_code TEXT,
    p_service_date DATE
)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    v_date TEXT;
BEGIN
    v_date := to_char(p_service_date, 'TMDay DD TMMonth');
    IF p_post_kind = 'can_replace' THEN
        RETURN 'Remplacement possible ' || p_service_type || ' - ' || initcap(v_date);
    END IF;
    IF p_service_number IS NOT NULL AND btrim(p_service_number) <> '' THEN
        RETURN 'Échange service ' || btrim(p_service_number);
    END IF;
    IF p_line_code IS NOT NULL AND btrim(p_line_code) <> '' THEN
        RETURN 'Recherche échange ' || p_service_type || ' - Ligne ' || btrim(p_line_code);
    END IF;
    RETURN 'Échange service ' || p_service_type || ' - ' || initcap(v_date);
END;
$$;

-- Expiration paresseuse (appelée au début des lectures).
CREATE OR REPLACE FUNCTION public.se_expire_posts()
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    UPDATE public.service_exchange_posts
       SET status = 'expired', updated_at = NOW()
     WHERE status IN ('active', 'in_discussion')
       AND expires_at IS NOT NULL
       AND expires_at < NOW();
$$;

-- Notifie les agents compatibles (même dépôt/réseau/habilitation), hors auteur,
-- non encore notifiés pour ce post (selon p_kind).
CREATE OR REPLACE FUNCTION public.se_notify_compatible(
    p_post_id UUID,
    p_kind TEXT,
    p_priority TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_post public.service_exchange_posts%ROWTYPE;
    v_title TEXT;
BEGIN
    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RETURN; END IF;

    v_title := CASE
        WHEN p_kind = 'urgent' THEN 'Annonce urgente compatible'
        WHEN p_kind = 'relanced' THEN 'Annonce relancée'
        ELSE 'Nouvelle annonce compatible'
    END;

    INSERT INTO public.user_notifications (
        user_id, category, source_type, source_id, title, body, priority
    )
    SELECT
        up.id,
        'activity',
        'service_exchange_post',
        v_post.id,
        v_title,
        v_post.service_type || ' · ' || to_char(v_post.service_date, 'DD/MM') ||
            COALESCE(' · ' || v_post.depot_name, ''),
        p_priority
    FROM public.drivers d
    JOIN public.user_profiles up ON up.id = d.user_id
    WHERE d.depot_id = v_post.depot_id
      AND d.id IS DISTINCT FROM v_post.author_driver_id
      AND up.id IS DISTINCT FROM v_post.author_id
      AND (
            v_post.required_habilitation = 'conduite'
         OR v_post.required_habilitation = 'umtc'
         OR (v_post.required_habilitation = 'controle' AND d.msr_control)
         OR (v_post.required_habilitation = 'intervention' AND d.msr_intervention)
      )
      AND NOT EXISTS (
            SELECT 1 FROM public.service_exchange_notifications_sent s
            WHERE s.post_id = v_post.id AND s.user_id = up.id
              AND s.notification_kind = p_kind
      );

    INSERT INTO public.service_exchange_notifications_sent (post_id, user_id, notification_kind)
    SELECT v_post.id, up.id, p_kind
    FROM public.drivers d
    JOIN public.user_profiles up ON up.id = d.user_id
    WHERE d.depot_id = v_post.depot_id
      AND d.id IS DISTINCT FROM v_post.author_driver_id
      AND up.id IS DISTINCT FROM v_post.author_id
      AND (
            v_post.required_habilitation = 'conduite'
         OR v_post.required_habilitation = 'umtc'
         OR (v_post.required_habilitation = 'controle' AND d.msr_control)
         OR (v_post.required_habilitation = 'intervention' AND d.msr_intervention)
      )
    ON CONFLICT DO NOTHING;
END;
$$;

-- Sérialise une annonce + flags propres au viewer.
CREATE OR REPLACE FUNCTION public.se_post_json(
    p_post public.service_exchange_posts,
    p_viewer UUID,
    p_habilitations TEXT[]
)
RETURNS JSONB
LANGUAGE sql
STABLE
SET search_path = public
AS $$
    SELECT jsonb_build_object(
        'id', p_post.id,
        'author_id', p_post.author_id,
        'network_code', p_post.network_code,
        'depot_id', p_post.depot_id,
        'depot_name', p_post.depot_name,
        'profile_type', p_post.profile_type,
        'post_kind', p_post.post_kind,
        'service_type', p_post.service_type,
        'required_habilitation', p_post.required_habilitation,
        'service_date', p_post.service_date,
        'start_time', to_char(p_post.start_time, 'HH24:MI'),
        'end_time', to_char(p_post.end_time, 'HH24:MI'),
        'service_number', p_post.service_number,
        'line_code', p_post.line_code,
        'vehicle_code', p_post.vehicle_code,
        'service_label', p_post.service_label,
        'message', p_post.message,
        'title', p_post.title,
        'status', p_post.status,
        'visibility', p_post.visibility,
        'expires_at', p_post.expires_at,
        'is_urgent', p_post.is_urgent,
        'contact_count', p_post.contact_count,
        'view_count', p_post.view_count,
        'resolved_at', p_post.resolved_at,
        'resource_id', p_post.resource_id,
        'author_display_name', p_post.author_display_name,
        'author_avatar_url', p_post.author_avatar_url,
        'created_at', p_post.created_at,
        'updated_at', p_post.updated_at,
        'is_mine', (p_post.author_id = p_viewer),
        'is_favorited', EXISTS (
            SELECT 1 FROM public.service_exchange_favorites f
            WHERE f.post_id = p_post.id AND f.user_id = p_viewer
        ),
        'my_reaction', (
            SELECT r.reaction FROM public.service_exchange_reactions r
            WHERE r.post_id = p_post.id AND r.user_id = p_viewer LIMIT 1
        ),
        'reaction_likes', (
            SELECT count(*) FROM public.service_exchange_reactions r
            WHERE r.post_id = p_post.id AND r.reaction = 'like'
        ),
        'reaction_seen', (
            SELECT count(*) FROM public.service_exchange_reactions r
            WHERE r.post_id = p_post.id AND r.reaction = 'seen'
        ),
        'is_new', (p_post.created_at > NOW() - INTERVAL '24 hours'),
        'is_expiring_soon', (
            p_post.expires_at IS NOT NULL
            AND p_post.expires_at < NOW() + INTERVAL '12 hours'
            AND p_post.expires_at > NOW()
        ),
        'is_resolved', (p_post.status = 'agreed'),
        'can_relance', (
            p_post.author_id = p_viewer
            AND p_post.status = 'active'
            AND p_post.contact_count = 0
            AND COALESCE(p_post.relanced_at, p_post.created_at) < NOW() - INTERVAL '24 hours'
        )
    );
$$;

-- ===========================================================================
-- 5. RPC — création / édition
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.create_service_exchange_post(
    p_post_kind TEXT,
    p_service_type TEXT,
    p_service_date DATE,
    p_start_time TIME,
    p_end_time TIME,
    p_service_number TEXT DEFAULT NULL,
    p_line_code TEXT DEFAULT NULL,
    p_vehicle_code TEXT DEFAULT NULL,
    p_message TEXT DEFAULT NULL,
    p_is_urgent BOOLEAN DEFAULT FALSE,
    p_expires_at TIMESTAMPTZ DEFAULT NULL,
    p_network_code TEXT DEFAULT 'naolib'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_driver public.drivers%ROWTYPE;
    v_depot_name TEXT;
    v_title TEXT;
    v_required TEXT;
    v_resource_id UUID;
    v_post_id UUID;
    v_post public.service_exchange_posts%ROWTYPE;
BEGIN
    IF v_user IS NULL THEN
        RAISE EXCEPTION 'Session invalide';
    END IF;

    SELECT * INTO v_driver FROM public.drivers
     WHERE user_id = v_user
        OR lower(email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
     LIMIT 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fiche conducteur introuvable';
    END IF;

    IF p_end_time <= p_start_time THEN
        RAISE EXCEPTION 'L''heure de fin doit être après l''heure de début';
    END IF;

    -- Limite : 1 annonce urgente / 24 h.
    IF p_is_urgent AND EXISTS (
        SELECT 1 FROM public.service_exchange_posts
        WHERE author_id = v_user AND is_urgent
          AND created_at > NOW() - INTERVAL '24 hours'
    ) THEN
        RAISE EXCEPTION 'urgent_rate_limited';
    END IF;

    SELECT name INTO v_depot_name FROM public.depots WHERE id = v_driver.depot_id;
    v_required := public.se_deduce_required_habilitation(p_service_type);
    v_title := public.se_generate_title(
        p_post_kind, p_service_type,
        CASE WHEN p_post_kind = 'request' THEN p_service_number ELSE NULL END,
        CASE WHEN p_post_kind = 'request' THEN p_line_code ELSE NULL END,
        p_service_date
    );

    -- L'annonce devient une ressource platform (objet de première classe).
    INSERT INTO public.resources (type, external_id, name, status, lifecycle)
    VALUES ('service_exchange', NULL, v_title, 'active', 'temporary')
    RETURNING id INTO v_resource_id;

    INSERT INTO public.service_exchange_posts (
        author_id, author_driver_id, network_code, depot_id, depot_name,
        profile_type, post_kind, service_type, required_habilitation,
        service_date, start_time, end_time,
        service_number, line_code, vehicle_code, message,
        title, status, is_urgent, expires_at, resource_id,
        author_display_name, author_avatar_url
    ) VALUES (
        v_user, v_driver.id, p_network_code, v_driver.depot_id, v_depot_name,
        'reseau', p_post_kind, p_service_type, v_required,
        p_service_date, p_start_time, p_end_time,
        CASE WHEN p_post_kind = 'request' THEN NULLIF(btrim(p_service_number), '') ELSE NULL END,
        CASE WHEN p_post_kind = 'request' THEN NULLIF(btrim(p_line_code), '') ELSE NULL END,
        CASE WHEN p_post_kind = 'request' THEN NULLIF(btrim(p_vehicle_code), '') ELSE NULL END,
        NULLIF(btrim(p_message), ''),
        v_title, 'active', p_is_urgent, p_expires_at, v_resource_id,
        NULLIF(btrim(coalesce(v_driver.first_name, '') || ' ' || coalesce(v_driver.last_name, '')), ''),
        v_driver.avatar_url
    )
    RETURNING id INTO v_post_id;

    UPDATE public.resources SET external_id = v_post_id::text WHERE id = v_resource_id;

    -- Timeline : événement « publiée » (global).
    INSERT INTO public.resource_events (resource_id, channel_id, event_type, actor_id, payload, priority)
    VALUES (v_resource_id, NULL, 'published', v_user,
            jsonb_build_object('title', v_title), 'normal');

    PERFORM public.se_notify_compatible(
        v_post_id, CASE WHEN p_is_urgent THEN 'urgent' ELSE 'created' END,
        CASE WHEN p_is_urgent THEN 'high' ELSE 'normal' END
    );

    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = v_post_id;
    RETURN public.se_post_json(v_post, v_user, ARRAY[]::text[]);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_service_exchange_post(
    p_post_id UUID,
    p_service_date DATE DEFAULT NULL,
    p_start_time TIME DEFAULT NULL,
    p_end_time TIME DEFAULT NULL,
    p_service_number TEXT DEFAULT NULL,
    p_line_code TEXT DEFAULT NULL,
    p_vehicle_code TEXT DEFAULT NULL,
    p_message TEXT DEFAULT NULL,
    p_is_urgent BOOLEAN DEFAULT NULL,
    p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_post public.service_exchange_posts%ROWTYPE;
    v_title TEXT;
    v_changes TEXT[] := ARRAY[]::text[];
    v_notice TEXT;
    v_ctx RECORD;
BEGIN
    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Annonce introuvable'; END IF;
    IF v_post.author_id <> v_user THEN RAISE EXCEPTION 'Action réservée à l''auteur'; END IF;

    IF p_service_date IS NOT NULL AND p_service_date <> v_post.service_date THEN
        v_changes := array_append(v_changes, 'date');
    END IF;
    IF (p_start_time IS NOT NULL AND p_start_time <> v_post.start_time)
       OR (p_end_time IS NOT NULL AND p_end_time <> v_post.end_time) THEN
        v_changes := array_append(v_changes, 'horaires');
    END IF;
    IF p_service_number IS NOT NULL
       AND NULLIF(btrim(p_service_number), '') IS DISTINCT FROM v_post.service_number THEN
        v_changes := array_append(v_changes, 'numéro de service');
    END IF;

    UPDATE public.service_exchange_posts SET
        service_date   = COALESCE(p_service_date, service_date),
        start_time     = COALESCE(p_start_time, start_time),
        end_time       = COALESCE(p_end_time, end_time),
        service_number = COALESCE(NULLIF(btrim(p_service_number), ''), service_number),
        line_code      = COALESCE(NULLIF(btrim(p_line_code), ''), line_code),
        vehicle_code   = COALESCE(NULLIF(btrim(p_vehicle_code), ''), vehicle_code),
        message        = COALESCE(NULLIF(btrim(p_message), ''), message),
        is_urgent      = COALESCE(p_is_urgent, is_urgent),
        expires_at     = COALESCE(p_expires_at, expires_at),
        updated_at     = NOW()
    WHERE id = p_post_id
    RETURNING * INTO v_post;

    v_title := public.se_generate_title(
        v_post.post_kind, v_post.service_type,
        v_post.service_number, v_post.line_code, v_post.service_date
    );
    UPDATE public.service_exchange_posts SET title = v_title WHERE id = p_post_id;
    UPDATE public.resources SET name = v_title, updated_at = NOW() WHERE id = v_post.resource_id;

    -- Avis de modification : timeline globale + message in-chat par conversation.
    IF array_length(v_changes, 1) IS NOT NULL THEN
        INSERT INTO public.resource_events (resource_id, channel_id, event_type, actor_id, payload, priority)
        VALUES (v_post.resource_id, NULL, 'modified', v_user,
                jsonb_build_object('changes', v_changes), 'normal');

        v_notice := CASE
            WHEN 'horaires' = ANY(v_changes) THEN 'L''auteur a modifié les horaires de cette annonce.'
            WHEN 'numéro de service' = ANY(v_changes) THEN 'Le numéro de service a été ajouté.'
            ELSE 'L''auteur a modifié cette annonce.'
        END;

        FOR v_ctx IN
            SELECT channel_id FROM public.conversation_contexts
            WHERE context_type = 'service_exchange' AND context_id = p_post_id
        LOOP
            INSERT INTO public.messages (channel_id, sender_id, message_type, body, metadata)
            VALUES (v_ctx.channel_id, v_user, 'text', v_notice,
                    jsonb_build_object('system', true, 'kind', 'modified'));
        END LOOP;
    END IF;

    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    RETURN public.se_post_json(v_post, v_user, ARRAY[]::text[]);
END;
$$;

-- ===========================================================================
-- 6. RPC — lecture du feed
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.list_service_exchange_feed(
    p_view TEXT DEFAULT 'available',
    p_network_code TEXT DEFAULT 'naolib',
    p_habilitations TEXT[] DEFAULT ARRAY[]::text[],
    p_service_type TEXT DEFAULT NULL,
    p_service_date DATE DEFAULT NULL,
    p_post_kind TEXT DEFAULT NULL,
    p_search TEXT DEFAULT NULL,
    p_mine_filter TEXT DEFAULT 'active'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_driver public.drivers%ROWTYPE;
    v_result JSONB;
BEGIN
    PERFORM public.se_expire_posts();

    SELECT * INTO v_driver FROM public.drivers
     WHERE user_id = v_user
        OR lower(email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
     LIMIT 1;

    IF p_view = 'mine' THEN
        SELECT COALESCE(jsonb_agg(public.se_post_json(p, v_user, p_habilitations)
                 ORDER BY p.bumped_at DESC), '[]'::jsonb)
          INTO v_result
          FROM public.service_exchange_posts p
         WHERE p.author_id = v_user
           AND (
                (p_mine_filter = 'active' AND p.status IN ('active', 'in_discussion'))
             OR (p_mine_filter = 'done' AND p.status = 'agreed')
             OR (p_mine_filter = 'cancelled' AND p.status IN ('cancelled', 'expired'))
             OR (p_mine_filter NOT IN ('active', 'done', 'cancelled'))
           );
        RETURN v_result;
    END IF;

    IF p_view = 'received_contacts' THEN
        SELECT COALESCE(jsonb_agg(public.se_post_json(p, v_user, p_habilitations)
                 ORDER BY p.contact_count DESC, p.bumped_at DESC), '[]'::jsonb)
          INTO v_result
          FROM public.service_exchange_posts p
         WHERE p.author_id = v_user
           AND p.contact_count > 0;
        RETURN v_result;
    END IF;

    -- available : annonces compatibles, hors auteur.
    SELECT COALESCE(jsonb_agg(public.se_post_json(p, v_user, p_habilitations)
             ORDER BY p.is_urgent DESC, p.service_date ASC,
                      p.expires_at ASC NULLS LAST, p.bumped_at DESC), '[]'::jsonb)
      INTO v_result
      FROM public.service_exchange_posts p
     WHERE p.author_id <> v_user
       AND p.visibility = 'public'
       AND p.network_code = p_network_code
       AND v_driver.depot_id IS NOT NULL
       AND p.depot_id = v_driver.depot_id
       AND (
            p.status IN ('active', 'in_discussion')
         OR (p.status = 'agreed' AND p.resolved_at > NOW() - INTERVAL '3 days')
       )
       AND (
            p.required_habilitation = ANY(p_habilitations)
         OR (p.required_habilitation = 'controle' AND v_driver.msr_control)
         OR (p.required_habilitation = 'intervention' AND v_driver.msr_intervention)
       )
       AND (p_service_type IS NULL OR p.service_type = p_service_type)
       AND (p_service_date IS NULL OR p.service_date = p_service_date)
       AND (p_post_kind IS NULL OR p.post_kind = p_post_kind)
       AND (
            p_search IS NULL OR btrim(p_search) = ''
         OR p.title ILIKE '%' || p_search || '%'
         OR COALESCE(p.line_code, '') ILIKE '%' || p_search || '%'
         OR COALESCE(p.service_number, '') ILIKE '%' || p_search || '%'
         OR COALESCE(p.message, '') ILIKE '%' || p_search || '%'
       );

    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_service_exchange_post(
    p_post_id UUID,
    p_habilitations TEXT[] DEFAULT ARRAY[]::text[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_post public.service_exchange_posts%ROWTYPE;
BEGIN
    PERFORM public.se_expire_posts();
    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RETURN NULL; END IF;
    RETURN public.se_post_json(v_post, v_user, p_habilitations);
END;
$$;

CREATE OR REPLACE FUNCTION public.list_similar_service_exchange_posts(
    p_post_id UUID,
    p_network_code TEXT DEFAULT 'naolib',
    p_habilitations TEXT[] DEFAULT ARRAY[]::text[],
    p_limit INT DEFAULT 5
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_src public.service_exchange_posts%ROWTYPE;
    v_result JSONB;
BEGIN
    SELECT * INTO v_src FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RETURN '[]'::jsonb; END IF;

    SELECT COALESCE(jsonb_agg(public.se_post_json(p, v_user, p_habilitations)
             ORDER BY p.is_urgent DESC, p.service_date ASC, p.bumped_at DESC), '[]'::jsonb)
      INTO v_result
      FROM (
        SELECT * FROM public.service_exchange_posts p2
         WHERE p2.id <> p_post_id
           AND p2.author_id <> v_user
           AND p2.visibility = 'public'
           AND p2.depot_id = v_src.depot_id
           AND p2.network_code = v_src.network_code
           AND p2.status IN ('active', 'in_discussion')
           AND p2.required_habilitation = v_src.required_habilitation
         LIMIT p_limit
      ) p;

    RETURN v_result;
END;
$$;

-- ===========================================================================
-- 7. RPC — vues / réactions / favoris
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.record_service_exchange_view(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_author UUID;
    v_rows INT := 0;
BEGIN
    SELECT author_id INTO v_author FROM public.service_exchange_posts WHERE id = p_post_id;
    IF v_author IS NULL OR v_author = v_user THEN RETURN; END IF;

    INSERT INTO public.service_exchange_views (post_id, viewer_id)
    VALUES (p_post_id, v_user)
    ON CONFLICT DO NOTHING;
    GET DIAGNOSTICS v_rows = ROW_COUNT;

    IF v_rows > 0 THEN
        UPDATE public.service_exchange_posts
           SET view_count = view_count + 1 WHERE id = p_post_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.toggle_service_exchange_reaction(
    p_post_id UUID,
    p_reaction TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_post public.service_exchange_posts%ROWTYPE;
    v_exists BOOLEAN;
BEGIN
    IF p_reaction NOT IN ('like', 'seen') THEN
        RAISE EXCEPTION 'Réaction invalide';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.service_exchange_reactions
        WHERE post_id = p_post_id AND user_id = v_user AND reaction = p_reaction
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.service_exchange_reactions
        WHERE post_id = p_post_id AND user_id = v_user AND reaction = p_reaction;
    ELSE
        DELETE FROM public.service_exchange_reactions
        WHERE post_id = p_post_id AND user_id = v_user;
        INSERT INTO public.service_exchange_reactions (post_id, user_id, reaction)
        VALUES (p_post_id, v_user, p_reaction);
    END IF;

    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    RETURN public.se_post_json(v_post, v_user, ARRAY[]::text[]);
END;
$$;

CREATE OR REPLACE FUNCTION public.toggle_service_exchange_favorite(p_post_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_exists BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.service_exchange_favorites
        WHERE post_id = p_post_id AND user_id = v_user
    ) INTO v_exists;

    IF v_exists THEN
        DELETE FROM public.service_exchange_favorites
        WHERE post_id = p_post_id AND user_id = v_user;
        RETURN FALSE;
    ELSE
        INSERT INTO public.service_exchange_favorites (post_id, user_id)
        VALUES (p_post_id, v_user) ON CONFLICT DO NOTHING;
        RETURN TRUE;
    END IF;
END;
$$;

-- ===========================================================================
-- 8. RPC — contact (annonce ↔ conversation) & messagerie générique
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.record_service_exchange_contact(p_post_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_post public.service_exchange_posts%ROWTYPE;
    v_channel_id UUID;
BEGIN
    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Annonce introuvable'; END IF;
    IF v_post.author_id = v_user THEN RAISE EXCEPTION 'Vous êtes l''auteur de cette annonce'; END IF;

    v_channel_id := public.get_or_create_direct_channel(v_post.author_id);

    -- Lien générique canal ↔ contexte (annonce).
    INSERT INTO public.conversation_contexts (channel_id, context_type, context_id, role)
    VALUES (v_channel_id, 'service_exchange', p_post_id, 'negotiation')
    ON CONFLICT (channel_id, context_type, context_id) DO NOTHING;

    -- Passage en discussion.
    UPDATE public.service_exchange_posts
       SET status = 'in_discussion', updated_at = NOW()
     WHERE id = p_post_id AND status = 'active';

    -- Timeline : « contacté » scellé au canal (confidentialité 1:1).
    INSERT INTO public.resource_events (resource_id, channel_id, event_type, actor_id, payload, priority)
    VALUES (v_post.resource_id, v_channel_id, 'contacted', v_user, '{}'::jsonb, 'normal');

    RETURN jsonb_build_object('channel_id', v_channel_id, 'title', v_post.title);
END;
$$;

-- Générique : contextes d'un canal (rendu piloté par context_type côté client).
CREATE OR REPLACE FUNCTION public.get_conversation_context(p_channel_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_is_member BOOLEAN;
    v_result JSONB;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.channel_members
        WHERE channel_id = p_channel_id AND user_id = v_user AND status = 'active'
    ) INTO v_is_member;
    IF NOT v_is_member THEN RETURN '[]'::jsonb; END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'context_type', cc.context_type,
            'context_id', cc.context_id,
            'role', cc.role,
            'payload', CASE
                WHEN cc.context_type = 'service_exchange' THEN
                    public.se_post_json(p, v_user, ARRAY[]::text[])
                ELSE NULL
            END
        )
    ), '[]'::jsonb)
      INTO v_result
      FROM public.conversation_contexts cc
      LEFT JOIN public.service_exchange_posts p
        ON cc.context_type = 'service_exchange' AND p.id = cc.context_id
     WHERE cc.channel_id = p_channel_id;

    RETURN v_result;
END;
$$;

-- Générique : timeline d'une conversation (events scellés par canal).
CREATE OR REPLACE FUNCTION public.get_conversation_timeline(p_channel_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_is_member BOOLEAN;
    v_result JSONB;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM public.channel_members
        WHERE channel_id = p_channel_id AND user_id = v_user AND status = 'active'
    ) INTO v_is_member;
    IF NOT v_is_member THEN RETURN '[]'::jsonb; END IF;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'event_type', e.event_type,
            'actor_display', public.driver_display_name(
                (SELECT id FROM public.drivers WHERE user_id = e.actor_id LIMIT 1)
            ),
            'payload', e.payload,
            'created_at', e.created_at
        ) ORDER BY e.created_at ASC
    ), '[]'::jsonb)
      INTO v_result
      FROM public.resource_events e
     WHERE e.resource_id IN (
            SELECT p.resource_id FROM public.conversation_contexts cc
            JOIN public.service_exchange_posts p ON p.id = cc.context_id
            WHERE cc.channel_id = p_channel_id AND cc.context_type = 'service_exchange'
       )
       AND e.event_type <> 'message'
       AND (e.channel_id IS NULL OR e.channel_id = p_channel_id);

    RETURN v_result;
END;
$$;

-- ===========================================================================
-- 9. RPC — statut / relance / clôture / suppression
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.update_service_exchange_post_status(
    p_post_id UUID,
    p_status TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_post public.service_exchange_posts%ROWTYPE;
BEGIN
    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Annonce introuvable'; END IF;
    IF v_post.author_id <> v_user THEN RAISE EXCEPTION 'Action réservée à l''auteur'; END IF;
    IF p_status NOT IN ('active', 'in_discussion', 'agreed', 'cancelled') THEN
        RAISE EXCEPTION 'Statut invalide';
    END IF;

    UPDATE public.service_exchange_posts SET
        status = p_status,
        resolved_at = CASE WHEN p_status = 'agreed' THEN NOW() ELSE resolved_at END,
        updated_at = NOW()
    WHERE id = p_post_id
    RETURNING * INTO v_post;

    IF p_status = 'agreed' THEN
        INSERT INTO public.resource_events (resource_id, channel_id, event_type, actor_id, payload, priority)
        VALUES (v_post.resource_id, NULL, 'resolved', v_user, '{}'::jsonb, 'normal');
    ELSIF p_status = 'cancelled' THEN
        INSERT INTO public.resource_events (resource_id, channel_id, event_type, actor_id, payload, priority)
        VALUES (v_post.resource_id, NULL, 'cancelled', v_user, '{}'::jsonb, 'normal');
    END IF;

    UPDATE public.resources SET status =
        CASE WHEN p_status IN ('agreed', 'cancelled') THEN 'closed' ELSE 'active' END
     WHERE id = v_post.resource_id;

    RETURN public.se_post_json(v_post, v_user, ARRAY[]::text[]);
END;
$$;

CREATE OR REPLACE FUNCTION public.relance_service_exchange_post(p_post_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_post public.service_exchange_posts%ROWTYPE;
BEGIN
    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Annonce introuvable'; END IF;
    IF v_post.author_id <> v_user THEN RAISE EXCEPTION 'Action réservée à l''auteur'; END IF;
    IF v_post.status <> 'active' THEN RAISE EXCEPTION 'Seule une annonce active peut être relancée'; END IF;
    IF COALESCE(v_post.relanced_at, v_post.created_at) > NOW() - INTERVAL '24 hours' THEN
        RAISE EXCEPTION 'relance_rate_limited';
    END IF;

    UPDATE public.service_exchange_posts
       SET bumped_at = NOW(), relanced_at = NOW(), updated_at = NOW()
     WHERE id = p_post_id
     RETURNING * INTO v_post;

    INSERT INTO public.resource_events (resource_id, channel_id, event_type, actor_id, payload, priority)
    VALUES (v_post.resource_id, NULL, 'relanced', v_user, '{}'::jsonb, 'normal');

    PERFORM public.se_notify_compatible(p_post_id, 'relanced', 'normal');

    RETURN public.se_post_json(v_post, v_user, ARRAY[]::text[]);
END;
$$;

CREATE OR REPLACE FUNCTION public.close_service_exchange_discussions(
    p_post_id UUID,
    p_message TEXT DEFAULT 'Cette annonce a été clôturée par son auteur. Merci pour votre intérêt.'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_post public.service_exchange_posts%ROWTYPE;
    v_ctx RECORD;
BEGIN
    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'Annonce introuvable'; END IF;
    IF v_post.author_id <> v_user THEN RAISE EXCEPTION 'Action réservée à l''auteur'; END IF;

    FOR v_ctx IN
        SELECT channel_id FROM public.conversation_contexts
        WHERE context_type = 'service_exchange' AND context_id = p_post_id
    LOOP
        INSERT INTO public.messages (channel_id, sender_id, message_type, body, metadata)
        VALUES (v_ctx.channel_id, v_user, 'text', p_message,
                jsonb_build_object('system', true, 'kind', 'closed'));
    END LOOP;

    INSERT INTO public.resource_events (resource_id, channel_id, event_type, actor_id, payload, priority)
    VALUES (v_post.resource_id, NULL, 'closed', v_user, '{}'::jsonb, 'normal');
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_service_exchange_post(p_post_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_post public.service_exchange_posts%ROWTYPE;
BEGIN
    SELECT * INTO v_post FROM public.service_exchange_posts WHERE id = p_post_id;
    IF NOT FOUND THEN RETURN; END IF;
    IF v_post.author_id <> v_user THEN RAISE EXCEPTION 'Action réservée à l''auteur'; END IF;

    DELETE FROM public.service_exchange_posts WHERE id = p_post_id;
    IF v_post.resource_id IS NOT NULL THEN
        UPDATE public.resources SET status = 'deleted' WHERE id = v_post.resource_id;
    END IF;
END;
$$;

-- ===========================================================================
-- 10. RPC — fiche profil & statistiques
-- ===========================================================================
CREATE OR REPLACE FUNCTION public.get_service_exchange_author_profile(p_author_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_driver public.drivers%ROWTYPE;
    v_depot_name TEXT;
    v_habs TEXT[] := ARRAY['conduite'];
    v_count INT;
BEGIN
    SELECT * INTO v_driver FROM public.drivers WHERE user_id = p_author_id LIMIT 1;
    IF NOT FOUND THEN RETURN NULL; END IF;

    SELECT name INTO v_depot_name FROM public.depots WHERE id = v_driver.depot_id;
    IF v_driver.msr_control THEN v_habs := array_append(v_habs, 'controle'); END IF;
    IF v_driver.msr_intervention THEN v_habs := array_append(v_habs, 'intervention'); END IF;

    SELECT count(*) INTO v_count FROM public.service_exchange_posts
     WHERE author_id = p_author_id AND status = 'agreed';

    RETURN jsonb_build_object(
        'display_name', NULLIF(btrim(coalesce(v_driver.first_name, '') || ' ' || coalesce(v_driver.last_name, '')), ''),
        'avatar_url', v_driver.avatar_url,
        'role_label', 'Conducteur',
        'depot_name', v_depot_name,
        'habilitations', to_jsonb(v_habs),
        'member_since_year', EXTRACT(YEAR FROM v_driver.created_at)::int,
        'exchanges_done', v_count
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.service_exchange_daily_stats(
    p_network_code TEXT DEFAULT 'naolib'
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user UUID := auth.uid();
    v_driver public.drivers%ROWTYPE;
BEGIN
    SELECT * INTO v_driver FROM public.drivers
     WHERE user_id = v_user
        OR lower(email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
     LIMIT 1;

    RETURN jsonb_build_object(
        'active_count', (
            SELECT count(*) FROM public.service_exchange_posts
            WHERE status IN ('active', 'in_discussion')
              AND depot_id = v_driver.depot_id),
        'agreed_today_count', (
            SELECT count(*) FROM public.service_exchange_posts
            WHERE status = 'agreed'
              AND depot_id = v_driver.depot_id
              AND resolved_at::date = CURRENT_DATE),
        'urgent_count', (
            SELECT count(*) FROM public.service_exchange_posts
            WHERE status IN ('active', 'in_discussion')
              AND is_urgent
              AND depot_id = v_driver.depot_id)
    );
END;
$$;

-- ===========================================================================
-- 11. RLS
-- ===========================================================================
ALTER TABLE public.conversation_contexts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_exchange_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_exchange_favorites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_exchange_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_exchange_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_exchange_notifications_sent ENABLE ROW LEVEL SECURITY;

-- conversation_contexts : lecture par membre du canal (écriture via RPC definer).
DROP POLICY IF EXISTS conversation_contexts_select ON public.conversation_contexts;
CREATE POLICY conversation_contexts_select ON public.conversation_contexts
    FOR SELECT TO authenticated
    USING (public.is_active_channel_member(channel_id) OR public.is_staff());

-- posts : auteur, ou même dépôt (défense en profondeur ; le feed passe par RPC).
DROP POLICY IF EXISTS se_posts_select ON public.service_exchange_posts;
CREATE POLICY se_posts_select ON public.service_exchange_posts
    FOR SELECT TO authenticated
    USING (
        author_id = auth.uid()
        OR public.is_staff()
        OR EXISTS (
            SELECT 1 FROM public.drivers d
            WHERE d.user_id = auth.uid()
              AND d.depot_id = service_exchange_posts.depot_id
        )
    );

DROP POLICY IF EXISTS se_posts_update ON public.service_exchange_posts;
CREATE POLICY se_posts_update ON public.service_exchange_posts
    FOR UPDATE TO authenticated
    USING (author_id = auth.uid())
    WITH CHECK (author_id = auth.uid());

DROP POLICY IF EXISTS se_posts_delete ON public.service_exchange_posts;
CREATE POLICY se_posts_delete ON public.service_exchange_posts
    FOR DELETE TO authenticated
    USING (author_id = auth.uid());

-- favoris / réactions / vues : chacun gère les siens.
DROP POLICY IF EXISTS se_favorites_all ON public.service_exchange_favorites;
CREATE POLICY se_favorites_all ON public.service_exchange_favorites
    FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS se_reactions_all ON public.service_exchange_reactions;
CREATE POLICY se_reactions_all ON public.service_exchange_reactions
    FOR ALL TO authenticated
    USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS se_views_all ON public.service_exchange_views;
CREATE POLICY se_views_all ON public.service_exchange_views
    FOR ALL TO authenticated
    USING (viewer_id = auth.uid()) WITH CHECK (viewer_id = auth.uid());

-- ===========================================================================
-- 12. GRANTS
-- ===========================================================================
GRANT EXECUTE ON FUNCTION public.create_service_exchange_post(TEXT, TEXT, DATE, TIME, TIME, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_service_exchange_post(UUID, DATE, TIME, TIME, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_service_exchange_feed(TEXT, TEXT, TEXT[], TEXT, DATE, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_service_exchange_post(UUID, TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_similar_service_exchange_posts(UUID, TEXT, TEXT[], INT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_service_exchange_view(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_service_exchange_contact(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_conversation_context(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_conversation_timeline(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_service_exchange_reaction(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_service_exchange_favorite(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.relance_service_exchange_post(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_service_exchange_post_status(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_service_exchange_discussions(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_service_exchange_post(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_service_exchange_author_profile(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.service_exchange_daily_stats(TEXT) TO authenticated;

-- ===========================================================================
-- 13. Réplication temps réel
-- ===========================================================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.service_exchange_posts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
