import "server-only";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { NetworkContextValue, NetworkMembershipRole } from "./types";

const PILOT_CODE = "naolib-nantes";
const PILOT_ID = "00000000-0000-4000-8000-000000000001";

export async function loadNetworkContext(
  supabase: SupabaseClient,
  userId: string,
): Promise<NetworkContextValue | null> {
  // Chemin nominal après déploiement de la migration multi-réseaux.
  const { data: ensuredId } = await supabase.rpc("ensure_current_user_network");
  const { data: profile } = await supabase
    .from("user_profiles")
    .select("active_network_id")
    .eq("id", userId)
    .maybeSingle();

  const networkId = (profile?.active_network_id as string | null) ??
    (typeof ensuredId === "string" ? ensuredId : null);

  if (networkId) {
    const [{ data: network }, { data: membership }] = await Promise.all([
      supabase
        .from("networks")
        .select("id, name, code, operator, territory, status, setup_completed_at")
        .eq("id", networkId)
        .maybeSingle(),
      supabase
        .from("network_memberships")
        .select("membership_role")
        .eq("network_id", networkId)
        .eq("user_id", userId)
        .maybeSingle(),
    ]);

    if (network && membership) {
      const membershipRole = membership.membership_role as NetworkMembershipRole;
      return {
        network: {
          id: network.id as string,
          name: network.name as string,
          code: network.code as string,
          operator: (network.operator as string | null) ?? null,
          territory: (network.territory as string | null) ?? null,
          status: (network.status as string) ?? "active",
          setupCompletedAt: (network.setup_completed_at as string | null) ?? null,
        },
        membershipRole,
        canManage: membershipRole === "owner" || membershipRole === "admin",
        isPilotNetwork: network.code === PILOT_CODE,
        schemaReady: true,
      };
    }
  }

  // Compatibilité temporaire : l'ancienne base ne possède ni adhésions ni
  // active_network_id. On reconstruit un contexte isolé depuis les métadonnées
  // Auth afin de ne jamais renvoyer un professionnel connecté vers l'onboarding.
  const { data: { user } } = await supabase.auth.getUser();
  if (!user || user.id !== userId) return null;
  const metadata = user.user_metadata as Record<string, unknown>;
  const request = metadata.onboarding_network_request;

  if (request && typeof request === "object") {
    const custom = request as Record<string, unknown>;
    const name = typeof custom.name === "string" ? custom.name.trim() : "";
    if (name) {
      return {
        network: {
          id: userId,
          name,
          code: `pending-${userId.slice(0, 8)}`,
          operator: typeof custom.operator === "string" ? custom.operator : null,
          territory: typeof custom.territory === "string" ? custom.territory : null,
          status: "active",
          setupCompletedAt: new Date(0).toISOString(),
        },
        membershipRole: "owner",
        canManage: true,
        isPilotNetwork: false,
        schemaReady: false,
      };
    }
  }

  const { data: pilot } = await supabase
    .from("networks")
    .select("id, name, code")
    .eq("code", PILOT_CODE)
    .maybeSingle();

  return {
    network: {
      id: (pilot?.id as string | undefined) ?? PILOT_ID,
      name: (pilot?.name as string | undefined) ?? "Naolib Nantes",
      code: (pilot?.code as string | undefined) ?? PILOT_CODE,
      operator: "Semitan",
      territory: "Nantes Métropole",
      status: "active",
      setupCompletedAt: new Date(0).toISOString(),
    },
    membershipRole: "member",
    canManage: false,
    isPilotNetwork: true,
    schemaReady: false,
  };
}
