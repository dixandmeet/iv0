-- Framework métier Aule — resources, Hub collaboratif, RBAC plateforme
-- Architecture v8 FINALE (Phase 1 — schema gelé)

-- ---------------------------------------------------------------------------
-- Extensions profils
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_profiles
    ADD COLUMN IF NOT EXISTS is_bot BOOLEAN NOT NULL DEFAULT false;

-- ---------------------------------------------------------------------------
-- 1. resources — centre plateforme
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.resources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL,
    name TEXT NOT NULL,
    external_id TEXT,
    parent_resource_id UUID REFERENCES public.resources(id) ON DELETE SET NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'paused', 'closed', 'archived', 'deleted')),
    lifecycle TEXT NOT NULL DEFAULT 'permanent'
        CHECK (lifecycle IN ('permanent', 'temporary')),
    context JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_resources_type_external
    ON public.resources (type, external_id)
    WHERE external_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_resources_parent
    ON public.resources (parent_resource_id);

CREATE INDEX IF NOT EXISTS idx_resources_type_status
    ON public.resources (type, status);

-- ---------------------------------------------------------------------------
-- 2. resource_relations — graphe métier
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.resource_relations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_resource_id UUID NOT NULL REFERENCES public.resources(id) ON DELETE CASCADE,
    target_resource_id UUID NOT NULL REFERENCES public.resources(id) ON DELETE CASCADE,
    relation_type TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source_resource_id, target_resource_id, relation_type)
);

CREATE INDEX IF NOT EXISTS idx_resource_relations_source
    ON public.resource_relations (source_resource_id);

CREATE INDEX IF NOT EXISTS idx_resource_relations_target
    ON public.resource_relations (target_resource_id);

-- ---------------------------------------------------------------------------
-- 3. resource_capabilities
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.resource_capabilities (
    resource_type TEXT NOT NULL,
    capability TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT true,
    config JSONB NOT NULL DEFAULT '{}'::jsonb,
    inherits_from TEXT,
    PRIMARY KEY (resource_type, capability)
);

