# Architecture — Mission comme ressource métier Aule

**Version** : 1.0  
**Statut** : Référence architecture V1+

---

## Vision

La **Mission** est une ressource métier transverse dans Aule Pro. Le modèle V1 (Mission de contrôle) sert de référence pour les futures extensions : intervention, UMTC, événementiel, régulation.

```
Mission (ressource métier)
├── Équipe          — composition, rôles, présence, invitations
├── Discussion      — canal temporaire, lecture seule à la clôture
├── Ressources      — PJ (photos, docs, audio) — V2
├── Activité        — signaux temps réel (connectés, durée, messages)
├── Audit           — journal interne (support, conformité)
├── Événements      — timeline métier persistée (V2 UI)
├── Notifications   — bus découplé des mutations
├── Géolocalisation — présence dépôt, secteur, carte terrain
└── Débrief         — résumé clôture, archivage
```

---

## Alignement plateforme

| Couche Aule | Rôle mission |
|-------------|--------------|
| `platform_resources` | Ressource type `mission`, statut `temporary` → `closed` |
| `sync_mission_resource` | Création canal discussion à la naissance MSR |
| `DiscussionService` | Messagerie équipe |
| `LocationService` | Géorepérage présence |

---

## Phases (cycle de vie)

| Phase | Ressource status | Discussion |
|-------|------------------|------------|
| Préparation | active | écriture |
| Intervention | active | écriture |
| Débrief | closing | lecture |
| Archivée | closed | lecture seule |

---

## Identifiants

| Champ | Usage |
|-------|-------|
| `mission_display_number` | UI terrain : Mission #248 |
| `mission_reference` | Admin, exports : MC-20260629-01 |
| UUID technique | Interne uniquement |

---

## Événements métier (V1 persistés, V2 affichés)

`MISSION_CREATED`, `MEMBER_JOINED`, `MEMBER_DECLINED`, `MEMBER_PRESENT`, `ROLE_UPDATED`, `SECTOR_UPDATED`, `MISSION_STARTED`, `MISSION_COMPLETED`, `MISSION_SUSPENDED`

Double persistance : `mission_events` (produit/analytics) + `mission_audit_log` (support).

---

## Extensibilité

Nouveaux types de mission héritent de :
- Workspace shell (bandeau + onglets)
- Matrice phase × rôle
- Bus événements + notifications
- Ressource plateforme + discussion

Éviter les stacks parallèles par vertical métier.

---

*Référence technique : migration 050, `ControlPlanService`, `MissionEventBus`.*
