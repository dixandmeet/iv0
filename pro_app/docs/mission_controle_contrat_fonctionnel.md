# Contrat fonctionnel — Mission de contrôle (V1)

**Version** : 1.0 — référence produit  
**Périmètre** : Application Aule Pro, mode Contrôle conducteur  
**Statut** : Validé pour développement V1

---

## 1. Contexte et objectif

En salle de prise de service, une équipe de contrôle découvre sa mission : secteur, consignes, composition, rôles (PAD, Chef, TPE). L'application doit permettre à chaque agent de connaître sa mission du jour, de coordonner l'équipe avant le départ, puis de piloter l'intervention sur le terrain.

**Objectif V1** : offrir un espace de travail temporaire centré sur la mission, utilisable sans formation, fidèle au langage métier (« mission », « PAD », « présent »).

---

## 2. Acteurs

| Acteur | Description | Visible dans l'UI |
|--------|-------------|-----------------|
| **Agent** | Membre de l'équipe de contrôle | Oui |
| **PAD** | Pilote opérationnel terrain ; termine l'intervention | Badge PAD |
| **Chef** | Rôle équipe | Badge Chef |
| **TPE** | Rôle équipe | Badge TPE |
| **Responsable** | Référent opérationnel de la mission ; pas forcément le PAD | Libellé « Responsable » |
| **Créateur** | A créé la mission ; droits administratifs | **Jamais affiché** |
| **Superviseur** | Suit plusieurs missions (hors équipe) | V2 — hors V1 |

---

## 3. Objet : Mission de contrôle

Une mission est un **workspace temporaire** regroupant équipe, consignes, discussion, terrain et débrief.

**Identifiant terrain** : `Mission #248` (numéro court, unique, mémorisable).  
Code technique (`MC-20260629-01`) : débrief, exports, back-office uniquement.

**Priorité** : Standard · Renforcée · Prioritaire (affichée sur cartes et détail).

**Objectif** : toujours visible en premier (ex. « Contrôle des titres de transport »).

---

## 4. Phases et états

| Phase | Signification |
|-------|---------------|
| **Préparation** | Équipe en constitution ; rôles modifiables ; pas encore sur le terrain |
| **Intervention** | Mission démarrée par le PAD ; rôles verrouillés |
| **Débrief** | Clôture ; résumé automatique |
| **Archivée** | Historique ; lecture seule |
| **Suspendue** | Réserve V2 (annulation, interruption) — pas de parcours V1 |

---

## 5. Transitions autorisées

```
Création → Préparation
Préparation → Intervention (si checklist OK + PAD)
Intervention → Débrief (PAD termine)
Débrief → Archivée
```

**Conditions démarrage intervention** :
- PAD désigné, Chef désigné, TPE désigné
- Tous les agents invités ont accepté
- Tous les participants sont **présents**
- Action ouverte à **tout participant ayant accepté**

---

## 6. Matrice actions (phase × rôle)

| Phase | Agent | PAD | Créateur (sans label) |
|-------|-------|-----|------------------------|
| Préparation | Rejoindre la mission ; Je suis arrivé ; démarrer si la checklist est complète | Gérer préparation ; confirmer présence ; modifier rôles ; démarrer | Modifier mission ; inviter ; supprimer ; démarrer |
| Intervention | Notes* ; incidents* | Notes* ; incidents* ; terminer | Lecture seule (sauf si aussi PAD) |
| Débrief / Archivée | Lecture | Lecture | Lecture |

\* V1 : message « Bientôt disponible ».

---

## 7. Présence

| État | Signification |
|------|---------------|
| Invitation en attente | Pas encore répondu |
| **Participant** | A rejoint la mission |
| **Présent** | Arrivé en prise de service |

**Passage à Présent** (une seule suffit) :
1. Détection automatique (géolocalisation dépôt)
2. Bouton « Je suis arrivé »
3. Validation par le PAD

Pas de statut « En route ».

---

## 8. Checklist de préparation

Items obligatoires avant démarrage :
- PAD désigné
- Chef désigné
- TPE désigné
- Tous les agents ont accepté
- Tous les agents sont présents

Si un item manque : message explicite (ex. « Julien n'est pas encore arrivé ») et bouton démarrage désactivé.

---

## 9. Cas particuliers

| Cas | Comportement V1 |
|-----|-----------------|
| Créateur ≠ PAD | Créateur gère le cadre ; PAD pilote le terrain |
| Changement PAD en préparation | Autorisé ; checklist recalculée |
| PAD absent, autre agent présent | Rôles modifiables en préparation |
| Invitation expirée | Message « Mission dépassée » ; pas de validation |
| Agent refuse invitation | Mission visible en historique (refusée) |
| Mission sans plan mais invitation | Carte mission via données équipe (fallback) |
| Mission suspendue | Modèle prévu ; flux V2 |

---

## 10. Parcours nominaux

### 10.1 Premier agent (création)
1. Onglet Aujourd'hui → Créer la mission
2. Wizard : secteur, horaires, objectif, consignes, équipe, rôles, responsable, priorité
3. Mission en **Préparation** ; invitations envoyées

### 10.2 Agent invité
1. Carte invitation : Rejoindre / Refuser (sans ouvrir le détail)
2. Devient **Participant**
3. Arrive → **Présent** (auto ou manuel ou PAD)

### 10.3 Démarrage
1. Un participant consulte la checklist
2. Si prête → Démarrer l'intervention
3. Phase **Intervention** ; discussion active

### 10.4 Clôture
1. PAD → Terminer l'intervention
2. Écran **Débrief** (durée, équipe, PAD, responsable)
3. Mission **Archivée** ; discussion lecture seule

---

## 11. Interface — liste des missions

**Trois onglets** : Aujourd'hui · À venir · Historique

**Aujourd'hui** : carte statut visuelle (phase, objectif, priorité, agents prêts, secteur, horaire).

**Workspace mission** : bandeau synthèse persistant + onglets Mission · Équipe · Terrain · Discussion.

---

## 12. Hors périmètre V1

- Timeline affichée à l'écran
- Photos et pièces jointes
- Incidents et notes persistants
- Superviseur multi-missions
- Intégration cartographie écosystème
- Flux mission suspendue

---

## 13. Critères d'acceptation

Scénario test avec 3 à 5 agents réels, sans explication :
1. Création mission
2. Invitations et rôles
3. Présence
4. Démarrage PAD
5. Clôture et débrief

**Succès** : parcours complet sans hésitation ni aide.

---

*Document produit — aucune référence technique (Flutter, Supabase, RPC). Référence développement : plan technique V1.*
