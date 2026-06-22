# Guide de l'éditeur de ligne

Documentation utilisateur pour l'éditeur de tracé du dashboard de régulation.

> Dans l'application : bouton **Guide** (icône livre) en haut à droite de l'éditeur de ligne.

## Vue d'ensemble

L'éditeur de ligne permet de construire et maintenir le tracé d'une ligne de transport : arrêts, points de passage, topologie (départs convergents, branches) et métadonnées opérationnelles.

L'interface est organisée en trois zones complémentaires :

- **Plan (gauche)** — liste verticale des arrêts, onglets tronc / départs / branches, réordonnancement par glisser-déposer.
- **Carte (centre)** — visualisation géographique, insertion et déplacement des points, tracé automatique.
- **Panneau (droite)** — détail du point sélectionné : type, coordonnées, fiche arrêt, actions hub.

## Hub — point de correspondance

Le **hub** est un arrêt du tronc qui sert de nœud : plusieurs parcours s'y rejoignent ou en partent.

```
         [Départ A] ──────┐
                          ├──► [ HUB ] ──► tronc commun ──► terminus
         [Départ B] ──────┘         │
                                    └──► [Branche] ──► autre terminus
```

- Créer : typifier un arrêt du tronc en « Hub / correspondance ».
- Migration auto : les arrêts amont du hub deviennent des départs convergents.
- Actions hub : ajouter départ, ajouter branche, lister les variantes.

## Départs convergents

Voies **parallèles en amont** qui fusionnent au hub. Ce ne sont pas des arrêts consécutifs sur le tronc.

**Exemple Ligne 1** : Beaujoire et Babinière → Haluchère (hub) → tronc commun.

| Action | Comment |
|--------|---------|
| Créer | Hub → « Ajouter un point de départ » |
| Convertir | Terminus sur tronc → « Rattacher vers [hub] » |
| Éditer | Onglet du départ dans le plan |
| Supprimer | Corbeille sur l'onglet ou barre dédiée (réintègre au tronc) |

## Branches sortantes

Voies **divergentes en aval** partant du hub vers un terminus alternatif (service partiel, extension).

```
  Tronc :  … ──► [ HUB ] ──► … ──► Terminus principal
                      │
  Branche:             └──► … ──► Terminus branche
```

| Action | Comment |
|--------|---------|
| Créer | Hub → « Ajouter une branche vers un terminus » |
| Éditer | Onglet branche dans le plan |
| Supprimer | Panneau latéral → « Supprimer la branche » |

## Modèle de données (résumé)

- **Tronc** — parcours commun (`pointsAller` / `pointsRetour`).
- **Départs** — `originLegs`, rattachés via `mergePointId` au hub.
- **Branches** — `branches`, rattachées via `forkPointId` au hub.
- Chaque **voix** (aller / retour) a sa topologie indépendante.

## Tracé automatique

| Mode | Comportement |
|------|--------------|
| Tramway | Voies GTFS de la ligne |
| Bus / navette | Réseau routier (OSRM) |
| Bateau | Manuel uniquement |

## Raccourcis

- `Ctrl/Cmd + Z` — annuler
- `Ctrl/Cmd + Shift + Z` ou `Ctrl/Cmd + Y` — rétablir
- `Suppr` — supprimer le point sélectionné
- `Échap` — quitter le mode tracé partiel

---

Contenu in-app : `dashboard/lib/line-editor-guide.ts`
