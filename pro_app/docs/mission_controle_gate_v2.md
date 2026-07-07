# Gate V2 — Journée test agents réels

Checklist de validation UX avant ouverture V2 (timeline UI, PJ, superviseur multi-missions).

## Participants

- 3 à 5 agents terrain réels (PAD, Chef, TPE, agents)
- 1 responsable métier observateur (sans guider l’interface)

## Prérequis

- Migration `050_mission_ux.sql` appliquée en environnement de test
- Build Flutter V1 installé sur les terminaux agents
- Au moins une mission de contrôle créée avec équipe complète (PAD + Chef + TPE)

## Scénario nominal (sans explication)

Chaque agent reçoit uniquement : « Prenez votre service et gérez la mission du jour. »

| # | Action | Critère succès |
|---|--------|----------------|
| 1 | Ouvrir l’app, section Contrôle | Identifie sa mission ou l’invitation sans aide |
| 2 | Accepter invitation | Bouton « Rejoindre la mission » compris immédiatement |
| 3 | Préparation | Checklist visible ; comprend pourquoi la mission n’est pas prête si blocage |
| 4 | Présence | Au moins une voie testée (GPS, « Je suis arrivé », ou validation PAD) |
| 5 | Un participant démarre l’intervention | Bouton « Démarrer l’intervention » trouvé dans le workspace ; action impossible tant que la checklist est incomplète |
| 6 | Navigation onglets | Bandeau synthèse cohérent sur Mission / Équipe / Terrain / Discussion |
| 7 | Discussion | Canal mission accessible depuis l’onglet Discussion |
| 8 | Clôture | PAD termine ; débrief affiché avec `#248` + référence secondaire |
| 9 | Oral terrain | Agents utilisent « Mission 248 » (pas le code MC-…) |

## Critères d’acceptation globaux

- [ ] Aucun agent ne demande « où est le briefing ? » ou « c’est quoi le plan ? »
- [ ] Parcours complet réalisé en moins de 15 min de formation cumulée
- [ ] Zéro blocage critique non documenté
- [ ] Retours UX consignés pour V2

## Hors périmètre (ne pas tester en gate V1)

- Timeline UI
- Pièces jointes actives
- Superviseur multi-missions
- Écosystème carte avancé

## Suivi

Consigner date, participants, anomalies et décision go/no-go V2 dans l’outil projet interne.
