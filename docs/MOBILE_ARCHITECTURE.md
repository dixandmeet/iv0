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

## 4. État actuel : vivant vs à nettoyer

Inventaire au moment de la rédaction (chemins relatifs à `lib/screens/`).

### Arbre vivant (atteignable depuis `AppShell`)
`app_shell`, `home_tab` (+ `widgets/home/*`), `itinerary_page` → `route_result_screen` →
`itinerary_guidance_page`, `horaires_page` → `station_search_screen`, `menu_page`,
`stop_detail_page`, `line_detail_page` → `immersive_navigation_page`, `search_route_screen`,
`settings_screen`, `pulse_screen`.

### Code mort à supprimer (importé par personne, ou seulement via des racines mortes)
| Fichier | Raison |
|---|---|
| `aule_shell`, `aule_home_screen`, `aule_map_screen`, `aule_profile_screen` | prototype d'UI alternatif jamais branché |
| `main_shell` | ancien shell, remplacé par `app_shell` (référencé seulement par `privacy_consent_screen`) |
| `privacy_consent_screen` | importé par personne (consentement géré ailleurs — à confirmer) |
| `home_screen`, `map_screen` | atteignables uniquement via `aule_shell` / `main_shell` (morts) |
| `unified_search_screen` | atteignable uniquement via `aule_home_screen` / `home_screen` (morts) |

### Features MVP existantes mais déconnectées (à reconnecter, pas à supprimer)
| Fichier | Fonctionnalité | Action |
|---|---|---|
| `vehicle_tracking_page` (+ `trip_in_progress_page`) | Suivi véhicule en direct | brancher une entrée depuis carte / fiche véhicule |
| `nearby_stops_page` | Arrêts à proximité | fusionner avec `map` ou exposer une entrée |

### Écrans redondants à fusionner
- **Recherche** : `search_route_screen`, `station_search_screen`, `unified_search_screen` → un parcours unique par feature (`journey` pour A→B, `schedules` pour la recherche de station).
- **Navigation/trajet** : `itinerary_guidance_page`, `immersive_navigation_page`, `trip_in_progress_page` → un seul écran de guidage dans `journey`.

---

## 5. Plan de migration (incrémental, une étape livrable à la fois)

1. **Filet de sécurité** : `git init` + premier commit de l'état actuel (le repo n'est pas versionné aujourd'hui).
2. **Supprimer le code mort** (§4) — aucun impact fonctionnel.
3. **Unifier le design system sur Aule** : migrer `home` + `widgets/home/*` (aujourd'hui en Flow) vers Aule, puis retirer `flow_theme` / `flow_widgets` / `flow_primitives`.
4. **Reconnecter** `vehicles` et `nearby_stops` au shell.
5. **Fusionner** les écrans de recherche et de navigation redondants.
6. **Déplacer vers `features/`** une feature à la fois (commencer par les plus autonomes : `vehicles`, `favorites`).

Chaque étape doit laisser l'app compilable et lançable.
