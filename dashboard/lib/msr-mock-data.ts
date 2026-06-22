export type MsrMissionPriority = "high" | "medium" | "low";
export type MsrDisplayStatus = "in_progress" | "planned" | "completed";

export interface MsrAgent {
  id: string;
  name: string;
  initials: string;
  available: boolean;
  position: [number, number];
  teamId: string;
}

export interface MsrTeam {
  id: string;
  name: string;
  manager: { name: string; initials: string };
  color: string;
  zoneId: string;
}

export interface MsrZone {
  id: string;
  teamId: string;
  teamName: string;
  color: string;
  fillColor: string;
  agentCount: number;
  coordinates: [number, number][];
}

export interface MsrStation {
  id: string;
  name: string;
  position: [number, number];
}

export interface MsrMapIncident {
  id: string;
  title: string;
  position: [number, number];
}

export interface MsrMissionDemo {
  id: string;
  title: string;
  status: MsrDisplayStatus;
  priority: MsrMissionPriority;
  teamId: string;
  zoneLabel: string;
  startTime: string;
  endTime: string;
  agentCount: number;
  remainingTime?: string;
  description: string;
  lines: string[];
  stationCount: number;
  instructions: string[];
  startLabel: string;
  endLabel: string;
  duration: string;
  agentIds: string[];
}

export const MSR_AGENTS: MsrAgent[] = [
  { id: "a1", name: "Thomas Martin", initials: "TM", available: true, position: [-1.558, 47.216], teamId: "nord" },
  { id: "a2", name: "Sophie Bernard", initials: "SB", available: true, position: [-1.552, 47.219], teamId: "nord" },
  { id: "a3", name: "Lucas Petit", initials: "LP", available: true, position: [-1.546, 47.222], teamId: "nord" },
  { id: "a4", name: "Emma Dubois", initials: "ED", available: true, position: [-1.541, 47.225], teamId: "nord" },
  { id: "a5", name: "Julien Moreau", initials: "JM", available: true, position: [-1.555, 47.214], teamId: "centre" },
  { id: "a6", name: "Claire Rousseau", initials: "CR", available: false, position: [-1.549, 47.217], teamId: "centre" },
  { id: "a7", name: "Antoine Leroy", initials: "AL", available: true, position: [-1.562, 47.211], teamId: "sud" },
  { id: "a8", name: "Marie Girard", initials: "MG", available: true, position: [-1.538, 47.228], teamId: "ouest" },
];

export const MSR_TEAMS: MsrTeam[] = [
  { id: "nord", name: "Équipe Nord", manager: { name: "Thomas Martin", initials: "TM" }, color: "#3B82F6", zoneId: "zone-nord" },
  { id: "centre", name: "Équipe Centre", manager: { name: "Julien Moreau", initials: "JM" }, color: "#22C55E", zoneId: "zone-centre" },
  { id: "sud", name: "Équipe Sud", manager: { name: "Antoine Leroy", initials: "AL" }, color: "#F97316", zoneId: "zone-sud" },
  { id: "ouest", name: "Équipe Ouest", manager: { name: "Marie Girard", initials: "MG" }, color: "#A855F7", zoneId: "zone-ouest" },
];

export const MSR_ZONES: MsrZone[] = [
  {
    id: "zone-nord",
    teamId: "nord",
    teamName: "Équipe Nord",
    color: "#3B82F6",
    fillColor: "rgba(59, 130, 246, 0.18)",
    agentCount: 4,
    coordinates: [
      [-1.568, 47.208], [-1.535, 47.208], [-1.535, 47.228], [-1.568, 47.228], [-1.568, 47.208],
    ],
  },
  {
    id: "zone-centre",
    teamId: "centre",
    teamName: "Équipe Centre",
    color: "#22C55E",
    fillColor: "rgba(34, 197, 94, 0.18)",
    agentCount: 2,
    coordinates: [
      [-1.558, 47.212], [-1.544, 47.212], [-1.544, 47.220], [-1.558, 47.220], [-1.558, 47.212],
    ],
  },
  {
    id: "zone-sud",
    teamId: "sud",
    teamName: "Équipe Sud",
    color: "#F97316",
    fillColor: "rgba(249, 115, 22, 0.18)",
    agentCount: 1,
    coordinates: [
      [-1.570, 47.204], [-1.556, 47.204], [-1.556, 47.210], [-1.570, 47.210], [-1.570, 47.204],
    ],
  },
  {
    id: "zone-ouest",
    teamId: "ouest",
    teamName: "Équipe Ouest",
    color: "#A855F7",
    fillColor: "rgba(168, 85, 247, 0.18)",
    agentCount: 1,
    coordinates: [
      [-1.542, 47.224], [-1.530, 47.224], [-1.530, 47.234], [-1.542, 47.234], [-1.542, 47.224],
    ],
  },
];

export const MSR_STATIONS: MsrStation[] = [
  { id: "s1", name: "Commerce", position: [-1.5608, 47.2134] },
  { id: "s2", name: "Gare Maritime", position: [-1.557, 47.216] },
  { id: "s3", name: "Place du Cirque", position: [-1.553, 47.219] },
  { id: "s4", name: "Talensac", position: [-1.549, 47.222] },
  { id: "s5", name: "Haluchère", position: [-1.5378, 47.2438] },
  { id: "s6", name: "Beaujoire", position: [-1.532, 47.251] },
  { id: "s7", name: "Doulon", position: [-1.528, 47.238] },
  { id: "s8", name: "Ranzay", position: [-1.565, 47.209] },
];

