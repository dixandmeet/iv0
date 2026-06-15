# Wazibus Nantes MVP 🚍🗺️

**Wazibus Nantes** est un GPS communautaire temps réel pour les transports en commun de Nantes Métropole (réseau **Naolib**). 
L'application permet aux usagers de partager passivement et anonymement leur trajet afin de localiser précisément les bus, trams, navibus et busways sur la carte pour l'ensemble de la communauté.

---

## 🛠️ Stack Technique

- **Frontend Mobile** : Flutter (compatible iOS et Android)
- **Backend / BDD** : Supabase, PostgreSQL + PostGIS (requêtes spatiales et agrégation)
- **Cartographie** : OpenStreetMap via `flutter_map`
- **Algorithmes** : Détection de ligne probable et regroupement communautaire directement en PL/pgSQL (PostGIS)
- **Respect de la vie privée (RGPD)** : 100% Anonyme par défaut, consentement explicite, purge automatique des coordonnées brutes après 15 minutes.

---

## 🚀 Fonctionnement : Les Deux Modes

Pour simplifier le développement et les tests, l'application dispose de deux modes :

1. **Mode Démo (Simulé - Activé par défaut)** :
   Si aucun identifiant Supabase n'est configuré dans `lib/services/supabase_service.dart`, l'application fonctionne de manière autonome en simulant :
   - Les arrêts majeurs de Nantes (Commerce, Bouffay, Gare de Nantes, etc.).
   - Le tracé des lignes Tram 1 et Busway 4.
   - Les déplacements en temps réel de véhicules communautaires (qui se déplacent le long des lignes).
   - Les signalements d'incidents (contrôles, retards, affluence).
   - Une simulation de trajet passif (l'appareil simulé se déplace le long du Tram 1).
   - Le calculateur d'itinéraire A ➔ B (par exemple de "Commerce" à "Gare").

2. **Mode Réel (Connecté à Supabase)** :
   En renseignant l'URL et la clé anonyme Supabase dans `lib/services/supabase_service.dart`, l'application envoie les vrais signaux GPS à votre serveur PostgreSQL et lit les informations calculées par les fonctions PostGIS.

---

## 📦 Structure du Code Flutter

```
lib/
├── main.dart                       # Point d'entrée de l'application
├── models/                         # Modèles de données Dart
│   ├── anonymous_device.dart
│   ├── app_settings.dart
│   ├── community_vehicle.dart
│   ├── gtfs.dart
│   ├── location_event.dart
│   └── report.dart
├── services/                       # Services applicatifs
│   ├── supabase_service.dart       # Connexion et auth anonyme
│   ├── location_service.dart       # Acquisition GPS
│   ├── passive_tracking_service.dart # Boucle de tracking & simulation
│   ├── gtfs_service.dart           # Lignes, arrêts et routing A -> B
│   ├── vehicle_detection_service.dart # Réception et interpolation des véhicules
│   ├── report_service.dart         # Gestion des signalements
│   └── map_service.dart            # Helpers de design cartographique
└── screens/                        # Écrans de l'interface utilisateur
    ├── privacy_consent_screen.dart # Écran d'accord RGPD initial
    ├── home_map_screen.dart        # Carte interactive plein écran
    ├── search_route_screen.dart    # Formulaire de recherche A -> B
    ├── route_result_screen.dart    # Liste des itinéraires trouvés
    ├── settings_screen.dart        # Paramètres et charte RGPD
    └── widgets/                    # Panneaux flottants (bottom sheets)
        ├── vehicle_details_bottom_sheet.dart
        └── report_incident_bottom_sheet.dart
```

---

## ⚙️ Déploiement du Backend Supabase

### 1. Initialiser PostGIS
Créez un projet sur [Supabase](https://supabase.com/). Dans l'éditeur SQL de votre projet, exécutez le script `/supabase/schema.sql` pour installer l'extension géospatiale PostGIS, créer les tables et installer les fonctions de détection.

### 1b. Migrations plateforme d'exploitation (Phase 0)
Après `schema.sql` et `seed_tan.sql`, exécutez les fichiers de [`supabase/migrations/`](supabase/migrations/) dans l'ordre (auth, conducteur, incidents, MSR, flotte live, RLS). Voir [`supabase/migrations/README.md`](supabase/migrations/README.md).

L'architecture de référence du projet est documentée dans [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

Le poste de contrôle Web Next.js se trouve dans [`dashboard/`](dashboard/) (port 3001 en dev).

### 2. Configurer les clés Supabase
Dans le fichier `lib/services/supabase_service.dart`, mettez à jour les variables suivantes :
```dart
static const String _urlKey = 'https://VOTRE-PROJET.supabase.co';
static const String _anonKey = 'VOTRE-CLE-ANON-PUBLIQUE';
```

### 3. Import des données GTFS Naolib

**Option rapide (réseau TAN réel fourni)** : exécutez `supabase/seed_tan.sql` dans l'éditeur SQL après `schema.sql`. Il importe directement les **109 lignes**, **3 751 arrêts** (avec accessibilité PMR `wheelchair_boarding`), les **414 variantes de tracés** (`gtfs_shapes`) et des `gtfs_trips` minimaux (1 par variante, avec le vrai `direction_id`) pour que la détection temps réel `detect_probable_route` fonctionne. Ce seed est régénérable depuis un export GTFS Naolib via `python3 tool/update_tan_data.py /chemin/vers/gtfs` (données : export GTFS Naolib de juin 2026 ; les mêmes données sont embarquées en assets pour le mode démo hors-ligne : `assets/data/tan_*.json`).

**Option complète (avec horaires)** pour charger aussi les horaires théoriques de Nantes :
1. Téléchargez le fichier zip GTFS officiel de Naolib (Nantes) sur [transport.data.gouv.fr](https://transport.data.gouv.fr/).
2. Extrayez les fichiers `.txt` (stops, routes, shapes, trips, stop_times).
3. Importez-les dans votre base Supabase.
   * *Note pour PostGIS* : Pour convertir les latitudes/longitudes de `stops.txt` et `shapes.txt` en géométries PostGIS utilisables (`geom`), exécutez ces requêtes SQL après import :
     ```sql
     -- Conversion pour les arrêts
     UPDATE gtfs_stops SET geom = ST_SetSRID(ST_Point(stop_lon, stop_lat), 4326);
     
     -- Conversion pour les tracés
     UPDATE gtfs_shapes SET geom = ST_SetSRID(ST_Point(shape_pt_lon, shape_pt_lat), 4326);
     ```

---

## 📱 Démarrage de l'application Flutter

### Prérequis
- Flutter SDK (version `>= 3.10.0`)
- Un émulateur iOS/Android ou un appareil de test connecté

### Commandes de lancement
1. Récupérer les paquets et dépendances :
   ```bash
   flutter pub get
   ```
2. Lancer l'application :
   ```bash
   flutter run
   ```
