export interface LineEditorGuideSection {
  id: string;
  title: string;
  paragraphs: string[];
  bullets?: string[];
  /** Schéma ASCII affiché dans un encadré monospace. */
  diagram?: string;
}

export const LINE_EDITOR_GUIDE_SECTIONS: LineEditorGuideSection[] = [
  {
    id: "overview",
    title: "Vue d'ensemble",
    paragraphs: [
      "L'éditeur de ligne permet de construire et maintenir le tracé d'une ligne de transport : arrêts, points de passage, topologie (départs convergents, branches) et métadonnées opérationnelles.",
      "L'interface est organisée en trois zones complémentaires que vous pouvez afficher ou masquer selon vos besoins.",
    ],
    bullets: [
      "Plan (gauche) — liste verticale des arrêts, onglets tronc / départs / branches, réordonnancement par glisser-déposer.",
      "Carte (centre) — visualisation géographique, insertion et déplacement des points, tracé automatique.",
      "Panneau (droite) — détail du point sélectionné : type, coordonnées, fiche arrêt, actions hub.",
    ],
  },
  {
    id: "header",
    title: "En-tête et métadonnées",
    paragraphs: [
      "La barre supérieure regroupe les informations générales de la ligne et les actions globales.",
    ],
    bullets: [
      "Numéro, nom, couleur et mode de transport (bus, tramway, navette, bateau) — le mode influence le tracé automatique.",
      "Statut : brouillon, en validation ou publié.",
      "Voix 1 (aller) et Voix 2 (retour) — chaque sens possède son propre tracé indépendant.",
      "Directions affichées aux voyageurs pour chaque voix.",
      "Indicateurs : nombre d'arrêts, distance totale, durée estimée.",
      "Annuler / Rétablir — l'enregistrement automatique sauvegarde le brouillon localement.",
      "Publier la ligne — passe le statut en validation.",
    ],
  },
  {
    id: "plan",
    title: "Plan vertical",
    paragraphs: [
      "Le plan liste les arrêts du contexte actif. Utilisez les onglets pour basculer entre le tronc principal, les départs convergents et les branches.",
    ],
    bullets: [
      "Tronc — parcours principal après convergence des départs.",
      "Onglets de départ (ex. Beaujoire, Babinière) — variantes qui rejoignent un hub de correspondance.",
      "Onglets de branche — extensions depuis un hub vers un terminus secondaire.",
      "Glisser-déposer (poignée ↕) — réordonner les arrêts dans le contexte actif (tronc, départ ou branche).",
      "Bouton + — ajouter un arrêt après la sélection courante.",
      "Sur un départ actif : renommer le libellé, voir le hub de convergence, supprimer le départ (icônes crayon / corbeille sur l'onglet ou barre dédiée).",
      "Vue Tronc avec topologie complexe : les départs convergents apparaissent au-dessus du hub avec un connecteur « Convergence ».",
    ],
  },
  {
    id: "map",
    title: "Carte",
    paragraphs: [
      "La carte est l'outil principal pour positionner précisément le tracé.",
    ],
    bullets: [
      "Cliquer sur le tracé — insérer un point de passage entre deux points existants.",
      "Marqueurs + sur la ligne — ajouter un point à un emplacement précis.",
      "Glisser un point — ajuster sa position (relâcher pour valider).",
      "Tracer l'itinéraire — calcule automatiquement les points de passage intermédiaires entre chaque paire de points consécutifs.",
      "Effacer le tracé — supprime tous les points de passage (conserve les arrêts).",
      "Barre d'outils Plan / Panneau — masquer ou afficher les colonnes latérales pour agrandir la carte.",
      "Poignée entre le plan et la carte — redimensionner la largeur du plan.",
    ],
  },
  {
    id: "trace",
    title: "Tracé automatique",
    paragraphs: [
      "Le comportement du tracé dépend du mode de transport sélectionné dans l'en-tête.",
    ],
    bullets: [
      "Tramway — le tracé suit les voies GTFS enregistrées pour la ligne (réseau réel du tram). Les arrêts doivent être proches du tracé GTFS (< ~180 m).",
      "Bus / navette — le tracé suit le réseau routier (OSRM).",
      "Bateau — tracé automatique non disponible ; positionnez les points manuellement.",
      "Tracé partiel — sélectionnez un point de passage, puis « Proposer un tracé » dans le panneau pour tracer uniquement jusqu'à un point aval.",
    ],
  },
  {
    id: "sidebar",
    title: "Panneau latéral — types de points",
    paragraphs: [
      "Chaque point de la ligne a un rôle. Sélectionnez-le sur la carte ou dans le plan pour le configurer.",
    ],
    bullets: [
      "Point de passage — façonne la géométrie du tracé sans apparaître au plan voyageur.",
      "Arrêt voyageur — arrêt desservi, avec nom, code, accessibilité, temps depuis l'arrêt précédent.",
      "Terminus départ / Terminus arrivée — extrémités de la ligne ou d'une branche.",
      "Hub (correspondance) — point de bifurcation ou de convergence ; permet d'ajouter des départs ou des branches.",
      "Autocomplétion — recherchez un arrêt référencé pour préremplir nom, code et coordonnées.",
      "Coordonnées — saisie manuelle ou ajustement fin après déplacement sur la carte.",
    ],
  },
  {
    id: "hub",
    title: "Hub — point de correspondance",
    paragraphs: [
      "Le hub (type « Hub / correspondance ») est un arrêt du tronc principal qui sert de nœud topologique : plusieurs parcours distincts s'y rejoignent ou en partent, sans dupliquer le tronc commun.",
      "Contrairement à un arrêt classique, le hub structure la ligne en réseau. Il apparaît une seule fois sur le tronc, mais peut être relié à plusieurs départs convergents (entrées) et/ou branches sortantes (sorties).",
      "Sur la carte, le tronc et chaque départ/branche sont tracés comme des segments séparés qui se connectent visuellement au hub.",
    ],
    diagram: [
      "         [Départ A] ──────┐",
      "                          ├──► [ HUB ] ──► tronc commun ──► terminus",
      "         [Départ B] ──────┘         │",
      "                                    └──► [Branche] ──► autre terminus",
    ].join("\n"),
    bullets: [
      "Créer un hub — sélectionnez un arrêt du tronc et changez son type en « Hub / correspondance » dans le panneau latéral.",
      "Migration automatique — si des arrêts précèdent déjà le hub sur le tronc, l'éditeur les transforme en départs convergents distincts (ex. Beaujoire et Babinière avant Haluchère).",
      "Actions disponibles sur un hub — ajouter un point de départ convergent, ajouter une branche sortante, consulter la liste des variantes rattachées.",
      "Le hub reste un arrêt à part entière : nom, code, accessibilité, correspondances voyageur.",
    ],
  },
  {
    id: "origin-legs",
    title: "Départs convergents",
    paragraphs: [
      "Un départ convergent (origin leg) modélise une variante de début de ligne : un terminus de départ indépendant rejoint le tronc au hub. Les départs ne sont pas des arrêts consécutifs sur le tronc — ce sont des voies parallèles qui fusionnent.",
      "Cas typique — Ligne 1 tramway : les courses peuvent partir de Beaujoire ou de Babinière, converger à Haluchère - Batignolles, puis suivre le même tronc jusqu'au terminus commun.",
      "Chaque départ possède sa propre liste d'arrêts (terminus départ + arrêts intermédiaires éventuels), son libellé et son tracé cartographique jusqu'au hub.",
    ],
    diagram: [
      "  Onglet « Beaujoire »     Onglet « Babinière »     Onglet « Tronc »",
      "  ───────────────────     ────────────────────     ─────────────────",
      "  Beaujoire (T)           Babinière (T)            Haluchère (HUB)",
      "       │                        │                  Pin Sec",
      "       └──────── convergence ───┘                  Souillarderie",
      "                                                   …",
    ].join("\n"),
    bullets: [
      "Créer — sélectionnez le hub → « Ajouter un point de départ ». Un nouvel onglet apparaît dans le plan avec un terminus vierge à positionner.",
      "Convertir un arrêt existant — sur le tronc, sélectionnez un terminus départ situé avant le hub → « Rattacher vers [nom du hub] ». L'arrêt quitte le tronc et devient le terminus d'un départ convergent.",
      "Éditer — cliquez l'onglet du départ dans le plan : vous ne voyez que les arrêts de cette variante. Ajoutez, réordonnez (glisser-déposer) et tracez l'itinéraire indépendamment.",
      "Renommer / supprimer — barre sous les onglets ou icônes crayon/corbeille sur l'onglet actif. La suppression réintègre les arrêts du départ dans le tronc.",
      "Vue Tronc — les départs s'affichent au-dessus du hub avec un libellé « Convergence », sans mélanger l'ordre du tronc principal.",
    ],
  },
  {
    id: "branches",
    title: "Branches sortantes",
    paragraphs: [
      "Une branche modélise un débranchement après un hub : une partie des courses continue sur le tronc principal, d'autres empruntent un itinéraire alternatif vers un terminus différent (service partiel, extension ou boucle).",
      "La branche commence au hub (point de fourche) et s'étend avec ses propres arrêts. Le tronc et la branche partagent le hub comme arrêt commun, mais divergent ensuite.",
      "Exemple — après une correspondance majeure, certaines courses vont au terminus principal tandis que d'autres desservent une zone annexe via une branche dédiée.",
    ],
    diagram: [
      "  Tronc :  … ──► [ HUB ] ──► Arrêt 1 ──► Arrêt 2 ──► Terminus principal",
      "                      │",
      "  Branche:             └──► Arrêt A ──► Arrêt B ──► Terminus branche",
    ].join("\n"),
    bullets: [
      "Créer — sélectionnez le hub → « Ajouter une branche vers un terminus ». Un onglet de branche s'ouvre ; le premier arrêt est créé après le hub.",
      "Éditer — onglet de la branche dans le plan : liste verticale des arrêts propres à cette variante, réordonnancement et tracé indépendants.",
      "Métadonnées — libellé de branche et nom du terminus modifiables dans le panneau latéral quand la branche est active.",
      "Supprimer — bouton « Supprimer la branche » dans le panneau ; les arrêts de la branche sont retirés, le hub et le tronc restent intacts.",
      "Sur la carte — le tronc s'arrête au hub puis reprend ; la branche est dessinée comme un segment distinct partant du hub.",
    ],
  },
  {
    id: "topology",
    title: "Comprendre l'ensemble",
    paragraphs: [
      "Le tronc est la colonne vertébrale : il contient le parcours commun après convergence des départs et avant/après les éventuelles fourches. Les départs et branches ne dupliquent pas le tronc — ils s'y rattachent par référence au hub.",
      "Chaque voix (aller / retour) possède sa propre topologie : un hub, des départs et des branches sur la voix 1 ne sont pas partagés avec la voix 2.",
    ],
    bullets: [
      "Tronc — pointsAller / pointsRetour : arrêts communs, dont le ou les hubs.",
      "Départs — originLegs : variantes amont convergentes (mergePointId → id du hub).",
      "Branches — branches : variantes aval divergentes (forkPointId → id du hub).",
      "Onglets du plan — Tronc | Départ 1 | Beaujoire | … | Branche X : chaque contexte isole sa liste d'arrêts pour l'édition.",
      "Terminus affichés en en-tête — agrégation de tous les terminus départ (départs + tronc) et terminus arrivée (tronc + branches).",
      "Complexité — dès qu'au moins un départ ou une branche existe, les onglets et chips « Départs convergents » apparaissent automatiquement.",
    ],
  },
  {
    id: "shortcuts",
    title: "Raccourcis clavier",
    paragraphs: [],
    bullets: [
      "Ctrl/Cmd + Z — annuler.",
      "Ctrl/Cmd + Shift + Z ou Ctrl/Cmd + Y — rétablir.",
      "Suppr / Retour arrière — supprimer le point sélectionné (hors champs de saisie).",
      "Échap — quitter le mode tracé partiel (sélection destination sur la carte).",
    ],
  },
  {
    id: "workflow",
    title: "Parcours recommandé",
    paragraphs: [
      "Pour créer ou restructurer une ligne, suivez généralement ces étapes :",
    ],
    bullets: [
      "1. Définir le mode, la couleur et les directions dans l'en-tête.",
      "2. Placer les arrêts principaux sur la carte ou via le plan (+).",
      "3. Typifier les points (terminus, hub, arrêts intermédiaires).",
      "4. Configurer les hubs, départs convergents ou branches si nécessaire (voir sections dédiées).",
      "5. Lancer « Tracer l'itinéraire » pour générer la géométrie fine.",
      "6. Ajuster manuellement les points de passage restants.",
      "7. Compléter les fiches arrêts (nom, code, accessibilité, temps de parcours).",
      "8. Vérifier les deux voix (aller / retour), puis publier.",
    ],
  },
];

export const LINE_EDITOR_GUIDE_TITLE = "Guide de l'éditeur de ligne";