export const MSR_INCIDENTS: MsrMapIncident[] = [
  { id: "i1", title: "Affluence anormale", position: [-1.551, 47.218] },
  { id: "i2", title: "Retard signalé", position: [-1.545, 47.226] },
];

export const MSR_MISSIONS: MsrMissionDemo[] = [
  {
    id: "m1",
    title: "Contrôle Ligne T1",
    status: "in_progress",
    priority: "high",
    teamId: "nord",
    zoneLabel: "Commerce → Haluchère",
    startTime: "07:00",
    endTime: "11:00",
    agentCount: 4,
    remainingTime: "2h 15m restantes",
    description:
      "Mission de contrôle et de surveillance sur la ligne T1, axe Commerce – Haluchère. Renforcer la présence visible et assurer la fluidité des correspondances.",
    lines: ["T1"],
    stationCount: 14,
    instructions: [
      "Renforcer la présence sur les quais",
      "Vérifier la fluidité des correspondances",
      "Contrôler la montée à bord",
      "Remonter tout incident via l'application",
    ],
    startLabel: "Aujourd'hui 07:00",
    endLabel: "Aujourd'hui 11:00",
    duration: "4h 00m",
    agentIds: ["a1", "a2", "a3", "a4"],
  },
  {
    id: "m2",
    title: "Surveillance Centre-ville",
    status: "in_progress",
    priority: "medium",
    teamId: "centre",
    zoneLabel: "Centre historique",
    startTime: "08:00",
    endTime: "12:00",
    agentCount: 2,
    remainingTime: "3h 40m restantes",
    description: "Surveillance renforcée du centre-ville et des axes piétons à forte affluence.",
    lines: ["T1", "Bus C3"],
    stationCount: 8,
    instructions: [
      "Patrouille visible sur les axes principaux",
      "Assister les voyageurs en correspondance",
    ],
    startLabel: "Aujourd'hui 08:00",
    endLabel: "Aujourd'hui 12:00",
    duration: "4h 00m",
    agentIds: ["a5", "a6"],
  },
  {
    id: "m3",
    title: "Sécurité Ligne T2",
    status: "planned",
    priority: "high",
    teamId: "sud",
    zoneLabel: "Gare Sud → Zénith",
    startTime: "14:00",
    endTime: "18:00",
    agentCount: 3,
    description: "Mission de sécurité préventive sur la ligne T2 en période de forte affluence.",
    lines: ["T2"],
    stationCount: 11,
    instructions: [
      "Positionnement aux points sensibles",
      "Coordination avec le régulateur",
    ],
    startLabel: "Aujourd'hui 14:00",
    endLabel: "Aujourd'hui 18:00",
    duration: "4h 00m",
    agentIds: ["a7"],
  },
  {
    id: "m4",
    title: "Contrôle Soirée",
    status: "planned",
    priority: "low",
    teamId: "ouest",
    zoneLabel: "Beaujoire → Doulon",
    startTime: "19:00",
    endTime: "23:00",
    agentCount: 2,
    description: "Contrôle de fin de journée sur les dessertes ouest du réseau.",
    lines: ["Bus C4"],
    stationCount: 6,
    instructions: ["Vérifier la fermeture des accès", "Rapport de fin de mission"],
    startLabel: "Aujourd'hui 19:00",
    endLabel: "Aujourd'hui 23:00",
    duration: "4h 00m",
    agentIds: ["a8"],
  },
  {
    id: "m5",
    title: "Vigilance Match",
    status: "completed",
    priority: "low",
    teamId: "nord",
    zoneLabel: "Beaujoire",
    startTime: "17:00",
    endTime: "20:00",
    agentCount: 4,
    description: "Mission de vigilance lors d'un événement sportif à la Beaujoire.",
    lines: ["T1", "Bus E3"],
    stationCount: 3,
    instructions: ["Gestion des flux sortants", "Coordination avec les forces de l'ordre"],
    startLabel: "Hier 17:00",
    endLabel: "Hier 20:00",
    duration: "3h 00m",
    agentIds: ["a1", "a2", "a3", "a4"],
  },
];

export const MSR_KPI = {
  missionsInProgress: 12,
  missionsDelta: 2,
  agentsAvailable: 8,
  agentsTotal: 24,
  activeTeams: 4,
  teamsDelta: 1,
  zonesCovered: 7,
  zonesTotal: 12,
  criticalAlerts: 2,
};

export function priorityLabel(p: MsrMissionPriority): string {
  switch (p) {
    case "high":
      return "Haute";
    case "medium":
      return "Moyenne";
    case "low":
      return "Basse";
  }
}

export function priorityColor(p: MsrMissionPriority): string {
  switch (p) {
    case "high":
      return "#EF4444";
    case "medium":
      return "#F97316";
    case "low":
      return "#22C55E";
  }
}

export function displayStatusLabel(s: MsrDisplayStatus): string {
  switch (s) {
    case "in_progress":
      return "En cours";
    case "planned":
      return "Planifiée";
    case "completed":
      return "Terminée";
  }
}

export function displayStatusColor(s: MsrDisplayStatus): string {
  switch (s) {
    case "in_progress":
      return "#3B82F6";
    case "planned":
      return "#64748B";
    case "completed":
      return "#22C55E";
  }
}

export function getTeamById(id: string): MsrTeam | undefined {
  return MSR_TEAMS.find((t) => t.id === id);
}

export function getAgentsForMission(mission: MsrMissionDemo): MsrAgent[] {
  return MSR_AGENTS.filter((a) => mission.agentIds.includes(a.id));
}
