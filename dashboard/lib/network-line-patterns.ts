/**
 * Parcours commerciaux de référence qui ne peuvent pas être reconstruits à
 * partir de la table gtfs_stop_times seule (services partiels, branches, etc.).
 *
 * Les noms sont résolus à l'exécution vers les arrêts actifs du réseau. Ce
 * registre est volontairement indépendant des identifiants de quais, qui
 * changent selon le sens et les versions du GTFS.
 */
export interface NetworkLinePattern {
  id: string;
  destination: string;
  stops: string[];
}

const LINE_1_COMMON_WEST = [
  "François Mitterrand",
  "Tourmaline",
  "Schoelcher",
  "Frachon",
  "Neruda",
  "Tertre",
  "Romanet",
  "Mendès France - Bellevue",
  "Romain Rolland",
  "Lauriers",
  "Jean Moulin",
  "Croix Bonneau",
];

const LINE_1_COMMON_TRUNK = [
  "Égalité",
  "Du Chaffault",
  "Gare Maritime",
  "Chantiers Navals",
  "Médiathèque",
  "Commerce",
  "Bouffay",
  "Duchesse Anne - Château",
  "Gare Nord - Jardin des Plantes",
  "Manufacture",
  "Moutonnerie",
  "Hôpital Bellier",
  "Bd de Doulon",
  "Mairie de Doulon",
  "Landreau",
  "Souillarderie",
  "Pin Sec",
  "Haluchère - Batignolles",
];

const LINE_1_WEST_BRANCHES = {
  francoisMitterrand: LINE_1_COMMON_WEST,
  jamet: ["Jamet", "Croix Bonneau"],
} as const;

const LINE_1_EAST_BRANCHES = {
  beaujoire: ["Halvêque", "Beaujoire"],
  babiniere: ["Ranzay", "Babinière"],
} as const;

function line1Stops(
  west: keyof typeof LINE_1_WEST_BRANCHES,
  east: keyof typeof LINE_1_EAST_BRANCHES,
): string[] {
  return [
    ...LINE_1_WEST_BRANCHES[west],
    ...LINE_1_COMMON_TRUNK,
    ...LINE_1_EAST_BRANCHES[east],
  ];
}

const NETWORK_LINE_PATTERNS: Record<string, NetworkLinePattern[]> = {
  "1": [
    {
      id: "francois-mitterrand-beaujoire",
      destination: "Beaujoire",
      stops: line1Stops("francoisMitterrand", "beaujoire"),
    },
    {
      id: "francois-mitterrand-babiniere",
      destination: "Babinière",
      stops: line1Stops("francoisMitterrand", "babiniere"),
    },
    {
      id: "jamet-beaujoire",
      destination: "Beaujoire",
      stops: line1Stops("jamet", "beaujoire"),
    },
    {
      id: "jamet-babiniere",
      destination: "Babinière",
      stops: line1Stops("jamet", "babiniere"),
    },
  ],
};

export function getNetworkLinePatterns(routeId: string): NetworkLinePattern[] {
  return NETWORK_LINE_PATTERNS[routeId] ?? [];
}
