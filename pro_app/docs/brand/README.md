# Identité visuelle Aule Pro

Logo officiel : « A » blanc rubané sur dégradé turquoise → menthe.

## Masters (sources de vérité)

| Fichier | Usage |
| --- | --- |
| `aule_pro_icon_fullbleed_1024.png` | Icône plein cadre (iOS, maskable PWA) — le système applique son propre masque d'angles. |
| `aule_pro_icon_rounded_1024.png` | Icône coins arrondis + transparence (Android legacy, favicon, PWA « any », splash, in-app). |
| `aule_pro_mark.png` | Marque « A » seule sur fond transparent (foreground Android adaptatif, usages sur fond coloré). |

## Charte officielle UI (juillet 2026)

Palette harmonisée appliquée aux écrans de l'app (thème Material, espace
conducteur, écrans d'authentification) — **ne concerne pas l'icône** :

| Rôle | Couleur | Hex |
| --- | --- | --- |
| Primary | Sarcelle | `#1E8D82` |
| Primary Light | Vert d'eau | `#4FC7B1` |
| Accent | Turquoise doux | `#76DCC8` |
| Surface / fond clair | Menthe claire | `#D7F6EF` |
| Accent pastel | Menthe | `#B7EADF` |
| Success | Vert | `#2ECC71` |
| Background | Presque blanc | `#F8FCFB` |
| Card | Blanc pur | `#FFFFFF` |
| Texte principal | Vert pétrole foncé | `#153C3A` |
| Texte secondaire | Vert grisé | `#6E8C89` |
| Ombres | Vert pétrole | `#166B65` |

Définie dans `lib/theme/driver_home_palette.dart` (espace conducteur) et
`lib/widgets/auth/auth_palette.dart` (connexion/inscription) — les deux
partagent ces mêmes teintes. Le seed du thème Material (`main.dart`) utilise
le Primary `#1E8D82`.

Le dégradé du **logo** (icône app, `theme_color` web, fond de l'icône Android
adaptative) reste intentionnellement `#0D595E → #318E81 → #7DF7C0`, tel
quel — il ne suit pas la charte UI ci-dessus et ne doit pas être modifié.

## Déclinaisons générées

- iOS : `ios/Runner/Assets.xcassets/AppIcon.appiconset/` (15 tailles, sans alpha)
  et `LaunchImage.imageset/` (splash 120 pt).
- Android : `mipmap-*/ic_launcher.png` (legacy), `mipmap-anydpi-v26/ic_launcher.xml`
  (adaptatif : fond dégradé XML + `ic_launcher_foreground` + `ic_launcher_monochrome`),
  `mipmap-*/launch_image.png` (splash).
- Web : `web/favicon.png`, `web/icons/Icon-{192,512}.png` (arrondi transparent),
  `Icon-maskable-{192,512}.png` (plein cadre).
- In-app : `assets/images/aule_pro_logo.png` (512) et `aule_pro_mark.png`.

Pour régénérer une taille : partir du master adapté ci-dessus (redimensionnement
Lanczos), jamais d'une déclinaison déjà réduite.
