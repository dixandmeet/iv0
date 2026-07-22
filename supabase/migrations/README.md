# Migrations Supabase — Plateforme d'exploitation

Migrations à exécuter **après** [`../schema.sql`](../schema.sql) et [`../seed_tan.sql`](../seed_tan.sql).

## Ordre d'exécution

| Fichier | Contenu |
|---------|---------|
| `001_auth_profiles_depots.sql` | Dépôts, profils utilisateurs, helpers RLS |
| `002_driver_sessions.sql` | Sessions conducteur, détection auto (`start_driver_session_auto`) |
| `003_incidents.sql` | Incidents réseau, règles, statistiques |
| `004_msr_missions.sql` | Secteurs MSR, missions, buffer ligne GTFS |
| `005_live_fleet_positions.sql` | Couche temps réel unifiée + score fiabilité |
| `006_rls_policies.sql` | Politiques RLS par rôle |
| `007_regulator_features.sql` | Fonctionnalités régulateur |
| `008_stops_management.sql` | Gestion arrêts (RPC initiales) |
| `009_fix_stop_serving_lines.sql` | Correctif lignes desservies |
| `010_operational_stops.sql` | Arrêts opérationnels |
| `011_stations_stops_schema.sql` | Schéma stations / arrêts |
| `012_migrate_gtfs_to_stations.sql` | Migration GTFS → stations |
| `013_stations_stops_rpc.sql` | RPC stations (UUID) |
| `014_archive_gtfs_stops_legacy.sql` | Archive gtfs_stops legacy |
| `015_validate_stations_stops.sql` | Validation stations |
| `016_user_favorites.sql` | Favoris utilisateur |
| `017_fix_served_routes_resolution.sql` | RPC lignes desservies (UUID, repli GTFS) |
| `018_gtfs_stop_times.sql` | Horaires théoriques arrêt/ligne (lignes desservies) |
| `019_driver_management.sql` | Demandes d'inscription conducteur + RPC gestion annuaire |
| `020_control_plans.sql` | Plans de contrôle MSR |
| `021_driver_mvp.sql` | MVP conducteur (drivers, driver_services, vehicle_positions…) |
| `022_driver_service_train.sql` | N° de train sur la prise de service |
| `023_roulement_services.sql` | Roulements / services conducteurs (référence) |
| `024_driver_signup_matricule.sql` | Inscription conducteur par matricule (roster + liste de vérification) |
| `032_feed_posts.sql` | Fil d'actualité communautaire (mur partagé) + bucket Storage `feed-media` |
| `062_immersive_public_fleet.sql` | Positions de flotte anonymisées pour la carte immersive publique |
| `063_line_editor_traces.sql` | Tracés de lignes publiés depuis l'éditeur de ligne (dashboard) → carte immersive |
| `064_network_tenancy_self_service.sql` | Réseaux autonomes et isolation multi-tenant |
| `065_driver_network_selection.sql` | Réseau actif des conducteurs |
| `066_gtfs_routes_network_scope.sql` | Rattachement des lignes GTFS aux réseaux |
| `067_theoretical_fleet.sql` | Flotte théorique compressée et RPC radar |
| `068_production_security_hardening.sql` | Durcissement rôles/RPC, GPS et rétention |
| `069_schedule_vehicle_position_purge.sql` | Active Supabase Cron et purge chaque heure les positions GPS de plus de 24 h |
| `073_aleop_pdl_import.sql` | Importe les arrêts et lignes Aléop Pays de la Loire |
| `074_transit_routing_performance.sql` | Index de performance du routage historique |
| `075_timetable_journey_planner.sql` | Moteur horaire multi-alternatives, 0 à 2 correspondances, perturbations et PMR |
| `20260708000000_pro_multi_profile_access.sql` | Profils cumulables + overrides de permissions (ex-`dashboard/supabase/migrations`) |
| `20260708000001_admin_control_center.sql` | Ressources/rôles/audit Aule Studio (ex-`dashboard/supabase/migrations`) |
| `20260708000002_admin_rls_platform_admin.sql` | Policies RLS d'écriture pour l'admin plateforme (ex-`dashboard/supabase/migrations`) |

> **Traçabilité** : le projet live suit les migrations dans
> `supabase_migrations.schema_migrations`. Toute nouvelle migration doit être
> appliquée via `supabase migration up` **ou**, si elle est passée en SQL brut,
> accompagnée d'un `INSERT INTO supabase_migrations.schema_migrations (version, name)`
> dans la même session — sinon l'onglet Migrations du dashboard Supabase diverge
> (déjà arrivé deux fois, audits du 06/07 et du 22/07/2026).

### Liste de référence des conducteurs (`driver_roster`)

Après la migration `024`, importer le roster RH (idempotent, 1491 agents) :

```bash
psql "$DATABASE_URL" -f ../seed_driver_roster.sql
```

Le seed est généré depuis le CSV RH `aule_drivers_supabase_import.csv`.

### Regénérer `018_gtfs_stop_times.sql`

Utiliser l’export GTFS **legacy** (stop_id type `RLON1`, pas NeTEx) :

```bash
python3 tool/generate_stop_times_migration.py /chemin/vers/gtfs-legacy
```


## Application

### Supabase Dashboard (SQL Editor)

Exécuter chaque fichier dans l'ordre.

### Supabase CLI

```bash
supabase db push
```

## Realtime

Après migration `005`, vérifier dans **Database → Publications** que ces tables sont publiées :

- `live_fleet_positions`
- `network_incidents`
- `msr_missions`

## Création de comptes métier

Les profils sont créés automatiquement à l'inscription. Pour assigner un rôle métier :

```sql
UPDATE user_profiles
SET role = 'regulator', display_name = 'Régulateur test'
WHERE id = '<uuid-auth-user>';
```

Rôles disponibles : `passenger`, `driver`, `msr_agent`, `msr_supervisor`, `regulator`, `admin`.

## Modèles d'e-mail (Auth)

Les modèles HTML en français sont versionnés dans [`../templates/`](../templates/) et référencés par [`../config.toml`](../config.toml).

| Modèle | Déclencheur |
|--------|-------------|
| `confirmation.html` | Inscription conducteur / passager (`signUp`) |
| `invite.html` | Invitation staff via le dashboard (`inviteUserByEmail`) |
| `recovery.html` | Réinitialisation du mot de passe |
| `magic_link.html` | Connexion sans mot de passe |
| `email_change.html` | Changement d'adresse e-mail |

**Local** : `supabase stop && supabase start`, puis consulter les e-mails dans Inbucket.

**Production** : copier sujet + corps HTML dans **Authentication → Email Templates** du dashboard Supabase (les fichiers du dépôt ne sont pas déployés automatiquement sur un projet hébergé).

## Tâches planifiées recommandées

| Fonction | Fréquence | Rôle |
|----------|-----------|------|
| `purge_old_user_locations()` | 15 min | RGPD passagers |
| `aggregate_community_vehicles()` | 1 min | Flotte communautaire |
| `refresh_live_fleet_positions()` | 30 s | Couche unifiée + fiabilité |
| `purge_old_vehicle_positions(interval '24 hours')` | Chaque heure à :17 UTC | Purge des positions conducteurs précises |

La migration `069_schedule_vehicle_position_purge.sql` active `pg_cron` et
crée automatiquement le job nommé `purge-vehicle-positions-hourly`.

## Coordonnées dépôts

Les dépôts dans `001` sont **approximatifs**. Les remplacer par les coordonnées internes Naolib avant le planificateur MSR (Phase 5).
