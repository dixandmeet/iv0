import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";
import { createClient as createServerClient } from "@/lib/supabase/server";

type AccountAction = "deactivate" | "delete";

const CONFIRMATION_PHRASES: Record<AccountAction, string> = {
  deactivate: "DESACTIVER",
  delete: "SUPPRIMER",
};

function getAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!url || !serviceKey) return null;

  return createSupabaseClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export async function POST(request: Request) {
  const requestOrigin = request.headers.get("origin");
  if (requestOrigin && requestOrigin !== new URL(request.url).origin) {
    return NextResponse.json({ error: "Requête non autorisée." }, { status: 403 });
  }

  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user || !user.email) {
    return NextResponse.json({ error: "Votre session a expiré. Reconnectez-vous." }, { status: 401 });
  }

  let body: {
    action?: unknown;
    confirmationEmail?: unknown;
    confirmationPhrase?: unknown;
    accepted?: unknown;
  };

  try {
    body = await request.json();
  } catch {
    return NextResponse.json({ error: "Demande invalide." }, { status: 400 });
  }

  const action = body.action;
  if (action !== "deactivate" && action !== "delete") {
    return NextResponse.json({ error: "Action inconnue." }, { status: 400 });
  }

  const emailMatches =
    typeof body.confirmationEmail === "string" &&
    body.confirmationEmail.trim().toLowerCase() === user.email.toLowerCase();
  const phraseMatches =
    typeof body.confirmationPhrase === "string" &&
    body.confirmationPhrase.trim() === CONFIRMATION_PHRASES[action];

  if (!emailMatches || !phraseMatches || body.accepted !== true) {
    return NextResponse.json(
      { error: "Les confirmations de sécurité sont incomplètes ou incorrectes." },
      { status: 400 },
    );
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json(
      { error: "La gestion du compte n’est pas configurée. Contactez un administrateur Aule." },
      { status: 503 },
    );
  }

  const ownershipBlocker = await findOwnershipBlocker(admin, user.id);
  if (ownershipBlocker) {
    return NextResponse.json({ error: ownershipBlocker }, { status: 409 });
  }

  if (action === "deactivate") {
    const { error } = await admin.auth.admin.updateUserById(user.id, {
      ban_duration: "876000h",
      app_metadata: {
        ...user.app_metadata,
        account_status: "deactivated",
        deactivated_at: new Date().toISOString(),
      },
    });

    if (error) {
      return NextResponse.json(
        { error: "La désactivation a échoué. Réessayez ou contactez un administrateur." },
        { status: 500 },
      );
    }

    return NextResponse.json({ success: true });
  }

  const { error } = await admin.auth.admin.deleteUser(user.id, false);
  if (error) {
    return NextResponse.json(
      { error: "La suppression a échoué. Réessayez ou contactez un administrateur." },
      { status: 500 },
    );
  }

  return NextResponse.json({ success: true });
}

async function findOwnershipBlocker(
  admin: NonNullable<ReturnType<typeof getAdminClient>>,
  userId: string,
): Promise<string | null> {
  const { data: managedMemberships, error: membershipsError } = await admin
    .from("network_memberships")
    .select("network_id")
    .eq("user_id", userId)
    .in("membership_role", ["owner", "admin"]);

  if (membershipsError) {
    return "Impossible de vérifier vos responsabilités réseau. Réessayez avant de continuer.";
  }

  const networkIds = [...new Set((managedMemberships ?? []).map((row) => row.network_id as string))];
  if (networkIds.length > 0) {
    const { data: otherManagers, error: managersError } = await admin
      .from("network_memberships")
      .select("network_id")
      .in("network_id", networkIds)
      .in("membership_role", ["owner", "admin"])
      .neq("user_id", userId);

    if (managersError) {
      return "Impossible de vérifier les autres administrateurs réseau. Réessayez avant de continuer.";
    }

    const coveredNetworks = new Set((otherManagers ?? []).map((row) => row.network_id as string));
    if (networkIds.some((networkId) => !coveredNetworks.has(networkId))) {
      return "Vous êtes le dernier administrateur d’au moins un réseau. Nommez d’abord un autre administrateur.";
    }
  }

  const [{ data: profile }, { data: adminAssignment }] = await Promise.all([
    admin.from("user_profiles").select("role").eq("id", userId).maybeSingle(),
    admin
      .from("profile_assignments")
      .select("id")
      .eq("user_id", userId)
      .eq("is_active", true)
      .in("profile_key", ["admin", "platform_admin", "super_admin"])
      .limit(1)
      .maybeSingle(),
  ]);

  if (profile?.role !== "admin" && !adminAssignment) return null;

  const [{ data: otherLegacyAdmin }, { data: otherAdminAssignment }] = await Promise.all([
    admin
      .from("user_profiles")
      .select("id")
      .eq("role", "admin")
      .neq("id", userId)
      .limit(1)
      .maybeSingle(),
    admin
      .from("profile_assignments")
      .select("id")
      .neq("user_id", userId)
      .eq("is_active", true)
      .in("profile_key", ["admin", "platform_admin", "super_admin"])
      .limit(1)
      .maybeSingle(),
  ]);

  if (!otherLegacyAdmin && !otherAdminAssignment) {
    return "Vous êtes le dernier administrateur de la plateforme. Attribuez d’abord ce rôle à une autre personne.";
  }

  return null;
}
