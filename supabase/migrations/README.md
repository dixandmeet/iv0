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

## Tâches planifiées recommandées

| Fonction | Fréquence | Rôle |
|----------|-----------|------|
| `purge_old_user_locations()` | 15 min | RGPD passagers |
| `aggregate_community_vehicles()` | 1 min | Flotte communautaire |
| `refresh_live_fleet_positions()` | 30 s | Couche unifiée + fiabilité |

Configurer via **Database → Extensions → pg_cron** ou un Edge Function cron Supabase.

## Coordonnées dépôts

Les dépôts dans `001` sont **approximatifs**. Les remplacer par les coordonnées internes Naolib avant le planificateur MSR (Phase 5).
