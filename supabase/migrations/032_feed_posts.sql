-- Fil d'actualité communautaire Aule Pro (feed)
-- ---------------------------------------------------------------------------
-- Mur partagé : tous les utilisateurs Aule Pro authentifiés (conducteurs,
-- agents MSR, staff) voient tous les posts. Chacun publie en son nom et peut
-- supprimer ses propres posts ; le staff peut modérer (supprimer n'importe
-- quel post).
--
-- v1 : texte + image. La colonne `media_type` prévoit déjà la vidéo — pour
-- l'activer : ajouter les types MIME vidéo au bucket et relever le quota.
-- L'auteur (nom + avatar) est dénormalisé sur le post : la RLS de `drivers`
-- n'autorise pas la lecture des autres fiches conducteur, on capture donc
-- l'identité au moment de la publication.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.feed_posts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_driver_id  UUID NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
    author_name       TEXT,
    author_avatar_url TEXT,
    body              TEXT,
    media_url         TEXT,
    media_type        TEXT NOT NULL DEFAULT 'none'
                      CHECK (media_type IN ('none', 'image', 'video')),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    -- Un post doit porter au moins du texte ou un média.
    CONSTRAINT feed_posts_not_empty CHECK (
        (body IS NOT NULL AND length(btrim(body)) > 0)
        OR media_url IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_feed_posts_created_at
    ON public.feed_posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_posts_author
    ON public.feed_posts(author_driver_id, created_at DESC);

-- === RLS ===================================================================
ALTER TABLE public.feed_posts ENABLE ROW LEVEL SECURITY;

-- Lecture : tout utilisateur authentifié (mur partagé).
DROP POLICY IF EXISTS feed_posts_select_all ON public.feed_posts;
CREATE POLICY feed_posts_select_all ON public.feed_posts
    FOR SELECT TO authenticated
    USING (true);

-- Publication : uniquement en son propre nom (fiche conducteur courante).
DROP POLICY IF EXISTS feed_posts_insert_own ON public.feed_posts;
CREATE POLICY feed_posts_insert_own ON public.feed_posts
    FOR INSERT TO authenticated
    WITH CHECK (author_driver_id = public.current_driver_id());

-- Suppression : son propre post, ou modération staff.
DROP POLICY IF EXISTS feed_posts_delete_own ON public.feed_posts;
CREATE POLICY feed_posts_delete_own ON public.feed_posts
    FOR DELETE TO authenticated
    USING (author_driver_id = public.current_driver_id() OR public.is_staff());

-- === Storage : médias du feed =============================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'feed-media',
    'feed-media',
    true,
    10485760, -- 10 Mo (images v1 ; relever pour la vidéo)
    ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS feed_media_public_read ON storage.objects;
CREATE POLICY feed_media_public_read ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'feed-media');

DROP POLICY IF EXISTS feed_media_insert_own ON storage.objects;
CREATE POLICY feed_media_insert_own ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'feed-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS feed_media_delete_own ON storage.objects;
CREATE POLICY feed_media_delete_own ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'feed-media'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

-- === Réplication temps réel (idempotent) ==================================
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.feed_posts;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
