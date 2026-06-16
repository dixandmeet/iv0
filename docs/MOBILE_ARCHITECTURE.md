# App mobile voyageur — Structure de référence

> **Statut** : référence active — à respecter pour tout nouvel écran/widget.
> **Périmètre** : surface **voyageur** de l'app Flutter (`lib/`).
> Pour la plateforme d'exploitation (conducteur, MSR, dashboard Web), voir [`ARCHITECTURE.md`](ARCHITECTURE.md).
>
> **Décision design actée** : design system unique = **Aule** (dark-aware, déjà thème global dans `main.dart`). Flow est en voie de retrait.

---

## 1. Principe directeur

Le code est organisé **par fonctionnalité** (feature-first), pas par couche technique. Chaque
fonctionnalité du MVP possède son dossier, qui contient ses écrans **et** ses widgets propres.
Ce qui est transverse (thème, modèles GTFS, services, primitives UI partagées) vit dans `core/`.

**Règle de placement d'un widget** :
- utilisé par **une seule** feature → il reste dans cette feature ;
- utilisé par **deux features ou plus** → il monte dans `core/widgets/`.

**Règle design** : tout écran/widget voyageur utilise **Aule** (`core/theme/aule_theme.dart`).
Aucun nouvel usage de Flow. Le code Flow est migré au fur et à mesure puis supprimé.

---

## 2. Arborescence cible

```
lib/
├── main.dart
├── app/                      # bootstrap : providers, MaterialApp, ModeGate, AppShell, navigation
├── core/
│   ├── theme/                # Aule uniquement (aule_theme + tokens couleur/typo)
│   ├── models/               # gtfs, stop_data, report… (partagés)
│   ├── services/             # supabase, location, gtfs, realtime, disruptions, favoris…
│   └── widgets/              # primitives partagées (line_badge, departure_row, cards génériques)
└── features/
    ├── home/                 # Accueil / dashboard + sections
    ├── journey/              # Itinéraires A→B : recherche + comparaison + résultats + guidage
    ├── schedules/            # Horaires temps réel, prochains départs, théorique vs réel
    ├── map/                  # Carte interactive : arrêts proximité, position, lignes/stations
    ├── stop/                 # Fiche arrêt : lignes desservies, passages, perturbations, PMR
    ├── vehicles/             # Suivi véhicule en direct + ETA dynamique
    ├── alerts/               # Perturbations : retards, travaux, déviations, interruptions
    ├── favorites/            # Arrêts / lignes / trajets récurrents (domicile, travail, école)
    └── driver/               # Surface conducteur (hors voyageur — voir ARCHITECTURE.md)
```

Chemin d'exécution réel : `main.dart → app/ModeGate → app/AppShell` (onglets Accueil · Itinéraire · Horaires · Menu).

---

## 3. Mapping MVP → feature

| Fonctionnalité MVP | Feature | Écrans clés (cible) |
|---|---|---|
| Recherche d'itinéraires multimodaux (A→B, comparaison, modes, marche) | `journey` | recherche, résultats comparés, guidage pas-à-pas |
| Horaires temps réel (attente réelle, prochains départs, théorique vs réel) | `schedules` | liste départs, recherche station |
| Carte interactive (arrêts proximité, position, lignes/stations) | `map` | carte plein écran |
| Fiche détaillée d'un arrêt (lignes, passages, perturbations, PMR) | `stop` | fiche arrêt |
| Suivi des véhicules en direct (position, ETA, déplacement carte) | `vehicles` | suivi véhicule live |
| Alertes et perturbations (retards, travaux, déviations, interruptions) | `alerts` | bandeau accueil + détail |
| Favoris (arrêts, lignes, trajets récurrents) | `favorites` | gestion favoris |

---

## 4. État réel après nettoyage (2026-06-16)

Le repo a été initialisé sous git, puis 11 fichiers du prototype parallèle mort ont été
supprimés (9 écrans + 2 modèles). `dart analyze` : 0 erreur.

### Constat clé
- L'**accueil vivant** (`home_tab`) est **déjà en Aule** (hankenGrotesk, palette dark-aware inline).
  Le « home en Flow » supposé était en réalité le `home_screen` supprimé.
