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
| `/dashboard` | Carte + flotte live + incidents |
| `/incidents` | Module incidents (stub) |
| `/missions` | Missions MSR (stub Phase 4) |

## Prérequis Supabase

Appliquer les migrations `supabase/migrations/001` → `006` et activer Realtime sur `live_fleet_positions`, `network_incidents` et `msr_missions`.

### Données de démonstration (dev)

Pour peupler le dashboard avec des véhicules, incidents et missions fictifs autour de Nantes :

```bash
psql $DATABASE_URL -f supabase/seed_dashboard_demo.sql
```

Ce script est idempotent : il supprime et recrée les données demo à chaque exécution.
