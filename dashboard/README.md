# Aule — Poste de contrôle (Next.js)

Interface Web d'exploitation pour régulateurs, superviseurs MSR et administrateurs.

## Stack

- **Next.js 16** (App Router)
- **Supabase** (auth + Realtime)
- **MapLibre GL JS** (cartographie open source)

## Démarrage

```bash
cd dashboard
cp .env.local.example .env.local   # si besoin
npm install
npm run dev
```

Ouvrir [http://localhost:3001](http://localhost:3001) (port **3001** pour ne pas entrer en conflit avec Flutter Web).

En cas d'erreur `Cannot find module './XXX.js'` ou de pages en 500, nettoyer le cache Next.js :

```bash
npm run dev:clean
```

## Variables d'environnement

| Variable | Description |
|----------|-------------|
| `NEXT_PUBLIC_SUPABASE_URL` | URL du projet Supabase |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Clé anon / publishable |
| `SUPABASE_SERVICE_ROLE_KEY` | Routes serveur d'administration et invitations |
| `GOOGLE_MAPS_API_KEY` | Autocomplétion d’adresses Google Places (repli OSM sans clé) |
| `NAOLIB_SIRI_API_KEY` | Optionnel : perturbations opérateur SIRI Situation Exchange via Okina |
| `NEXT_PUBLIC_ENABLE_DEMO_DATA` | Démo locale uniquement ; toujours désactivée en production |

## Accès

Réservé aux rôles : `regulator`, `msr_supervisor`, `admin`.

```sql
UPDATE user_profiles SET role = 'regulator', display_name = 'Régulateur test'
WHERE id = '<uuid-auth-user>';
```

## Pages

| Route | Description |
|-------|-------------|
| `/login` | Connexion exploitant |
| `/dashboard` | Carte + flotte live + KPI + alertes |
| `/alertes` | Centre d'alertes automatiques |
| `/incidents` | Création, suivi et résolution incidents |
| `/conducteurs` | Annuaire conducteurs, demandes d'inscription, sessions actives |
| `/communication` | Messages staff (individuel, groupe, diffusion) |
| `/info-voyageur` | Publication perturbations et annonces |
| `/missions` | Missions MSR |
| `/reporting` | KPI, ponctualité, exports CSV |

## Prérequis Supabase

Appliquer les migrations Supabase dans l’ordre. Le planificateur horaire de la
carte immersive nécessite en particulier `067_theoretical_fleet.sql`,
`074_transit_routing_performance.sql` et `075_timetable_journey_planner.sql`.
Activer Realtime sur `live_fleet_positions`, `network_incidents`, `msr_missions`,
`staff_messages` et `passenger_announcements`.

### Données de démonstration (dev)

Pour peupler le dashboard avec des véhicules, incidents et missions fictifs autour de Nantes :

```bash
psql $DATABASE_URL -f supabase/seed_dashboard_demo.sql
```

Ce script est idempotent : il supprime et recrée les données demo à chaque exécution.