- Sur les **85 fichiers atteignables** depuis `main.dart`, **Flow ne subsiste que dans 5** :

  **✅ Migration terminée — tout l'arbre atteignable depuis `main.dart` est désormais 100 % Aule.**

  | Fichier | État |
  |---|---|
  | `screens/station_search_screen.dart` | ✅ migré Aule (vérifié à l'écran) |
  | `screens/settings_screen.dart` | ✅ migré Aule (vérifié à l'écran) |
  | `screens/route_result_screen.dart` | ✅ migré Aule (vérifié à l'écran) |
  | `screens/itinerary_guidance_page.dart` | ✅ migré Aule (vérifié — guidage volontairement clair / sombre à bord) |
  | `services/map_service.dart` | ✅ migré (couleurs sémantiques locales) |
  | `models/transport_visuals.dart` | NEW — `enum CrowdLevel` extrait de `flow_theme` (ré-exporté par `flow_theme` pour les orphelins) |

  > **✅ Flow entièrement supprimé du codebase** (`flow_theme`/`flow_widgets`/`flow_primitives` + tous les écrans qui en dépendaient). Plus aucune référence à Flow dans `lib/`.

### Audit étape 4 — les features MVP « manquantes » étaient des doublons

| Orphelin supprimé | Verdict |
|---|---|
| `vehicle_tracking_page` + `trip_in_progress_page` | doublons de `ImmersiveNavigationPage` (vivant) — le suivi véhicule en direct existe déjà via `stop → LineDetailPage → ImmersiveNavigationPage` (vérifié à l'écran) |
| `nearby_stops_page` | alias déprécié (« préférer AppShell ») — les arrêts à proximité sont sur `home_tab` |
| sheets Flow (`vehicle_details`, `tracked_vehicle`, `report_incident`, `line_plan_sheet`) | cluster orphelin fermé, jamais branché |

> ⚠️ **Feature à rebâtir** : l'UI « signaler un incident » (`report_incident_bottom_sheet`) était dans le cluster Flow supprimé. Le backend `ReportService` reste vivant (utilisé par `app_shell`). Quand la feature « signalement communautaire » sera priorisée, recréer le bottom sheet en Aule et le brancher (carte / fiche véhicule). Récupérable via git.

### Statut des features MVP (audit + complétions)

| Feature MVP | Statut |
|---|---|
| Recherche d'itinéraires | ✅ `itinerary_page → route_result_screen → itinerary_guidance_page` |
| Horaires temps réel | ✅ `horaires_page`, `stop_detail_page`, `line_detail_page` (Live) |
| Fiche arrêt | ✅ `stop_detail_page` |
| Suivi véhicule en direct | ✅ `line_detail_page → ImmersiveNavigationPage` |
| **Alertes & perturbations** | ✅ **NEW** `disruptions_page.dart` (DisruptionService réel), branché depuis le Menu |
| **Favoris** | ✅ **NEW** arrêts favoris persistés (`FavoritesService` + `shared_preferences`), étoile sur `stop_detail`, `favorites_page.dart`, entrée Menu |
| **Carte interactive** | ✅ **NEW** `network_map_page.dart` (réseau complet : lignes + arrêts + position, tap arrêt → fiche), entrée Menu « Plan du réseau » |

> **Toutes les features MVP listées sont désormais présentes et vérifiées à l'écran.** Restes possibles (polish) : persistance des trajets récurrents (domicile/travail) dans les favoris ; UI « signaler un incident » (backend `ReportService` prêt) ; migration physique vers `features/`.

  → migrer ces 5 fichiers vers Aule = pré-requis pour supprimer `flow_theme` / `flow_widgets` / `flow_primitives`.

### Orphelins révélés par le nettoyage (~40, non atteignables depuis `main.dart`)

Classés par intention — **ne pas supprimer en masse** :

| Bucket | Fichiers | Décision |
|---|---|---|
| **Features MVP à reconnecter** | `vehicle_tracking_page`, `trip_in_progress_page`, `nearby_stops_page` + widgets `vehicle_tracking/*`, `nearby_stops/{map_preview,quick_actions}`, sheets `vehicle_details/tracked_vehicle/station_details/report_incident` | brancher au shell (étape 4) |
| **Services temps réel** | `gtfs_rt_service`, `operator_realtime_service`, `utils/aule_eta` | reconnecter (feature « temps réel ») |
| **Kit de widgets Aule** (orphelin depuis `aule_shell`) | `widgets/aule/*` (9 fichiers) | réutiliser pour bâtir les features en Aule |
| ~~Ancien dashboard d'accueil en Flow~~ | ~~`screens/widgets/home/*`, `widgets/home/*`, `nearby_station_card`, `pulse_screen`, `search_route_screen`, `station_details_bottom_sheet`~~ | ✅ **supprimé** (14 fichiers) — accueil Aule conservé |

**Décision accueil (exécutée) :** l'accueil Aule vivant a été vérifié à l'écran (header, chip temps
réel, arrêts à proximité) et conservé comme base. L'ancien dashboard Flow, débranché et plus riche
mais dans le mauvais design system, a été supprimé pour ne pas réintroduire Flow. Ses sections
(favoris, départs imminents, véhicules proches, alertes, suggestions) restent **récupérables via git**
et seront rebâties nativement en Aule au besoin.

**Vérification à l'écran (preview web) :** accueil, onglet itinéraire et écran résultats bootent et
sont fonctionnels. Constat de thème : l'accueil/itinéraire (Aule) utilisent une palette de neutres
*froide*, tandis que `route_result`/`itinerary_guidance` (Flow) utilisent une palette *chaude* (beige) —
d'où l'incohérence visuelle subtile. Finir la migration Aule de ces écrans supprime cet écart.

---

## 5. Plan de migration (état)

1. ~~**Filet de sécurité** : `git init` + commit initial~~ ✅ fait
2. ~~**Supprimer le code mort** (prototype parallèle)~~ ✅ fait (11 fichiers)
3. ~~**Unifier sur Aule** : migrer les fichiers Flow vivants~~ ✅ fait — tout l'arbre atteignable
   est en Aule (vérifié à l'écran). Reste à supprimer `flow_*` après migration des sheets orphelins.
4. ~~**Reconnecter** les features MVP orphelines~~ ✅ audit fait — c'étaient des doublons morts
   (suivi véhicule & arrêts proximité déjà vivants), supprimés. Reste à rebâtir l'UI « signaler
   un incident » en Aule quand priorisée.
5. ~~**Supprimer `flow_*`**~~ ✅ fait — codebase 100 % sans Flow.
6. **Trancher l'accueil** : dashboard riche (reconstruit en Aule) vs accueil simple actuel.
7. **Fusionner** les écrans de recherche/navigation redondants (reste : `station_search` vs
   recherche d'itinéraire ; `immersive_navigation` vs `itinerary_guidance` se recoupent en partie).
8. **Déplacer vers `features/`** une feature à la fois (commencer par les plus autonomes).

Chaque étape doit laisser l'app compilable et lançable.
