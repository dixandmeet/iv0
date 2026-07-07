-- Likes et commentaires sur le fil d'actualité Aule Pro (feed_posts, 032)
-- ---------------------------------------------------------------------------
-- Même esprit que 032 : accès table direct depuis le client (pas de RPC), RLS
-- pour la sécurité, dénormalisation des compteurs sur feed_posts (mis à jour
-- par trigger) pour éviter un COUNT(*) à chaque lecture du fil.
-- ---------------------------------------------------------------------------

ALTER TABLE public.feed_posts
    ADD COLUMN IF NOT EXISTS likes_count    INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS comments_count INT NOT NULL DEFAULT 0;

-- === Likes =================================================================
CREATE TABLE IF NOT EXISTS public.feed_post_likes (
    post_id    UUID NOT NULL REFERENCES public.feed_posts(id) ON DELETE CASCADE,
    driver_id  UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, driver_id)
);

CREATE INDEX IF NOT EXISTS idx_feed_post_likes_driver
    ON public.feed_post_likes(driver_id);

ALTER TABLE public.feed_post_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS feed_post_likes_select_all ON public.feed_post_likes;
CREATE POLICY feed_post_likes_select_all ON public.feed_post_likes
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS feed_post_likes_insert_own ON public.feed_post_likes;
CREATE POLICY feed_post_likes_insert_own ON public.feed_post_likes
    FOR INSERT TO authenticated
    WITH CHECK (driver_id = public.current_driver_id());

DROP POLICY IF EXISTS feed_post_likes_delete_own ON public.feed_post_likes;
CREATE POLICY feed_post_likes_delete_own ON public.feed_post_likes
    FOR DELETE TO authenticated
    USING (driver_id = public.current_driver_id());

CREATE OR REPLACE FUNCTION public.feed_post_likes_count_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.feed_posts
           SET likes_count = likes_count + 1
         WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.feed_posts
           SET likes_count = GREATEST(likes_count - 1, 0)
         WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_feed_post_likes_count ON public.feed_post_likes;
CREATE TRIGGER trg_feed_post_likes_count
    AFTER INSERT OR DELETE ON public.feed_post_likes
    FOR EACH ROW EXECUTE FUNCTION public.feed_post_likes_count_sync();

-- === Commentaires ===========================================================
CREATE TABLE IF NOT EXISTS public.feed_post_comments (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id           UUID NOT NULL REFERENCES public.feed_posts(id) ON DELETE CASCADE,
    author_driver_id  UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    author_name       TEXT,
    author_avatar_url TEXT,
    body              TEXT NOT NULL CHECK (length(btrim(body)) > 0),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feed_post_comments_post
    ON public.feed_post_comments(post_id, created_at ASC);

ALTER TABLE public.feed_post_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS feed_post_comments_select_all ON public.feed_post_comments;
CREATE POLICY feed_post_comments_select_all ON public.feed_post_comments
    FOR SELECT TO authenticated
    USING (true);

DROP POLICY IF EXISTS feed_post_comments_insert_own ON public.feed_post_comments;
CREATE POLICY feed_post_comments_insert_own ON public.feed_post_comments
    FOR INSERT TO authenticated
    WITH CHECK (author_driver_id = public.current_driver_id());

DROP POLICY IF EXISTS feed_post_comments_delete_own ON public.feed_post_comments;
CREATE POLICY feed_post_comments_delete_own ON public.feed_post_comments
    FOR DELETE TO authenticated
    USING (author_driver_id = public.current_driver_id() OR public.is_staff());

CREATE OR REPLACE FUNCTION public.feed_post_comments_count_sync()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.feed_posts
           SET comments_count = comments_count + 1
         WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.feed_posts
           SET comments_count = GREATEST(comments_count - 1, 0)
         WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_feed_post_comments_count ON public.feed_post_comments;
CREATE TRIGGER trg_feed_post_comments_count
    AFTER INSERT OR DELETE ON public.feed_post_comments
    FOR EACH ROW EXECUTE FUNCTION public.feed_post_comments_count_sync();

-- === Réplication temps réel (idempotent) ==================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.feed_post_likes;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.feed_post_comments;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
