export type TravelerCommentCategory =
  | "incident"
  | "delay"
  | "crowding"
  | "cleanliness"
  | "accessibility"
  | "safety"
  | "comfort"
  | "driver"
  | "other";

export interface TravelerComment {
  id: string;
  authorName: string;
  lineName: string;
  vehicleService: string;
  stopName: string;
  createdAt: Date;
  category: TravelerCommentCategory;
  message: string;
  reactionCount: number;
  reportCount: number;
  authorCertified: boolean;
}

export const TRAVELER_COMMENT_MODERATION_THRESHOLD = 3;

export const TRAVELER_COMMENT_CATEGORY_LABELS: Record<TravelerCommentCategory, string> = {
  incident: "Incident",
  delay: "Retard",
  crowding: "Affluence",
  cleanliness: "Propreté",
  accessibility: "Accessibilité",
  safety: "Sécurité",
  comfort: "Confort",
  driver: "Conducteur",
  other: "Autre",
};

export const TRAVELER_COMMENT_CATEGORY_COLORS: Record<TravelerCommentCategory, string> = {
  incident: "#EF4444",
  delay: "#F59E0B",
  crowding: "#7C3AED",
  cleanliness: "#16A34A",
  accessibility: "#2563EB",
  safety: "#DC2626",
  comfort: "#0EA5A4",
  driver: "#0891B2",
  other: "#64748B",
};

export function isTravelerCommentActive(comment: TravelerComment): boolean {
  return Date.now() - comment.createdAt.getTime() < 24 * 60 * 60 * 1000;
}

export function isTravelerCommentHidden(comment: TravelerComment): boolean {
  return comment.reportCount >= TRAVELER_COMMENT_MODERATION_THRESHOLD;
}

export function travelerCommentElapsedLabel(comment: TravelerComment): string {
  const diffMin = Math.floor((Date.now() - comment.createdAt.getTime()) / 60000);
  if (diffMin < 1) return "à l'instant";
  if (diffMin < 60) return `il y a ${diffMin} min`;
  const diffH = Math.floor(diffMin / 60);
  if (diffH < 24) return `il y a ${diffH} h`;
  return "expiré";
}

export function travelerCommentInitials(authorName: string): string {
  const compact = authorName.replace(/[^A-Za-z0-9]/g, "");
  if (!compact) return "?";
  return compact.slice(0, 2).toUpperCase();
}

function demoComments(
  lineName: string,
  vehicleService: string,
  stopName: string,
  currentDelayMin: number,
): TravelerComment[] {
  const now = Date.now();

  return [
    ...(currentDelayMin > 0
      ? [
          {
            id: "nadia-delay",
            authorName: "Nadia_44",
            lineName,
            vehicleService,
            stopName,
            createdAt: new Date(now - 4 * 60 * 1000),
            category: "delay" as const,
            message: `Bus en retard d'environ ${currentDelayMin} minute${currentDelayMin > 1 ? "s" : ""}.`,
            reactionCount: 5,
            reportCount: 0,
            authorCertified: true,
          },
        ]
      : []),
    {
      id: "yannick-crowding",
      authorName: "YannickL",
      lineName,
      vehicleService,
      stopName: "Les Salles",
      createdAt: new Date(now - 12 * 60 * 1000),
      category: "crowding",
      message: "Le bus est assez bondé en heure de pointe.",
      reactionCount: 3,
      reportCount: 0,
      authorCertified: true,
    },
    {
      id: "sarah-driver",
      authorName: "SarahB",
      lineName,
      vehicleService,
      stopName,
      createdAt: new Date(now - 25 * 60 * 1000),
      category: "driver",
      message: "Conducteur très sympa, conduite au top !",
      reactionCount: 2,
      reportCount: 0,
      authorCertified: true,
    },
    {
      id: "tom-clean",
      authorName: "Tom_85",
      lineName,
      vehicleService,
      stopName: "Haluchère - Batignolles",
      createdAt: new Date(now - 40 * 60 * 1000),
      category: "cleanliness",
      message: "Bus propre et bien entretenu.",
      reactionCount: 1,
      reportCount: 0,
      authorCertified: true,
    },
    {
      id: "lea-access",
      authorName: "LeaPMR",
      lineName,
      vehicleService,
      stopName,
      createdAt: new Date(now - 67 * 60 * 1000),
      category: "accessibility",
      message: "Rampe disponible, montée possible sans difficulté.",
      reactionCount: 6,
      reportCount: 0,
      authorCertified: true,
    },
    {
      id: "moderated",
      authorName: "Voyageur32",
      lineName,
      vehicleService,
      stopName: "Koufra",
      createdAt: new Date(now - 2 * 60 * 60 * 1000),
      category: "other",
      message: "Message masqué après plusieurs signalements.",
      reactionCount: 0,
      reportCount: 3,
      authorCertified: false,
    },
    {
      id: "expired",
      authorName: "OldTrip",
      lineName,
      vehicleService,
      stopName,
      createdAt: new Date(now - 25 * 60 * 60 * 1000),
      category: "safety",
      message: "Commentaire expiré automatiquement.",
      reactionCount: 1,
      reportCount: 0,
      authorCertified: true,
    },
  ];
}

export function travelerCommentsForVehicle(
  lineName: string,
  vehicleService: string,
  stopName?: string,
  currentDelayMin = 0,
): TravelerComment[] {
  const stop = stopName ?? "Bd de Boulon";
  return demoComments(lineName, vehicleService, stop, currentDelayMin)
    .filter((comment) => isTravelerCommentActive(comment))
    .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
}