-- ---------------------------------------------------------------------------
-- 4. resource_watchers
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.resource_watchers (
    resource_id UUID NOT NULL REFERENCES public.resources(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    mode TEXT NOT NULL DEFAULT 'all'
        CHECK (mode IN ('all', 'important', 'silent')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (resource_id, user_id)
);

-- ---------------------------------------------------------------------------
-- 5. RBAC plateforme
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL,
    scope TEXT NOT NULL DEFAULT 'channel'
        CHECK (scope IN ('platform', 'channel')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS public.role_permissions (
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES public.permissions(id) ON DELETE CASCADE,
    PRIMARY KEY (role_id, permission_id)
);

-- ---------------------------------------------------------------------------
-- 6. channels — vue discussion (1:1 resource)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.channels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id UUID UNIQUE REFERENCES public.resources(id) ON DELETE CASCADE,
    parent_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    type TEXT NOT NULL DEFAULT 'discussion',
    subtype TEXT,
    mode TEXT NOT NULL DEFAULT 'normal'
        CHECK (mode IN ('normal', 'announcement', 'readonly')),
    creation_mode TEXT NOT NULL DEFAULT 'manual'
        CHECK (creation_mode IN ('manual', 'automatic')),
    name TEXT,
    avatar_url TEXT,
    created_by UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_channels_parent
    ON public.channels (parent_channel_id);

-- ---------------------------------------------------------------------------
-- 7. direct_channels — DM
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.direct_channels (
    channel_id UUID PRIMARY KEY REFERENCES public.channels(id) ON DELETE CASCADE,
    user_low UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    user_high UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    UNIQUE (user_low, user_high)
);

-- ---------------------------------------------------------------------------
-- 8. channel_members
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.channel_members (
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'left', 'removed', 'blocked')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_read_at TIMESTAMPTZ,
    draft TEXT,
    is_favorite BOOLEAN NOT NULL DEFAULT false,
    is_muted BOOLEAN NOT NULL DEFAULT false,
    is_archived BOOLEAN NOT NULL DEFAULT false,
    PRIMARY KEY (channel_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_channel_members_user
    ON public.channel_members (user_id, status);

-- ---------------------------------------------------------------------------
-- 9. member_roles
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.member_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
    channel_id UUID REFERENCES public.channels(id) ON DELETE CASCADE,
    resource_id UUID REFERENCES public.resources(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (channel_id IS NOT NULL OR resource_id IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_member_roles_channel_user_role
    ON public.member_roles (channel_id, user_id, role_id)
    WHERE channel_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 10. resource_events — événements unifiés
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.resource_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id UUID NOT NULL REFERENCES public.resources(id) ON DELETE CASCADE,
    channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    actor_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    priority TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('low', 'normal', 'high', 'critical')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_resource_events_resource_time
    ON public.resource_events (resource_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_resource_events_channel_time
    ON public.resource_events (channel_id, created_at DESC)
    WHERE channel_id IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 11. messages
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    message_type TEXT NOT NULL DEFAULT 'text'
        CHECK (message_type IN ('text', 'location', 'document', 'task', 'entity', 'image')),
    body TEXT NOT NULL DEFAULT '',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    linked_entity_type TEXT,
    linked_entity_id TEXT,
    priority TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('low', 'normal', 'high', 'critical')),
    reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    search_vector TSVECTOR GENERATED ALWAYS AS (
        to_tsvector('french', coalesce(body, ''))
    ) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    edited_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_messages_channel_time
    ON public.messages (channel_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_messages_search
    ON public.messages USING gin (search_vector);

-- ---------------------------------------------------------------------------
-- 12. Satellites discussion
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.message_mentions (
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    mention_type TEXT NOT NULL CHECK (mention_type IN ('user', 'channel', 'business_role')),
    target_id TEXT NOT NULL,
    PRIMARY KEY (message_id, mention_type, target_id)
);

CREATE TABLE IF NOT EXISTS public.message_reactions (
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    PRIMARY KEY (message_id, user_id, emoji)
);

CREATE TABLE IF NOT EXISTS public.pinned_messages (
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    pinned_by UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (channel_id, message_id)
);

CREATE TABLE IF NOT EXISTS public.channel_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    resource_id UUID REFERENCES public.resources(id) ON DELETE SET NULL,
    uploaded_by UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    file_url TEXT NOT NULL,
    mime_type TEXT,
    size_bytes BIGINT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_channel_files_channel
    ON public.channel_files (channel_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.channel_tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    resource_id UUID REFERENCES public.resources(id) ON DELETE SET NULL,
    source_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    assigned_to UUID REFERENCES public.user_profiles(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'assigned'
        CHECK (status IN ('assigned', 'in_progress', 'completed')),
    created_by UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_channel_tasks_channel
    ON public.channel_tasks (channel_id, status);

-- ---------------------------------------------------------------------------
-- 13. user_notifications — projections
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    category TEXT NOT NULL CHECK (category IN ('message', 'activity', 'alert')),
    source_type TEXT NOT NULL,
    source_id UUID,
    resource_id UUID REFERENCES public.resources(id) ON DELETE SET NULL,
    channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    body TEXT,
    priority TEXT NOT NULL DEFAULT 'normal'
        CHECK (priority IN ('low', 'normal', 'high', 'critical')),
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_notifications_user_time
    ON public.user_notifications (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_notifications_unread
    ON public.user_notifications (user_id)
    WHERE read_at IS NULL;

-- ---------------------------------------------------------------------------
-- 14. panel_layouts — registry déclaratif
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.panel_layouts (
    resource_type TEXT PRIMARY KEY,
    layout JSONB NOT NULL
);

-- ---------------------------------------------------------------------------
-- Helpers RBAC / membership
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_active_channel_member(p_channel_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.channel_members cm
        WHERE cm.channel_id = p_channel_id
          AND cm.user_id = auth.uid()
          AND cm.status = 'active'
    );
$$;

CREATE OR REPLACE FUNCTION public.user_has_channel_permission(
    p_channel_id UUID,
    p_permission_key TEXT
)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT public.is_staff()
        OR EXISTS (
            SELECT 1
            FROM public.member_roles mr
            JOIN public.role_permissions rp ON rp.role_id = mr.role_id
            JOIN public.permissions p ON p.id = rp.permission_id
            WHERE mr.channel_id = p_channel_id
              AND mr.user_id = auth.uid()
              AND p.key = p_permission_key
        );
$$;

CREATE OR REPLACE FUNCTION public.resource_allows_write(p_resource_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.resources r
        WHERE r.id = p_resource_id
          AND r.status IN ('active', 'paused')
    );
$$;

GRANT EXECUTE ON FUNCTION public.is_active_channel_member(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_channel_permission(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.resource_allows_write(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- Trigger : message → resource_event
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.on_message_insert_event()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_resource_id UUID;
BEGIN
    SELECT c.resource_id INTO v_resource_id
    FROM public.channels c
    WHERE c.id = NEW.channel_id;

    IF v_resource_id IS NOT NULL THEN
        INSERT INTO public.resource_events (
            resource_id, channel_id, event_type, actor_id, payload, priority
        ) VALUES (
            v_resource_id,
            NEW.channel_id,
            'message',
            NEW.sender_id,
            jsonb_build_object(
                'message_id', NEW.id,
                'message_type', NEW.message_type,
                'body_preview', left(NEW.body, 200)
            ),
            NEW.priority
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_messages_resource_event ON public.messages;
CREATE TRIGGER trg_messages_resource_event
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.on_message_insert_event();

-- ---------------------------------------------------------------------------
-- Trigger : resource_event → notifications (membres + watchers)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.on_resource_event_notify()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_category TEXT;
    v_title TEXT;
    v_channel_id UUID;
BEGIN
    v_channel_id := NEW.channel_id;

    IF NEW.priority IN ('high', 'critical') THEN
        v_category := 'alert';
    ELSIF NEW.event_type = 'message' THEN
        v_category := 'message';
    ELSE
        v_category := 'activity';
    END IF;

    v_title := CASE NEW.event_type
        WHEN 'message' THEN 'Nouveau message'
        WHEN 'member_joined' THEN 'Membre rejoint'
        WHEN 'task_created' THEN 'Nouvelle tâche'
        ELSE 'Activité'
    END;

    -- Membres actifs du canal (hors auteur)
    IF v_channel_id IS NOT NULL THEN
        INSERT INTO public.user_notifications (
            user_id, category, source_type, source_id,
            resource_id, channel_id, title, body, priority
        )
        SELECT
            cm.user_id,
            v_category,
            'resource_event',
            NEW.id,
            NEW.resource_id,
            v_channel_id,
            v_title,
            NEW.payload->>'body_preview',
            NEW.priority
        FROM public.channel_members cm
        WHERE cm.channel_id = v_channel_id
          AND cm.status = 'active'
          AND cm.user_id IS DISTINCT FROM NEW.actor_id
          AND NOT cm.is_muted;
    END IF;

    -- Watchers ressource
    INSERT INTO public.user_notifications (
        user_id, category, source_type, source_id,
        resource_id, channel_id, title, body, priority
    )
    SELECT
        rw.user_id,
        v_category,
        'resource_event',
        NEW.id,
        NEW.resource_id,
        v_channel_id,
        v_title,
        NEW.payload->>'body_preview',
        NEW.priority
    FROM public.resource_watchers rw
    WHERE rw.resource_id = NEW.resource_id
      AND rw.user_id IS DISTINCT FROM NEW.actor_id
      AND (
          rw.mode = 'all'
          OR (rw.mode = 'important' AND NEW.priority IN ('high', 'critical'))
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.channel_members cm
          WHERE cm.channel_id = v_channel_id
            AND cm.user_id = rw.user_id
            AND cm.status = 'active'
      );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_resource_events_notify ON public.resource_events;
CREATE TRIGGER trg_resource_events_notify
    AFTER INSERT ON public.resource_events
    FOR EACH ROW
    EXECUTE FUNCTION public.on_resource_event_notify();

-- ---------------------------------------------------------------------------
-- RPC : ensure discussion channel for resource
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ensure_discussion_channel(p_resource_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_channel_id UUID;
    v_resource public.resources%ROWTYPE;
BEGIN
    SELECT id INTO v_channel_id
    FROM public.channels
    WHERE resource_id = p_resource_id;

    IF v_channel_id IS NOT NULL THEN
        RETURN v_channel_id;
    END IF;

    SELECT * INTO v_resource FROM public.resources WHERE id = p_resource_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Resource not found';
    END IF;

    INSERT INTO public.channels (
        resource_id, type, subtype, creation_mode, name, created_by
    ) VALUES (
        p_resource_id,
        'discussion',
        v_resource.type,
        'automatic',
        v_resource.name,
        auth.uid()
    )
    RETURNING id INTO v_channel_id;

    RETURN v_channel_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.ensure_discussion_channel(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC : get_or_create_direct_channel
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_or_create_direct_channel(p_other_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_me UUID := auth.uid();
    v_low UUID;
    v_high UUID;
    v_channel_id UUID;
BEGIN
    IF v_me IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;
    IF p_other_user_id = v_me THEN
        RAISE EXCEPTION 'Cannot DM yourself';
    END IF;

    IF v_me < p_other_user_id THEN
        v_low := v_me;
        v_high := p_other_user_id;
    ELSE
        v_low := p_other_user_id;
        v_high := v_me;
    END IF;

    SELECT dc.channel_id INTO v_channel_id
    FROM public.direct_channels dc
    WHERE dc.user_low = v_low AND dc.user_high = v_high;

    IF v_channel_id IS NOT NULL THEN
        RETURN v_channel_id;
    END IF;

    INSERT INTO public.channels (type, subtype, creation_mode, name, created_by)
    VALUES ('direct', 'free', 'manual', 'Discussion directe', v_me)
    RETURNING id INTO v_channel_id;

    INSERT INTO public.direct_channels (channel_id, user_low, user_high)
    VALUES (v_channel_id, v_low, v_high);

    INSERT INTO public.channel_members (channel_id, user_id, status)
    VALUES (v_channel_id, v_low, 'active'), (v_channel_id, v_high, 'active')
    ON CONFLICT DO NOTHING;

    RETURN v_channel_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_direct_channel(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC : get_capabilities
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_resource_capabilities(p_type TEXT)
RETURNS SETOF public.resource_capabilities
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    WITH RECURSIVE chain AS (
        SELECT p_type AS resource_type, 0 AS depth
        UNION ALL
        SELECT rc.inherits_from, c.depth + 1
        FROM chain c
        JOIN public.resource_capabilities rc
            ON rc.resource_type = c.resource_type
        WHERE rc.inherits_from IS NOT NULL
          AND c.depth < 5
    )
    SELECT DISTINCT ON (cap.capability) cap.*
    FROM public.resource_capabilities cap
    WHERE cap.resource_type = p_type
       OR cap.resource_type IN (SELECT DISTINCT resource_type FROM chain WHERE resource_type IS NOT NULL)
    ORDER BY cap.capability, cap.resource_type DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_resource_capabilities(TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC : watch / unwatch
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.watch_resource(
    p_resource_id UUID,
    p_mode TEXT DEFAULT 'all'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.resource_watchers (resource_id, user_id, mode)
    VALUES (p_resource_id, auth.uid(), p_mode)
    ON CONFLICT (resource_id, user_id)
    DO UPDATE SET mode = EXCLUDED.mode;
END;
$$;

CREATE OR REPLACE FUNCTION public.unwatch_resource(p_resource_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    DELETE FROM public.resource_watchers
    WHERE resource_id = p_resource_id AND user_id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.watch_resource(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unwatch_resource(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC : get_resource_shell (1 round-trip)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_resource_shell(p_resource_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result JSONB;
    v_channel_id UUID;
BEGIN
    SELECT id INTO v_channel_id
    FROM public.channels WHERE resource_id = p_resource_id;

    SELECT jsonb_build_object(
        'resource', to_jsonb(r.*),
        'channel_id', v_channel_id,
        'capabilities', (
            SELECT coalesce(jsonb_agg(to_jsonb(c.*)), '[]'::jsonb)
            FROM public.get_resource_capabilities(r.type) c
            WHERE c.enabled
        ),
        'panel_layout', (
            SELECT layout FROM public.panel_layouts pl
            WHERE pl.resource_type = r.type
        ),
        'watcher', (
            SELECT to_jsonb(w.*) FROM public.resource_watchers w
            WHERE w.resource_id = r.id AND w.user_id = auth.uid()
        )
    ) INTO v_result
    FROM public.resources r
    WHERE r.id = p_resource_id;

    RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_resource_shell(UUID) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC : get_hub_feed
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
            SELECT r.*, c.id AS channel_id, cm.last_read_at
            FROM public.channel_members cm
            JOIN public.channels c ON c.id = cm.channel_id
            LEFT JOIN public.resources r ON r.id = c.resource_id
            WHERE cm.user_id = auth.uid()
              AND cm.status = 'active'
              AND NOT cm.is_archived
            ORDER BY c.updated_at DESC
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
        -- activity : events + notifications récentes
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

-- ---------------------------------------------------------------------------
-- RPC : get_resource_graph
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_resource_graph(
    p_resource_id UUID,
    p_depth INT DEFAULT 2
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN (
        SELECT coalesce(jsonb_agg(jsonb_build_object(
            'relation_type', rr.relation_type,
            'target', to_jsonb(tr.*)
        )), '[]'::jsonb)
        FROM public.resource_relations rr
        JOIN public.resources tr ON tr.id = rr.target_resource_id
        WHERE rr.source_resource_id = p_resource_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_resource_graph(UUID, INT) TO authenticated;

-- ---------------------------------------------------------------------------
-- RPC : upsert platform resource + discussion channel
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.upsert_platform_resource(
    p_type TEXT,
    p_name TEXT,
    p_external_id TEXT DEFAULT NULL,
    p_parent_resource_id UUID DEFAULT NULL,
    p_lifecycle TEXT DEFAULT 'permanent',
    p_context JSONB DEFAULT '{}'::jsonb,
    p_metadata JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_id UUID;
    v_channel_id UUID;
BEGIN
    IF p_external_id IS NOT NULL THEN
        SELECT id INTO v_id
        FROM public.resources
        WHERE type = p_type AND external_id = p_external_id;
    END IF;

    IF v_id IS NULL THEN
        INSERT INTO public.resources (
            type, name, external_id, parent_resource_id,
            lifecycle, context, metadata
        ) VALUES (
            p_type, p_name, p_external_id, p_parent_resource_id,
            p_lifecycle, p_context, p_metadata
        )
        RETURNING id INTO v_id;

        INSERT INTO public.resource_events (
            resource_id, event_type, actor_id, payload, priority
        ) VALUES (
            v_id, 'resource_created', auth.uid(),
            jsonb_build_object('type', p_type, 'name', p_name),
            'normal'
        );
    ELSE
        UPDATE public.resources
        SET name = p_name,
            parent_resource_id = coalesce(p_parent_resource_id, parent_resource_id),
            context = p_context,
            metadata = p_metadata,
            updated_at = NOW()
        WHERE id = v_id;
    END IF;

    SELECT public.ensure_discussion_channel(v_id) INTO v_channel_id;

    RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_platform_resource(TEXT, TEXT, TEXT, UUID, TEXT, JSONB, JSONB) TO authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
ALTER TABLE public.resources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resource_relations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resource_capabilities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resource_watchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.resource_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_mentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pinned_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_files ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.panel_layouts ENABLE ROW LEVEL SECURITY;

-- resources : membres canal lié ou staff ou watcher
DROP POLICY IF EXISTS resources_select ON public.resources;
CREATE POLICY resources_select ON public.resources
    FOR SELECT TO authenticated
    USING (
        public.is_staff()
        OR EXISTS (
            SELECT 1 FROM public.channels c
            JOIN public.channel_members cm ON cm.channel_id = c.id
            WHERE c.resource_id = resources.id
              AND cm.user_id = auth.uid()
              AND cm.status = 'active'
        )
        OR EXISTS (
            SELECT 1 FROM public.resource_watchers rw
            WHERE rw.resource_id = resources.id AND rw.user_id = auth.uid()
        )
        OR type IN ('network', 'support')
    );

DROP POLICY IF EXISTS resources_insert ON public.resources;
CREATE POLICY resources_insert ON public.resources
    FOR INSERT TO authenticated
    WITH CHECK (public.is_staff() OR auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS resources_update ON public.resources;
CREATE POLICY resources_update ON public.resources
    FOR UPDATE TO authenticated
    USING (public.is_staff())
    WITH CHECK (public.is_staff());

-- resource_relations
DROP POLICY IF EXISTS resource_relations_select ON public.resource_relations;
CREATE POLICY resource_relations_select ON public.resource_relations
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS resource_relations_manage ON public.resource_relations;
CREATE POLICY resource_relations_manage ON public.resource_relations
    FOR ALL TO authenticated
    USING (public.is_staff())
    WITH CHECK (public.is_staff());

-- capabilities & panels : lecture pour tous authentifiés
DROP POLICY IF EXISTS resource_capabilities_select ON public.resource_capabilities;
CREATE POLICY resource_capabilities_select ON public.resource_capabilities
    FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS panel_layouts_select ON public.panel_layouts;
CREATE POLICY panel_layouts_select ON public.panel_layouts
    FOR SELECT TO authenticated USING (true);

-- watchers
DROP POLICY IF EXISTS resource_watchers_own ON public.resource_watchers;
CREATE POLICY resource_watchers_own ON public.resource_watchers
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- channels
DROP POLICY IF EXISTS channels_select ON public.channels;
CREATE POLICY channels_select ON public.channels
    FOR SELECT TO authenticated
    USING (
        public.is_staff()
        OR public.is_active_channel_member(id)
        OR resource_id IS NULL
    );

DROP POLICY IF EXISTS channels_insert ON public.channels;
CREATE POLICY channels_insert ON public.channels
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- channel_members
DROP POLICY IF EXISTS channel_members_select ON public.channel_members;
CREATE POLICY channel_members_select ON public.channel_members
    FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_active_channel_member(channel_id)
        OR public.is_staff()
    );

DROP POLICY IF EXISTS channel_members_update_own ON public.channel_members;
CREATE POLICY channel_members_update_own ON public.channel_members
    FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS channel_members_insert ON public.channel_members;
CREATE POLICY channel_members_insert ON public.channel_members
    FOR INSERT TO authenticated
    WITH CHECK (public.is_staff() OR auth.uid() = user_id);

-- messages
DROP POLICY IF EXISTS messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
    FOR SELECT TO authenticated
    USING (public.is_active_channel_member(channel_id) OR public.is_staff());

DROP POLICY IF EXISTS messages_insert ON public.messages;
CREATE POLICY messages_insert ON public.messages
    FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND public.is_active_channel_member(channel_id)
        AND public.user_has_channel_permission(channel_id, 'can_write')
        AND (
            NOT EXISTS (
                SELECT 1 FROM public.channels c
                JOIN public.resources r ON r.id = c.resource_id
                WHERE c.id = channel_id AND r.status NOT IN ('active', 'paused')
            )
            OR public.is_staff()
        )
    );

-- resource_events
DROP POLICY IF EXISTS resource_events_select ON public.resource_events;
CREATE POLICY resource_events_select ON public.resource_events
    FOR SELECT TO authenticated
    USING (
        public.is_staff()
        OR EXISTS (
            SELECT 1 FROM public.channels c
            JOIN public.channel_members cm ON cm.channel_id = c.id
            WHERE c.resource_id = resource_events.resource_id
              AND cm.user_id = auth.uid()
              AND cm.status = 'active'
        )
        OR EXISTS (
            SELECT 1 FROM public.resource_watchers rw
            WHERE rw.resource_id = resource_events.resource_id
              AND rw.user_id = auth.uid()
        )
    );

-- user_notifications
DROP POLICY IF EXISTS user_notifications_own ON public.user_notifications;
CREATE POLICY user_notifications_own ON public.user_notifications
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- channel_files, tasks, pins, reactions, mentions
DROP POLICY IF EXISTS channel_files_select ON public.channel_files;
CREATE POLICY channel_files_select ON public.channel_files
    FOR SELECT TO authenticated
    USING (public.is_active_channel_member(channel_id) OR public.is_staff());

DROP POLICY IF EXISTS channel_files_insert ON public.channel_files;
CREATE POLICY channel_files_insert ON public.channel_files
    FOR INSERT TO authenticated
    WITH CHECK (
        uploaded_by = auth.uid()
        AND public.is_active_channel_member(channel_id)
    );

DROP POLICY IF EXISTS channel_tasks_select ON public.channel_tasks;
CREATE POLICY channel_tasks_select ON public.channel_tasks
    FOR SELECT TO authenticated
    USING (public.is_active_channel_member(channel_id) OR public.is_staff());

DROP POLICY IF EXISTS channel_tasks_insert ON public.channel_tasks;
CREATE POLICY channel_tasks_insert ON public.channel_tasks
    FOR INSERT TO authenticated
    WITH CHECK (
        created_by = auth.uid()
        AND public.is_active_channel_member(channel_id)
    );

DROP POLICY IF EXISTS channel_tasks_update ON public.channel_tasks;
CREATE POLICY channel_tasks_update ON public.channel_tasks
    FOR UPDATE TO authenticated
    USING (public.is_active_channel_member(channel_id) OR assigned_to = auth.uid());

DROP POLICY IF EXISTS pinned_messages_select ON public.pinned_messages;
CREATE POLICY pinned_messages_select ON public.pinned_messages
    FOR SELECT TO authenticated
    USING (public.is_active_channel_member(channel_id) OR public.is_staff());

DROP POLICY IF EXISTS message_reactions_all ON public.message_reactions;
CREATE POLICY message_reactions_all ON public.message_reactions
    FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS message_mentions_select ON public.message_mentions;
CREATE POLICY message_mentions_select ON public.message_mentions
    FOR SELECT TO authenticated USING (true);

-- RBAC config tables : lecture authentifiée
DROP POLICY IF EXISTS roles_select ON public.roles;
CREATE POLICY roles_select ON public.roles FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS permissions_select ON public.permissions;
CREATE POLICY permissions_select ON public.permissions FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS role_permissions_select ON public.role_permissions;
CREATE POLICY role_permissions_select ON public.role_permissions FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS member_roles_select ON public.member_roles;
CREATE POLICY member_roles_select ON public.member_roles
    FOR SELECT TO authenticated
    USING (user_id = auth.uid() OR public.is_staff());

-- ---------------------------------------------------------------------------
-- Realtime
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.resource_events;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.user_notifications;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.channel_members;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- Seeds : permissions, roles, capabilities, ressources racine, panels
-- ---------------------------------------------------------------------------
INSERT INTO public.permissions (key, label) VALUES
    ('can_read', 'Lire'),
    ('can_write', 'Écrire'),
    ('can_invite', 'Inviter'),
    ('can_pin', 'Épingler'),
    ('can_delete', 'Supprimer'),
    ('can_manage', 'Gérer')
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.roles (key, label, scope) VALUES
    ('channel_owner', 'Propriétaire', 'channel'),
    ('channel_admin', 'Administrateur', 'channel'),
    ('channel_member', 'Membre', 'channel'),
    ('channel_observer', 'Observateur', 'channel'),
    ('pad', 'PAD', 'channel'),
    ('chef', 'Chef', 'channel'),
    ('tpe', 'TPE', 'channel')
ON CONFLICT (key) DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
CROSS JOIN public.permissions p
WHERE r.key = 'channel_owner'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.key IN ('can_read', 'can_write', 'can_invite', 'can_pin')
WHERE r.key = 'channel_admin'
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.key IN ('can_read', 'can_write')
WHERE r.key IN ('channel_member', 'pad', 'chef', 'tpe')
ON CONFLICT DO NOTHING;

INSERT INTO public.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM public.roles r
JOIN public.permissions p ON p.key = 'can_read'
WHERE r.key = 'channel_observer'
ON CONFLICT DO NOTHING;

-- Capabilities
INSERT INTO public.resource_capabilities (resource_type, capability, enabled, inherits_from) VALUES
    ('network', 'discussion', false, NULL),
    ('network', 'timeline', true, NULL),
    ('support', 'discussion', true, NULL),
    ('support', 'timeline', true, NULL),
    ('direct', 'discussion', true, NULL),
    ('group', 'discussion', true, NULL),
    ('group', 'members', true, NULL),
    ('vehicle', 'discussion', true, NULL),
    ('vehicle', 'tasks', true, NULL),
    ('vehicle', 'location', true, NULL),
    ('vehicle', 'timeline', true, NULL),
    ('vehicle', 'tracking', true, NULL),
    ('station', 'discussion', true, NULL),
    ('station', 'location', true, NULL),
    ('station', 'timeline', true, NULL),
    ('line', 'discussion', true, NULL),
    ('line', 'timeline', true, NULL),
    ('line', 'announcements', true, NULL),
    ('team', 'discussion', true, NULL),
    ('team', 'documents', true, NULL),
    ('team', 'tasks', true, NULL),
    ('team', 'members', true, NULL),
    ('team', 'timeline', true, NULL),
    ('mission', 'discussion', true, NULL),
    ('mission', 'documents', true, NULL),
    ('mission', 'tasks', true, NULL),
    ('mission', 'location', true, NULL),
    ('mission', 'timeline', true, NULL),
    ('mission', 'members', true, NULL),
    ('mission', 'announcements', true, NULL),
    ('mission', 'dispatch', true, NULL),
    ('mission', 'tracking', true, NULL),
    ('mission', 'validation', true, NULL),
    ('incident', 'discussion', true, NULL),
    ('incident', 'documents', true, NULL),
    ('incident', 'tasks', true, NULL),
    ('incident', 'location', true, NULL),
    ('incident', 'timeline', true, NULL),
    ('incident', 'announcements', true, NULL),
    ('control_plan', 'discussion', true, NULL),
    ('control_plan', 'documents', true, NULL),
    ('control_plan', 'timeline', true, NULL),
    ('control_plan', 'members', true, NULL),
    ('zone', 'discussion', true, NULL),
    ('zone', 'location', true, NULL),
    ('zone', 'timeline', true, NULL),
    ('driver', 'discussion', true, NULL)
ON CONFLICT DO NOTHING;

-- Panel layouts (default)
INSERT INTO public.panel_layouts (resource_type, layout) VALUES
    ('mission', '[
        {"panel":"context","capability":null,"order":10,"visible":true},
        {"panel":"map","capability":"location","order":20,"visible":true},
        {"panel":"members","capability":"members","order":30,"visible":true},
        {"panel":"tasks","capability":"tasks","order":35,"visible":true},
        {"panel":"discussion","capability":"discussion","order":40,"visible":true},
        {"panel":"documents","capability":"documents","order":50,"visible":true},
        {"panel":"timeline","capability":"timeline","order":60,"visible":true}
    ]'::jsonb),
    ('vehicle', '[
        {"panel":"context","capability":null,"order":10,"visible":true},
        {"panel":"map","capability":"location","order":20,"visible":true},
        {"panel":"timeline","capability":"timeline","order":30,"visible":true},
        {"panel":"tasks","capability":"tasks","order":35,"visible":true},
        {"panel":"discussion","capability":"discussion","order":40,"visible":true}
    ]'::jsonb),
    ('team', '[
        {"panel":"context","capability":null,"order":10,"visible":true},
        {"panel":"members","capability":"members","order":20,"visible":true},
        {"panel":"discussion","capability":"discussion","order":30,"visible":true},
        {"panel":"tasks","capability":"tasks","order":40,"visible":true},
        {"panel":"timeline","capability":"timeline","order":50,"visible":true},
        {"panel":"documents","capability":"documents","order":60,"visible":true}
    ]'::jsonb),
    ('support', '[
        {"panel":"discussion","capability":"discussion","order":10,"visible":true},
        {"panel":"timeline","capability":"timeline","order":20,"visible":true}
    ]'::jsonb),
    ('direct', '[
        {"panel":"discussion","capability":"discussion","order":10,"visible":true}
    ]'::jsonb)
ON CONFLICT (resource_type) DO UPDATE SET layout = EXCLUDED.layout;

-- Ressources racine
INSERT INTO public.resources (id, type, name, external_id, lifecycle, status)
VALUES (
    '00000000-0000-4000-8000-000000000100',
    'network',
    'Réseau Naolib',
    'naolib',
    'permanent',
    'active'
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.resources (id, type, name, external_id, lifecycle, status)
VALUES (
    '00000000-0000-4000-8000-000000000101',
    'support',
    'Support Aule',
    'support',
    'permanent',
    'active'
)
ON CONFLICT (id) DO NOTHING;

-- Canaux discussion pour ressources système
INSERT INTO public.channels (id, resource_id, type, creation_mode, name)
SELECT
    '00000000-0000-4000-8000-000000000200',
    '00000000-0000-4000-8000-000000000101',
    'discussion',
    'automatic',
    'Support Aule'
WHERE NOT EXISTS (
    SELECT 1 FROM public.channels WHERE resource_id = '00000000-0000-4000-8000-000000000101'
);

COMMENT ON TABLE public.resources IS 'Centre plateforme Aule — toute entité métier';
COMMENT ON TABLE public.resource_events IS 'Événements unifiés — messages/notifications/timeline en projection';
