-- Activation de la vidéo sur le fil d'actualité Aule Pro (feed_posts, 032)
-- ---------------------------------------------------------------------------
-- Le schéma (media_type) acceptait déjà 'video' ; il manquait : les types MIME
-- vidéo sur le bucket, un quota relevé, et une miniature pour l'affichage en
-- liste sans charger la vidéo elle-même.
-- ---------------------------------------------------------------------------

ALTER TABLE public.feed_posts
    ADD COLUMN IF NOT EXISTS media_thumbnail_url TEXT;

UPDATE storage.buckets
   SET file_size_limit = 83886080, -- 80 Mo (vidéos courtes)
       allowed_mime_types = ARRAY[
           'image/jpeg', 'image/png', 'image/webp',
           'video/mp4', 'video/quicktime'
       ]
 WHERE id = 'feed-media';
