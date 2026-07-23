# Inventaire des pages de l'app web

App **Next.js (App Router)**. Racine de toutes les routes : [`app/`](../app).

Rappels App Router :
- Un segment entre parenthèses (ex. `(dashboard)`) est un **route group** : il **n'apparaît pas** dans l'URL.
- Un segment entre crochets (ex. `[lineId]`) est un **paramètre dynamique**.
- `page.tsx` = page visible · `route.ts` = endpoint API/serveur · `layout.tsx` = gabarit partagé (non listé ici).

Dernière mise à jour : 2026-07-19.

## 📄 Pages publiques / racine

| Page | URL | Fichier |
|---|---|---|
| Accueil | `/` | [app/page.tsx](../app/page.tsx) |
| Connexion | `/login` | [app/login/page.tsx](../app/login/page.tsx) |
| Inscription | `/signup` | [app/signup/page.tsx](../app/signup/page.tsx) |
| Mot de passe oublié | `/forgot-password` | [app/forgot-password/page.tsx](../app/forgot-password/page.tsx) |
| Modifier le mot de passe | `/update-password` | [app/update-password/page.tsx](../app/update-password/page.tsx) |
| Onboarding | `/onboarding` | [app/onboarding/page.tsx](../app/onboarding/page.tsx) |
| Confirmation (auth) | `/auth/confirmation` | [app/auth/confirmation/page.tsx](../app/auth/confirmation/page.tsx) |
| Carte immersive | `/carte-immersive` | [app/carte-immersive/page.tsx](../app/carte-immersive/page.tsx) |
| Configuration réseau | `/configuration/reseau` | [app/configuration/reseau/page.tsx](../app/configuration/reseau/page.tsx) |
| Aide | `/aide` | [app/aide/page.tsx](../app/aide/page.tsx) |
| Contact | `/contact` | [app/contact/page.tsx](../app/contact/page.tsx) |
| Conditions | `/conditions` | [app/conditions/page.tsx](../app/conditions/page.tsx) |
| Confidentialité | `/confidentialite` | [app/confidentialite/page.tsx](../app/confidentialite/page.tsx) |
| Cookies | `/cookies` | [app/cookies/page.tsx](../app/cookies/page.tsx) |
| Suppression de compte | `/suppression-compte` | [app/suppression-compte/page.tsx](../app/suppression-compte/page.tsx) |

## 🗂️ Espace Dashboard (route group `(dashboard)`, URL sans le préfixe)

| Page | URL | Fichier |
|---|---|---|
| Dashboard (accueil) | `/dashboard` | [app/(dashboard)/dashboard/page.tsx](<../app/(dashboard)/dashboard/page.tsx>) |
| Lignes (dashboard) | `/dashboard/lignes` | [.../lignes/page.tsx](<../app/(dashboard)/dashboard/lignes/page.tsx>) |
| Nouvelle ligne | `/dashboard/lignes/nouvelle` | [.../lignes/nouvelle/page.tsx](<../app/(dashboard)/dashboard/lignes/nouvelle/page.tsx>) |
| Détail ligne | `/dashboard/lignes/[lineId]` | [.../lignes/[lineId]/page.tsx](<../app/(dashboard)/dashboard/lignes/[lineId]/page.tsx>) |
| Détail véhicule | `/dashboard/vehicules/[vehicleId]` | [.../vehicules/[vehicleId]/page.tsx](<../app/(dashboard)/dashboard/vehicules/[vehicleId]/page.tsx>) |
| Détail ligne | `/lignes/[lineId]` | [app/(dashboard)/lignes/[lineId]/page.tsx](<../app/(dashboard)/lignes/[lineId]/page.tsx>) |
| Nouvelle ligne | `/lignes/nouvelle` | [app/(dashboard)/lignes/nouvelle/page.tsx](<../app/(dashboard)/lignes/nouvelle/page.tsx>) |
| Arrêts | `/arrets` | [app/(dashboard)/arrets/page.tsx](<../app/(dashboard)/arrets/page.tsx>) |
| Détail arrêt | `/arrets/[stopId]` | [app/(dashboard)/arrets/[stopId]/page.tsx](<../app/(dashboard)/arrets/[stopId]/page.tsx>) |
| Stations | `/stations` | [app/(dashboard)/stations/page.tsx](<../app/(dashboard)/stations/page.tsx>) |
| Détail station | `/stations/[stationId]` | [app/(dashboard)/stations/[stationId]/page.tsx](<../app/(dashboard)/stations/[stationId]/page.tsx>) |
| Arrêt d'une station | `/stations/[stationId]/arrets/[stopId]` | [.../arrets/[stopId]/page.tsx](<../app/(dashboard)/stations/[stationId]/arrets/[stopId]/page.tsx>) |
| Nouvel arrêt de station | `/stations/[stationId]/arrets/nouveau` | [.../arrets/nouveau/page.tsx](<../app/(dashboard)/stations/[stationId]/arrets/nouveau/page.tsx>) |
| Conducteurs | `/conducteurs` | [app/(dashboard)/conducteurs/page.tsx](<../app/(dashboard)/conducteurs/page.tsx>) |
| Missions | `/missions` | [app/(dashboard)/missions/page.tsx](<../app/(dashboard)/missions/page.tsx>) |
| Incidents | `/incidents` | [app/(dashboard)/incidents/page.tsx](<../app/(dashboard)/incidents/page.tsx>) |
| Alertes | `/alertes` | [app/(dashboard)/alertes/page.tsx](<../app/(dashboard)/alertes/page.tsx>) |
| Info voyageur | `/info-voyageur` | [app/(dashboard)/info-voyageur/page.tsx](<../app/(dashboard)/info-voyageur/page.tsx>) |
| Communication | `/communication` | [app/(dashboard)/communication/page.tsx](<../app/(dashboard)/communication/page.tsx>) |
| Collaboration | `/collaboration` | [app/(dashboard)/collaboration/page.tsx](<../app/(dashboard)/collaboration/page.tsx>) |
| Reporting | `/reporting` | [app/(dashboard)/reporting/page.tsx](<../app/(dashboard)/reporting/page.tsx>) |
| Compte | `/compte` | [app/(dashboard)/compte/page.tsx](<../app/(dashboard)/compte/page.tsx>) |

