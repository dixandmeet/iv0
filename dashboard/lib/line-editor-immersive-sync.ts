import { createClient } from "@/lib/supabase/client";
import type { LineEditorState, RoutePoint } from "@/lib/line-editor-types";

export type LineTraceDirection = "aller" | "retour";
export type LineTraceVariant = { direction: LineTraceDirection; coordinates: [number, number][] };

type SupabaseRpcError = {
  code?: string;
  message?: string;
  details?: string;
  hint?: string;
};

function reportTraceSyncError(action: string, error: SupabaseRpcError): void {
  const code = error.code ? ` [${error.code}]` : "";
  const message = error.message || "Erreur Supabase inconnue";
  console.error(`${action}${code}: ${message}`, {
    details: error.details ?? null,
    hint: error.hint ?? null,
  });
}

function trunkForVoice(state: LineEditorState, direction: LineTraceDirection): RoutePoint[] {
  return direction === "aller" ? state.pointsAller : state.pointsRetour;
}

function branchesForVoice(state: LineEditorState, direction: LineTraceDirection) {
  return direction === "aller" ? state.branchesAller : state.branchesRetour;
}

function originLegsForVoice(state: LineEditorState, direction: LineTraceDirection) {
  return direction === "aller" ? state.originLegsAller : state.originLegsRetour;
}

/** Construit une variante de tracé par voix (tronc), branche (tronc jusqu'au fork + branche) et origin leg (leg + tronc à partir du merge). */
export function buildLineTraceVariants(state: LineEditorState): LineTraceVariant[] {
  const variants: LineTraceVariant[] = [];

  for (const direction of ["aller", "retour"] as const) {
    const trunk = trunkForVoice(state, direction);
    if (trunk.length >= 2) {
      variants.push({ direction, coordinates: trunk.map((p) => p.coordinates) });
    }

    for (const branch of branchesForVoice(state, direction)) {
      const forkIndex = trunk.findIndex((p) => p.id === branch.forkPointId);
      if (forkIndex === -1) continue;
      const coordinates = [...trunk.slice(0, forkIndex + 1), ...branch.points].map((p) => p.coordinates);
      if (coordinates.length >= 2) variants.push({ direction, coordinates });
    }

    for (const leg of originLegsForVoice(state, direction)) {
      const mergeIndex = trunk.findIndex((p) => p.id === leg.mergePointId);
      if (mergeIndex === -1) continue;
      const coordinates = [...leg.points, ...trunk.slice(mergeIndex)].map((p) => p.coordinates);
      if (coordinates.length >= 2) variants.push({ direction, coordinates });
    }
  }

  return variants;
}

/** Publie le tracé courant de la ligne pour la carte immersive (clé = shortName, aligné sur driver_services.line_id). */
export async function syncPublishedLineTrace(state: LineEditorState): Promise<void> {
  const lineId = state.shortName.trim();
  if (!lineId) return;

  const variants = buildLineTraceVariants(state);
  if (!variants.length) return;

  const supabase = createClient();
  const { error } = await supabase.rpc("publish_line_trace", {
    p_line_id: lineId,
    p_editor_state_id: state.id,
    p_transport_mode: state.transportMode,
    p_color: state.color,
    p_variants: variants,
  });
  if (error) {
    reportTraceSyncError(
      "Échec de publication du tracé sur la carte immersive",
      error,
    );
  }
}

export async function unpublishLineTrace(lineId: string): Promise<void> {
  const trimmed = lineId.trim();
  if (!trimmed) return;

  const supabase = createClient();
  const { error } = await supabase.rpc("unpublish_line_trace", { p_line_id: trimmed });
  if (error) {
    reportTraceSyncError(
      "Échec de la dépublication du tracé de la carte immersive",
      error,
    );
  }
}
