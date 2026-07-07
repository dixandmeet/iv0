-- Tentative de mitigation pour rls_disabled_in_public sur spatial_ref_sys,
-- SANS passer par ALTER TABLE (qui échoue : table possédée par supabase_admin).
-- REVOKE peut fonctionner même sans ownership, si le rôle courant a reçu le
-- privilège avec GRANT OPTION (souvent le cas par défaut sur Supabase).
--
-- A exécuter séparément du reste : si ça échoue aussi
-- ("permission denied" / "must have grant option"), c'est confirmé
-- infaisable depuis le SQL editor — voir le commentaire dans
-- supabase_fix_security_errors.sql (option : ticket support Supabase).
--
-- Effet si ça passe : anon/authenticated ne pourront plus lire
-- spatial_ref_sys via l'API REST. Vérifie que rien côté app n'interroge
-- cette table via PostgREST avant/après (peu probable : c'est une table
-- interne PostGIS, pas censée être appelée par le code applicatif).

revoke select on public.spatial_ref_sys from anon, authenticated;
