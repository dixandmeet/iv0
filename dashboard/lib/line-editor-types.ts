export type PointType =
  | "passage"
  | "stop"
  | "terminus_start"
  | "terminus_end"
  | "hub";

export type StopDirection = "aller" | "retour" | "both";

export type LineVoice = "aller" | "retour";

export const LINE_VOICE_LABELS: Record<LineVoice, string> = {
  aller: "Voix 1 · Aller",
  retour: "Voix 2 · Retour",
};

export type EditorTransportMode = "bus" | "tram" | "boat" | "shuttle";

export type EditorLineStatus = "draft" | "validation" | "published";

export interface StopDetails {
  name: string;
  code: string;
  address: string;
  direction: StopDirection;
  order: number;
  travelTimeMinutes: number;
  wheelchairAccessible: boolean;
  connections: string;
  notes: string;
}

export interface RoutePoint {
  id: string;
  coordinates: [number, number];
  type: PointType;
  stop?: StopDetails;
}

/** Branche rattachée à un pôle de correspondance sur le tronc principal. */
export interface LineBranch {
  id: string;
  /** Point hub / correspondance sur le tronc. */
  forkPointId: string;
  /** Libellé affiché (ex. « Vers École Centrale »). */
  label: string;
  /** Nom du terminus de la branche. */
  terminusName: string;
  /** Arrêts de la branche après la bifurcation (jusqu'au terminus). */
  points: RoutePoint[];
}

/** Variante de départ convergent vers un hub de correspondance. */
export interface LineOriginLeg {
  id: string;
  /** Hub où cette variante rejoint le tronc. */
  mergePointId: string;
  /** Libellé affiché (ex. « Depuis Beaujoire »). */
  label: string;
  /** Arrêts avant le hub : terminus départ + arrêts intermédiaires. */
  points: RoutePoint[];
}

export interface LineEditorState {
  id: string;
  name: string;
  shortName: string;
  color: string;
  transportMode: EditorTransportMode;
  directionAller: string;
  directionRetour: string;
  status: EditorLineStatus;
  activeVoice: LineVoice;
  pointsAller: RoutePoint[];
  pointsRetour: RoutePoint[];
  branchesAller: LineBranch[];
  branchesRetour: LineBranch[];
  originLegsAller: LineOriginLeg[];
  originLegsRetour: LineOriginLeg[];
  /** Branche sortante en cours d'édition ; null = tronc principal. */
  activeBranchId: string | null;
  /** Variante de départ en cours d'édition ; null = tronc principal. */
  activeOriginLegId: string | null;
  selectedPointId: string | null;
}

export const POINT_TYPE_LABELS: Record<PointType, string> = {
  passage: "Point de passage",
  stop: "Arrêt voyageur",
  terminus_start: "Terminus départ",
  terminus_end: "Terminus arrivée",
  hub: "Pôle de correspondance",
};

export const POINT_TYPE_COLORS: Record<PointType, string> = {
  passage: "#64748B",
  stop: "#3B82F6",
  terminus_start: "#22C55E",
  terminus_end: "#F97316",
  hub: "#A855F7",
};

export const TRANSPORT_MODE_LABELS: Record<EditorTransportMode, string> = {
  bus: "Bus",
  tram: "Tramway",
  boat: "Bateau",
  shuttle: "Navette",
};

export const LINE_STATUS_LABELS: Record<EditorLineStatus, string> = {
  draft: "Brouillon",
  validation: "En validation",
  published: "Publiée",
};

export const LINE_STATUS_COLORS: Record<EditorLineStatus, string> = {
  draft: "#94A3B8",
  validation: "#F59E0B",
  published: "#22C55E",
};
