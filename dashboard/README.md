# Aule — Poste de contrôle (Next.js)

Interface Web d'exploitation pour régulateurs, superviseurs MSR et administrateurs.

## Stack

- **Next.js 15** (App Router)
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
| `/conducteurs` | Sessions conducteurs actives |
| `/communication` | Messages staff (individuel, groupe, diffusion) |
| `/info-voyageur` | Publication perturbations et annonces |
| `/missions` | Missions MSR |
| `/reporting` | KPI, ponctualité, exports CSV |

## Prérequis Supabase

Appliquer les migrations `supabase/migrations/001` → `007` et activer Realtime sur `live_fleet_positions`, `network_incidents`, `msr_missions`, `staff_messages` et `passenger_announcements`.

### Données de démonstration (dev)

Pour peupler le dashboard avec des véhicules, incidents et missions fictifs autour de Nantes :

```bash
psql $DATABASE_URL -f supabase/seed_dashboard_demo.sql
```

Ce script est idempotent : il supprime et recrée les données demo à chaque exécution.
