-- Corrige les erreurs ERROR du linter Supabase (sécurité) qui sont
-- réellement applicables avec le rôle `postgres` du SQL editor.
-- A exécuter sur le projet Supabase live (SQL editor du dashboard, ou psql).
-- Idempotent : peut être rejoué sans risque.

-- 1) security_definer_view
-- La vue `legacy_reports_as_incidents` s'exécutait avec les droits de son
-- créateur (souvent un rôle élevé), contournant les RLS de l'appelant.
-- On la bascule en SECURITY INVOKER (comportement par défaut recommandé) :
-- la vue applique alors les policies RLS de l'utilisateur qui interroge,
-- pas celles du créateur. Ne redéfinit pas la vue, ne change pas sa requête.
alter view public.legacy_reports_as_incidents set (security_invoker = true);

-- 2) rls_disabled_in_public sur `spatial_ref_sys` : NON APPLICABLE ICI.
-- Cette table système est créée par l'extension PostGIS et appartient au
-- rôle `supabase_admin`. Ni `postgres` ni `postgres set role supabase_admin`
-- n'ont les droits pour l'ALTER (testé : "permission denied to set role").
-- C'est un faux positif connu et documenté du linter sur les projets
-- Supabase hébergés : la table ne contient que des définitions de
-- référentiels spatiaux (codes EPSG), publiques et non sensibles, jamais
-- écrites par l'app. Corriger proprement nécessiterait soit une
-- intervention du support Supabase (changement de propriétaire), soit de
-- déplacer l'extension PostGIS hors du schéma `public` (migration invasive,
-- risque de casser tout code référençant des types/fonctions PostGIS sans
-- préfixe de schéma) — à ne faire que dans une session dédiée avec tests.
