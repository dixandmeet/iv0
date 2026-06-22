# Séparation Aule Voyageur / Aule Pro

> **Statut** : séparation produit réalisée (branche `feat/aule-split`).
> Migration backend (commit 7) **à faire** — voir §4.

## 1. Décision

Le produit **Aule** est scindé en deux apps Flutter distinctes + un backend commun :

- **Aule Voyageur** — grand public (arrêts, lignes, véhicules, suivi, commentaires, notifications).
- **Aule Pro** — terrain (conducteur + agent MSR).
- **Dashboard Aule** (`/dashboard`) — exploitation / régulation / supervision / administration.
- **Supabase** — backend commun, cloisonné par RLS.

Principe directeur : **séparer le produit d'abord, durcir le backend ensuite.**

## 2. Structure du dépôt

```
/                  → app « aule » (Aule Voyageur, appId io.aule.app) — 100% voyageur
/pro_app           → app « aule_pro » (Aule Pro, appId io.aule.pro) — conducteur + MSR
/packages/shared   → package « shared » (path dep des 2 apps)
/dashboard         → Dashboard Aule (Next.js)
/supabase          → schéma + migrations
```

### `/packages/shared` (commun minimal et stable)
- `SupabaseConfig` — URL + clé publishable (**point unique** pour migrer de projet Supabase).
- `Tables` — noms de tables centralisés.
- `AppUserRole` — enum réduit (`passenger`, `driver`, `msrAgent`) ; autres rôles DB repliés sur `passenger`.
- `UserProfile`.
- **Pas** de `LocationService` : la logique GPS diverge entre voyageur/conducteur/MSR → chaque app garde la sienne.

### Aule Pro — navigation
`ProRoot` : non connecté → `ProLoginScreen` ; `driver` → `DriverShell` ; `msr_agent` → `MsrShell`
(scaffold) ; sinon → accès refusé. Auth pro = `signIn()` réservé aux comptes `driver`/`msr_agent`,
pas de session anonyme. MSR : coquille navigable (Missions/Profil), logique métier à brancher.

## 3. Commandes

```bash
# Voyageur (racine)            # Pro
flutter pub get               (cd pro_app && flutter pub get)
flutter analyze && flutter test
flutter run -d <device>
```

## 4. Commit 7 — Migration Supabase + RLS

Cible : projet `rllcdvuqduuyhdcifiwp` (clé `sb_publishable_SoVrtwgKHm3lkFaW8r5fmA_HEH7VpL6`).

### ✅ Fait — clonage des données (via pg_dump 17 → restore)
Schéma `public` (39 tables), données, **66 policies RLS**, 786 fonctions, 3 vues, et les
13 comptes `auth.users` (mots de passe inclus) ont été clonés et vérifiés (comptes de lignes
identiques, lecture REST anon HTTP 200). Extensions activées sur le nouveau projet :
`postgis` + `unaccent` dans `public` (`pgcrypto`/`uuid-ossp` dans `extensions`).
Sauvegarde locale : `/tmp/aule_migration/old_public.sql` + `old_auth.sql` (éphémère).

### ⛔ Restant — config auth + bascule (les apps tournent ENCORE sur l'ancien projet)
1. **Activer l'auth anonyme** sur le nouveau projet (sinon l'app voyageur tombe en mode
   dégradé) : dashboard → Authentication → Sign In/Providers → « Anonymous sign-ins », ou
   API `PATCH /v1/projects/rllcdvuqduuyhdcifiwp/config/auth {"external_anonymous_users_enabled":true}`
   (nécessite un PAT `sbp_…` ; le token CLI du keychain est expiré).
2. **OAuth** (login Google/Apple voyageur) : whitelister les redirects `io.aule.app://login-callback/`
   et `io.aule.pro://login-callback/`, reconfigurer les providers Google/Apple.
3. **Basculer les 3 points d'injection** (seulement après l'étape 1) :
   - `packages/shared/lib/src/supabase_config.dart` → `url` + `publishableKey` du nouveau projet
   - `dashboard/.env.local` → `NEXT_PUBLIC_SUPABASE_URL` + `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `supabase/.env.local` → `SUPABASE_PROJECT_REF` + `SUPABASE_URL`
4. Smoke test des 3 clients, puis redéploiement du dashboard.

> **Ne pas basculer tant que l'étape 1 n'est pas faite.** La bascule (étape 3) est réversible
> (git revert + redéploiement).

### Tables d'anticipation encore à créer (optionnel, non bloquant)
Le clonage a repris `networks`, `driver_services`, `driver_messages` (déjà présents). Restent
à ajouter quand utiles : `driver_incidents`, `vehicle_assignments`, `traveler_notifications`,
`staff_notifications`, et `network_id` sur les tables référentiel (multi-réseau).

### Détails de référence (ancien périmètre)
Cible historique : les 2 apps + le dashboard pointent aujourd'hui sur `zxxqrrsrvptkhfvasnco`.

**Prérequis** : DB password (ou management token) du nouveau projet ; idéalement DB password de
l'ancien pour le `pg_dump`.

**Étapes**
1. Appliquer `supabase/schema.sql` + migrations `001`→`021` sur le nouveau projet.
2. Nouvelles tables/colonnes à créer pendant la migration (anticipation, coût faible) :
   - **Multi-réseau** : table `networks` (`id, name, operator_name, country, timezone, is_active`)
     + colonne `network_id` sur `stations`, `stops`, `gtfs_routes`, `vehicles`, profils staff. Seed : Naolib/Nantes.
   - Conducteur : `driver_services`, `driver_incidents`, `driver_messages`, `vehicle_assignments`.
   - Notifications **séparées** : `traveler_notifications` + `staff_notifications`.
3. Données : `pg_dump --data-only` ancien → restore nouveau (volumineux : `gtfs_*`, `stations`/`stops`).
4. Auth : réactiver l'anonyme + redirects OAuth `io.aule.app://login-callback/` et `io.aule.pro://login-callback/`.
5. RLS (`supabase/migrations/022_app_split_rls.sql`) :
   - voyageur : aucun accès aux tables internes pro (`driver_sessions`, `msr_*`, `control_plans`, `drivers`).
   - conducteur : ne voit que SES services (filtre `auth.uid()` / email).
   - agent MSR : ne voit que SES missions / équipes.
   - supervisor / regulator / admin : préparés, non activés en mobile.
6. Bascule des **3 points d'injection** + dashboard :
   - `packages/shared/lib/src/supabase_config.dart` (les 2 apps en dépendent)
   - `dashboard/.env.local`
   - `supabase/.env.local`
7. Smoke test des 3 clients, puis nettoyage des refs codées en dur de l'ancien projet.

## 5. Points de vigilance
- Migration BDD = action sensible : dump de sauvegarde de l'ancien projet avant tout, bascule des
  identifiants seulement après smoke test du nouveau.
- `community_vehicle` / `live_fleet_position` / `traveler_comment` : le mot « driver » y est un
  **libellé de source/catégorie** côté voyageur — ne pas confondre avec du code pro.
- Assets GTFS dupliqués dans `pro_app/assets/data` (choix : faible couplage > DRY).
- OAuth deep links pro non encore testés (login = email/mot de passe).