## 👔 Espace Pro (par profil métier)

| Page | URL | Fichier |
|---|---|---|
| Pro (accueil) | `/pro` | [app/pro/page.tsx](../app/pro/page.tsx) |
| Admin | `/pro/admin` | [app/pro/admin/page.tsx](../app/pro/admin/page.tsx) |
| Exploitation | `/pro/exploitation` | [app/pro/exploitation/page.tsx](../app/pro/exploitation/page.tsx) |
| Régulateur | `/pro/regulateur` | [app/pro/regulateur/page.tsx](../app/pro/regulateur/page.tsx) |
| Conducteur | `/pro/conducteur` | [app/pro/conducteur/page.tsx](../app/pro/conducteur/page.tsx) |
| Contrôleur | `/pro/controleur` | [app/pro/controleur/page.tsx](../app/pro/controleur/page.tsx) |
| MSR | `/pro/msr` | [app/pro/msr/page.tsx](../app/pro/msr/page.tsx) |
| VTC | `/pro/vtc` | [app/pro/vtc/page.tsx](../app/pro/vtc/page.tsx) |
| Commerçant | `/pro/commercant` | [app/pro/commercant/page.tsx](../app/pro/commercant/page.tsx) |

## 🛡️ Espace Admin (back-office)

| Page | URL | Fichier |
|---|---|---|
| Admin (accueil) | `/admin` | [app/admin/page.tsx](../app/admin/page.tsx) |
| Supervision | `/admin/supervision` | [app/admin/supervision/page.tsx](../app/admin/supervision/page.tsx) |
| Exploitation | `/admin/exploitation` | [app/admin/exploitation/page.tsx](../app/admin/exploitation/page.tsx) |
| Carte | `/admin/map` | [app/admin/map/page.tsx](../app/admin/map/page.tsx) |
| Analytics | `/admin/analytics` | [app/admin/analytics/page.tsx](../app/admin/analytics/page.tsx) |
| Réseaux | `/admin/networks` | [app/admin/networks/page.tsx](../app/admin/networks/page.tsx) |
| Détail réseau | `/admin/networks/[id]` | [app/admin/networks/[id]/page.tsx](<../app/admin/networks/[id]/page.tsx>) |
| Utilisateurs | `/admin/users` | [app/admin/users/page.tsx](../app/admin/users/page.tsx) |
| Détail utilisateur | `/admin/users/[id]` | [app/admin/users/[id]/page.tsx](<../app/admin/users/[id]/page.tsx>) |
| Permissions | `/admin/permissions` | [app/admin/permissions/page.tsx](../app/admin/permissions/page.tsx) |
| Données transport | `/admin/transport-data` | [app/admin/transport-data/page.tsx](../app/admin/transport-data/page.tsx) |
| Marketplace | `/admin/marketplace` | [app/admin/marketplace/page.tsx](../app/admin/marketplace/page.tsx) |
| App Pro | `/admin/apps/pro` | [app/admin/apps/pro/page.tsx](../app/admin/apps/pro/page.tsx) |
| App Voyageur | `/admin/apps/voyageur` | [app/admin/apps/voyageur/page.tsx](../app/admin/apps/voyageur/page.tsx) |
| Logs | `/admin/logs` | [app/admin/logs/page.tsx](../app/admin/logs/page.tsx) |
| Paramètres | `/admin/settings` | [app/admin/settings/page.tsx](../app/admin/settings/page.tsx) |
| Compte | `/admin/account` | [app/admin/account/page.tsx](../app/admin/account/page.tsx) |

## 🔌 Routes API (endpoints serveur, pas des pages visibles)

| Endpoint | Fichier |
|---|---|
| `/auth/callback` | [app/auth/callback/route.ts](../app/auth/callback/route.ts) |
| `/api/account` | [app/api/account/route.ts](../app/api/account/route.ts) |
| `/api/admin/control-center` | [app/api/admin/control-center/route.ts](../app/api/admin/control-center/route.ts) |
| `/api/carte-immersive/line` | [route.ts](../app/api/carte-immersive/line/route.ts) |
| `/api/carte-immersive/stop-departures` | [route.ts](../app/api/carte-immersive/stop-departures/route.ts) |
| `/api/carte-immersive/stop-lines` | [route.ts](../app/api/carte-immersive/stop-lines/route.ts) |
| `/api/carte-immersive/vehicles` | [route.ts](../app/api/carte-immersive/vehicles/route.ts) |
| `/api/drivers/invite` | [route.ts](../app/api/drivers/invite/route.ts) |
| `/api/network/gtfs-import` | [route.ts](../app/api/network/gtfs-import/route.ts) |
| `/api/geocode` | [route.ts](../app/api/geocode/route.ts) |
| `/api/route` | [route.ts](../app/api/route/route.ts) |
| `/api/client-errors` | [route.ts](../app/api/client-errors/route.ts) |
| `/api/csp-report` | [route.ts](../app/api/csp-report/route.ts) |

---

**Récap :** ~55 pages visibles (public · dashboard · pro · admin) + 13 routes API.
