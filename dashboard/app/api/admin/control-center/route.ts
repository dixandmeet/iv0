import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { NextResponse } from "next/server";
import { createClient as createServerClient } from "@/lib/supabase/server";
import { isPermission } from "@/lib/access/permissions";
import { isProfile } from "@/lib/access/profiles";

type AdminClient = SupabaseClient;

function getServiceClient(): AdminClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!url || !serviceKey) return null;
  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function getAdminClient(
  authenticated: Awaited<ReturnType<typeof createServerClient>>,
): Promise<AdminClient> {
  return getServiceClient() ?? authenticated;
}

async function requireAdmin() {
  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return { error: NextResponse.json({ error: "Non authentifié" }, { status: 401 }) };
  }

  const { data: profile } = await supabase
    .from("user_profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  if (profile?.role === "admin") {
    return { userId: user.id, supabase: await getAdminClient(supabase) };
  }

  const { data: assignments } = await supabase
    .from("profile_assignments")
    .select("profile_key")
    .eq("user_id", user.id)
    .eq("is_active", true);

  const hasAdminProfile = (assignments ?? []).some((row) =>
    ["admin", "platform_admin", "super_admin"].includes(String(row.profile_key)),
  );

  if (!hasAdminProfile) {
    return { error: NextResponse.json({ error: "Accès refusé" }, { status: 403 }) };
  }

  return { userId: user.id, supabase: await getAdminClient(supabase) };
}

function rlsSetupRequired(message: string) {
  return NextResponse.json(
    {
      error: message,
      setupRequired:
        "Applique les migrations dashboard/supabase/migrations/20260708_admin_control_center.sql et 20260708_admin_rls_platform_admin.sql dans Supabase (ou renseigne SUPABASE_SERVICE_ROLE_KEY dans .env.local).",
    },
    { status: 500 },
  );
}

export async function GET() {
  const auth = await requireAdmin();
  if ("error" in auth) return auth.error;

  const admin = auth.supabase;

  const [
    resourcesRes,
    rolesRes,
    usersRes,
    assignmentsRes,
    overridesRes,
    auditRes,
  ] = await Promise.all([
    admin
      .from("aule_admin_resources")
      .select("*")
      .order("created_at", { ascending: false }),
    admin
      .from("aule_admin_roles")
      .select("*")
      .order("is_system", { ascending: false })
      .order("label"),
    admin
      .from("user_profiles")
      .select("id, display_name, role")
      .order("display_name", { ascending: true }),
    admin
      .from("profile_assignments")
      .select("id, user_id, profile_key, context, is_active, created_at")
      .order("created_at", { ascending: false }),
    admin
      .from("user_permission_overrides")
      .select("id, user_id, permission, granted, created_at")
      .order("created_at", { ascending: false }),
    admin
      .from("aule_admin_audit_logs")
      .select("*")
      .order("created_at", { ascending: false })
      .limit(40),
  ]);

  const setupError = [resourcesRes, rolesRes, auditRes].find((res) => res.error);
  if (setupError?.error) {
    return rlsSetupRequired(setupError.error.message);
  }

  return NextResponse.json({
    resources: resourcesRes.data ?? [],
    roles: rolesRes.data ?? [],
    users: usersRes.data ?? [],
    assignments: assignmentsRes.data ?? [],
    overrides: overridesRes.data ?? [],
    auditLogs: auditRes.data ?? [],
    warnings: [usersRes, assignmentsRes, overridesRes]
      .flatMap((res) => (res.error ? [res.error.message] : [])),
  });
}

export async function POST(request: Request) {
  const auth = await requireAdmin();
  if ("error" in auth) return auth.error;

  const admin = auth.supabase;

  const body = (await request.json()) as Record<string, unknown>;
  const action = String(body.action ?? "");

  try {
    switch (action) {
      case "upsertResource":
        return await upsertResource(admin, auth.userId, body);
      case "deleteResource":
        return await deleteResource(admin, auth.userId, body);
      case "upsertRole":
        return await upsertRole(admin, auth.userId, body);
      case "deleteRole":
        return await deleteRole(admin, auth.userId, body);
      case "assignProfile":
        return await assignProfile(admin, auth.userId, body);
      case "removeProfile":
        return await removeProfile(admin, auth.userId, body);
      case "setPermissionOverride":
        return await setPermissionOverride(admin, auth.userId, body);
      case "updateUser":
        return await updateUser(admin, auth.userId, body);
      default:
        return NextResponse.json({ error: "Action inconnue" }, { status: 400 });
    }
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Erreur inconnue" },
      { status: 500 },
    );
  }
}

