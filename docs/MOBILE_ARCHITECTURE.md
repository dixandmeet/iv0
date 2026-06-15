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

  | Fichier vivant en Flow | Ampleur | Note |
  |---|---|---|
  | `screens/route_result_screen.dart` | ~54 refs, 1053 l. | écran central, **à migrer avec rendu visible** |
  | `screens/itinerary_guidance_page.dart` | ~48 refs, 1450 l. | guidage, **à migrer avec rendu visible** |
  | `screens/settings_screen.dart` | ~31 refs, 307 l. | mécanique |
  | `screens/station_search_screen.dart` | ~25 refs, 279 l. | mécanique |
  | `services/map_service.dart` | 13 refs (constantes couleur) | trivial |

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
3. **Unifier sur Aule** : migrer les 5 fichiers Flow vivants (§4). Les 2 gros écrans de guidage
   doivent être migrés **app lancée** (vérification visuelle), pas à l'aveugle. Puis supprimer Flow.
4. **Reconnecter** les features MVP orphelines : suivi véhicule, arrêts à proximité, temps réel opérateur.
5. **Trancher l'accueil** : dashboard riche (reconstruit en Aule) vs accueil simple actuel.
6. **Fusionner** les écrans de recherche/navigation redondants.
7. **Déplacer vers `features/`** une feature à la fois (commencer par les plus autonomes).

Chaque étape doit laisser l'app compilable et lançable.
