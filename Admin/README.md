# Aule Admin Command Center

Prototype haute fidélité statique du dashboard administrateur Aule.

## Ouvrir

Ouvrir `index.html` dans un navigateur moderne.

## Inclus

- Sidebar fixe avec les 9 sections du brief.
- Dashboard global avec KPIs, carte, timeline, alertes et états UX.
- Centre de supervision type PC Exploitation.
- Exploitation, utilisateurs, missions, communication, marketplace, analytics et administration.
- Recherche globale `Cmd/Ctrl + K`.
- Dark mode premium, responsive desktop, animations et données simulées.
- Connexion aux open data Nantes Métropole/Naolib : vélos temps réel, P+R, parkings publics, autopartage, alertes trafic et catalogue GTFS-RT.

## Configuration des vraies données

Modifier `config.json` :

- `auleApiBaseUrl` : URL de l'API Aule si disponible.
- `auleApiToken` : token Bearer de l'API Aule.
- `okinaBearerToken` : token nécessaire pour les endpoints GTFS-RT Okina bus/tram.
- `refreshMs` : fréquence de rafraîchissement souhaitée.
- `supabase.url` : URL du projet Supabase, par exemple `https://xxxx.supabase.co`.
- `supabase.anonKey` : clé anon/public avec accès `select` aux tables voulues.
- `supabase.tables` : noms des tables à lire. Par défaut : `service_sources`, `transport_services`, `service_segments`, `drivers`.

Sans API Aule, les modules propriétaires restent indiqués comme "API Aule à connecter" tandis que les données publiques Naolib se chargent réellement.

Ne pas mettre une clé `service_role` dans `config.json` côté navigateur. Pour une clé service, passer par un backend ou une Edge Function.

`config.runtime.js` est généré depuis `config.json` pour permettre l'ouverture directe en `file://`. Si `config.json` change, régénérer `config.runtime.js`.