async function audit(
  admin: AdminClient,
  actorId: string,
  action: string,
  resourceType: string,
  resourceId: string | null,
  beforeState: unknown,
  afterState: unknown,
) {
  await admin.from("aule_admin_audit_logs").insert({
    actor_id: actorId,
    action,
    resource_type: resourceType,
    resource_id: resourceId,
    before_state: beforeState ?? null,
    after_state: afterState ?? null,
  });
}

async function upsertResource(
  admin: AdminClient,
  actorId: string,
  body: Record<string, unknown>,
) {
  const resource = (body.resource ?? {}) as Record<string, unknown>;
  const id = typeof resource.id === "string" && resource.id ? resource.id : undefined;
  const payload = {
    resource_type: String(resource.resource_type ?? "network"),
    name: String(resource.name ?? "").trim(),
    status: String(resource.status ?? "active").trim() || "active",
    network_id: nullableString(resource.network_id),
    depot_id: nullableString(resource.depot_id),
    owner_user_id: nullableString(resource.owner_user_id),
    metadata: parseJsonObject(resource.metadata, {}),
  };

  if (!payload.name) {
    return NextResponse.json({ error: "Le nom est obligatoire" }, { status: 400 });
  }

  const before = id
    ? await admin.from("aule_admin_resources").select("*").eq("id", id).maybeSingle()
    : null;
  const query = id
    ? admin.from("aule_admin_resources").update(payload).eq("id", id).select("*").single()
    : admin.from("aule_admin_resources").insert(payload).select("*").single();
  const { data, error } = await query;
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  await audit(admin, actorId, id ? "resource.update" : "resource.create", payload.resource_type, data.id, before?.data ?? null, data);
  return NextResponse.json({ ok: true, resource: data });
}

async function deleteResource(
  admin: AdminClient,
  actorId: string,
  body: Record<string, unknown>,
) {
  const id = String(body.id ?? "");
  const before = await admin.from("aule_admin_resources").select("*").eq("id", id).maybeSingle();
  const { error } = await admin.from("aule_admin_resources").delete().eq("id", id);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  await audit(admin, actorId, "resource.delete", before.data?.resource_type ?? "resource", id, before.data ?? null, null);
  return NextResponse.json({ ok: true });
}

async function upsertRole(
  admin: AdminClient,
  actorId: string,
  body: Record<string, unknown>,
) {
  const role = (body.role ?? {}) as Record<string, unknown>;
  const id = typeof role.id === "string" && role.id ? role.id : undefined;
  const permissions = Array.isArray(role.permissions)
    ? role.permissions.filter((p): p is string => typeof p === "string" && isPermission(p))
    : [];
  const roleKey = String(role.role_key ?? "").trim();
  const payload = {
    role_key: roleKey,
    label: String(role.label ?? "").trim(),
    description: nullableString(role.description),
    permissions,
    restrictions: parseJsonObject(role.restrictions, {}),
    scope: parseJsonObject(role.scope, {}),
    is_system: Boolean(role.is_system),
  };

  if (!payload.role_key || !payload.label) {
    return NextResponse.json({ error: "Clé et libellé obligatoires" }, { status: 400 });
  }

  const before = id
    ? await admin.from("aule_admin_roles").select("*").eq("id", id).maybeSingle()
    : null;
  const query = id
    ? admin.from("aule_admin_roles").update(payload).eq("id", id).select("*").single()
    : admin.from("aule_admin_roles").insert(payload).select("*").single();
  const { data, error } = await query;
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  await audit(admin, actorId, id ? "role.update" : "role.create", "role", data.id, before?.data ?? null, data);
  return NextResponse.json({ ok: true, role: data });
}

