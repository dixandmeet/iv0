# SAE — Aule Pro

Application Flutter terrain pour les conducteurs et agents Naolib.

## Données réelles

L'application utilise deux sources complémentaires :

- l'API Open Data Nantes Métropole pour contrôler le flux officiel
  `244400404_transports_commun_naolib_nantes_metropole_gtfs`, sa période de
  validité et l'URL du ZIP GTFS courant ;
- Supabase pour interroger la version normalisée du GTFS (`gtfs_routes`,
  `gtfs_trips`, `gtfs_stop_times`, `gtfs_stops`, `gtfs_shapes`) et le RPC
  `immersive_fleet_positions`.

La prise de service, les directions, le plan d'arrêts, les horaires et le tracé
du guidage ne reposent plus sur des données simulées. Le radar reste vide quand
aucune position réelle récente n'est publiée.

## Configuration

Le projet de développement est configuré par défaut. Pour cibler un autre
projet Supabase :

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

La clé embarquée doit rester une clé `publishable`/`anon`. Les accès sont
limités côté base par les politiques RLS ; ne jamais utiliser de clé
`service_role` dans l'application.

## Vérification

```sh
flutter analyze
flutter test
flutter build web --release
```
