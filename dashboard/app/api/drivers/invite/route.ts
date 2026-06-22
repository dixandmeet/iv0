import { createClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";
import { createClient as createServerClient } from "@/lib/supabase/server";

function getAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceKey) return null;
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

export async function POST(request: Request) {
  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json({ error: "Non authentifié" }, { status: 401 });
  }

  const { data: profile } = await supabase
    .from("user_profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  if (!profile || !["regulator", "admin"].includes(profile.role)) {
    return NextResponse.json({ error: "Accès refusé" }, { status: 403 });
  }

  const admin = getAdminClient();
  if (!admin) {
    return NextResponse.json(
      {
        error:
          "Invitation par e-mail non configurée (SUPABASE_SERVICE_ROLE_KEY manquante). Le conducteur doit d'abord créer un compte passager.",
      },
      { status: 503 },
    );
  }

  const body = (await request.json()) as {
    email?: string;
    display_name?: string;
    depot_id?: string | null;
  };

  const email = body.email?.trim().toLowerCase();
  const displayName = body.display_name?.trim();
  const depotId = body.depot_id ?? null;

  if (!email || !email.includes("@")) {
    return NextResponse.json({ error: "Adresse e-mail invalide" }, { status: 400 });
  }

  const { data: inviteData, error: inviteError } =
    await admin.auth.admin.inviteUserByEmail(email, {
      data: {
        display_name: displayName || null,
        role: "driver",
      },
      redirectTo: `${new URL(request.url).origin}/login`,
    });

  if (inviteError) {
    return NextResponse.json({ error: inviteError.message }, { status: 400 });
  }

  const userId = inviteData.user.id;

  const { error: profileError } = await admin.from("user_profiles").upsert(
    {
      id: userId,
      role: "driver",
      display_name: displayName || email.split("@")[0],
      depot_id: depotId,
      updated_at: new Date().toISOString(),
    },
    { onConflict: "id" },
  );

  if (profileError) {
    return NextResponse.json({ error: profileError.message }, { status: 500 });
  }

  return NextResponse.json({ userId, invited: true });
}