async function deleteRole(
  admin: AdminClient,
  actorId: string,
  body: Record<string, unknown>,
) {
  const id = String(body.id ?? "");
  const before = await admin.from("aule_admin_roles").select("*").eq("id", id).maybeSingle();
  if (before.data?.is_system) {
    return NextResponse.json({ error: "Un rôle système ne peut pas être supprimé" }, { status: 400 });
  }
  const { error } = await admin.from("aule_admin_roles").delete().eq("id", id);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  await audit(admin, actorId, "role.delete", "role", id, before.data ?? null, null);
  return NextResponse.json({ ok: true });
}

async function assignProfile(
  admin: AdminClient,
  actorId: string,
  body: Record<string, unknown>,
) {
  const userId = String(body.userId ?? "");
  const profileKey = String(body.profileKey ?? "");
  if (!userId || !isProfile(profileKey)) {
    return NextResponse.json({ error: "Utilisateur ou profil invalide" }, { status: 400 });
  }

  const context = parseJsonObject(body.context, {});
  const { data, error } = await admin
    .from("profile_assignments")
    .upsert(
      { user_id: userId, profile_key: profileKey, context, is_active: true },
      { onConflict: "user_id,profile_key" },
    )
    .select("*")
    .single();
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  await audit(admin, actorId, "profile.assign", "profile_assignment", data.id, null, data);
  return NextResponse.json({ ok: true, assignment: data });
}

async function removeProfile(
  admin: AdminClient,
  actorId: string,
  body: Record<string, unknown>,
) {
  const id = String(body.id ?? "");
  const before = await admin.from("profile_assignments").select("*").eq("id", id).maybeSingle();
  const { error } = await admin
    .from("profile_assignments")
    .update({ is_active: false })
    .eq("id", id);
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  await audit(admin, actorId, "profile.disable", "profile_assignment", id, before.data ?? null, { is_active: false });
  return NextResponse.json({ ok: true });
}

async function setPermissionOverride(
  admin: AdminClient,
  actorId: string,
  body: Record<string, unknown>,
) {
  const userId = String(body.userId ?? "");
  const permission = String(body.permission ?? "");
  const granted = body.granted;
  if (!userId || !isPermission(permission)) {
    return NextResponse.json({ error: "Utilisateur ou permission invalide" }, { status: 400 });
  }

  if (granted === null) {
    const before = await admin
      .from("user_permission_overrides")
      .select("*")
      .eq("user_id", userId)
      .eq("permission", permission)
      .maybeSingle();
    const { error } = await admin
      .from("user_permission_overrides")
      .delete()
      .eq("user_id", userId)
      .eq("permission", permission);
    if (error) return NextResponse.json({ error: error.message }, { status: 400 });
    await audit(admin, actorId, "permission_override.delete", "permission_override", before.data?.id ?? null, before.data ?? null, null);
    return NextResponse.json({ ok: true });
  }

  const { data, error } = await admin
    .from("user_permission_overrides")
    .upsert(
      { user_id: userId, permission, granted: Boolean(granted) },
      { onConflict: "user_id,permission" },
    )
    .select("*")
    .single();
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  await audit(admin, actorId, "permission_override.upsert", "permission_override", data.id, null, data);
  return NextResponse.json({ ok: true, override: data });
}

async function updateUser(
  admin: AdminClient,
  actorId: string,
  body: Record<string, unknown>,
) {
  const userId = String(body.userId ?? "");
  const role = String(body.role ?? "");
  const displayName = nullableString(body.displayName);
  if (!userId || !role) {
    return NextResponse.json({ error: "Utilisateur ou rôle invalide" }, { status: 400 });
  }

  const before = await admin.from("user_profiles").select("*").eq("id", userId).maybeSingle();
  const { data, error } = await admin
    .from("user_profiles")
    .update({ role, display_name: displayName, updated_at: new Date().toISOString() })
    .eq("id", userId)
    .select("id, display_name, role")
    .single();
  if (error) return NextResponse.json({ error: error.message }, { status: 400 });

  await audit(admin, actorId, "user.update", "user_profile", userId, before.data ?? null, data);
  return NextResponse.json({ ok: true, user: data });
}

function nullableString(value: unknown) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function parseJsonObject(value: unknown, fallback: Record<string, unknown>) {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  if (typeof value !== "string" || !value.trim()) return fallback;
  const parsed = JSON.parse(value) as unknown;
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error("JSON invalide: un objet est attendu");
  }
  return parsed as Record<string, unknown>;
}
