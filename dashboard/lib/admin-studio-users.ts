import { createClient as createSupabaseAdminClient, type SupabaseClient } from "@supabase/supabase-js";
import { createClient as createServerClient } from "@/lib/supabase/server";
import { PROFILE_META, profilesFromStaffRole, type Profile } from "@/lib/access/profiles";
import type { StaffRole } from "@/lib/types";
import { studioUsers } from "@/components/admin/admin-studio-data";
import { demoDataEnabled } from "@/lib/demo-mode";

export type AdminStudioUser = {
  id: string;
  name: string;
  email: string;
  profile: string;
  role: string;
  userKind: string;
  network: string;
  depot: string;
  authorizations: string;
  status: string;
  lastLogin: string;
  createdAt: string;
  apps: readonly string[];
  permissions: readonly string[];
};

export type AdminStudioUsersResult = {
  users: AdminStudioUser[];
  source: "supabase" | "demo";
  warning?: string;
};

type UserProfileRow = {
  id: string;
  display_name: string | null;
  role: string;
  depot_id: string | null;
  created_at: string | null;
  updated_at: string | null;
};

type DepotRow = {
  id: string;
  code: string | null;
  name: string | null;
};

type AssignmentRow = {
  user_id: string;
  profile_key: string;
  context: Record<string, unknown> | null;
  is_active: boolean;
};

type OverrideRow = {
  user_id: string;
  permission: string;
  granted: boolean;
};

type DriverRow = {
  id: string;
  user_id: string | null;
  email: string;
  first_name: string | null;
  last_name: string | null;
  driver_number: string | null;
  depot_id: string | null;
  status: string | null;
  created_at: string | null;
};

type AuthUserLite = {
  id: string;
  email?: string;
  last_sign_in_at?: string | null;
  created_at?: string | null;
  user_metadata?: {
    display_name?: string;
    full_name?: string;
    name?: string;
  };
};

function fallbackRole(profile: string) {
  if (profile.includes("Admin")) return "admin";
  if (profile.includes("Conducteur")) return "driver";
  if (profile.includes("Contrôleur")) return "msr_agent";
  if (profile.includes("maîtrise")) return "msr_supervisor";
  return profile.includes("Voyageur") ? "passenger" : "passenger";
}

const fallbackUsers: AdminStudioUser[] = studioUsers.map((user) => ({
  ...user,
  role: fallbackRole(user.profile),
}));

function getServiceClient(): SupabaseClient | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!url || !serviceKey) return null;
  return createSupabaseAdminClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}

async function getReadableClient() {
  return getServiceClient() ?? (await createServerClient());
}

function formatDateTime(value?: string | null) {
  if (!value) return "Jamais";
  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Europe/Paris",
  }).format(new Date(value));
}

function formatDate(value?: string | null) {
  if (!value) return "-";
  return new Intl.DateTimeFormat("fr-FR", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    timeZone: "Europe/Paris",
  }).format(new Date(value));
}

function isStaffRole(value: string): value is StaffRole {
  return ["passenger", "driver", "msr_agent", "msr_supervisor", "regulator", "admin"].includes(value);
}

function profileLabel(profile: string) {
  return (PROFILE_META as Partial<Record<string, { label: string }>>)[profile]?.label ?? profile;
}

function roleProfiles(role: string): Profile[] {
  return isStaffRole(role) ? profilesFromStaffRole(role) : [];
}

function profileFromRole(role: string) {
  switch (role) {
    case "driver":
      return "Conducteur";
    case "msr_agent":
      return "Contrôleur";
    case "msr_supervisor":
      return "Agent de maîtrise";
    case "regulator":
      return "Exploitation / Régulateur";
    case "admin":
      return "Admin interne Aule";
    case "passenger":
      return "Voyageur";
    default:
      return role || "Utilisateur";
  }
}

function userKindFrom(role: string, profiles: string[]) {
  if (role === "admin" || profiles.some((profile) => ["admin", "platform_admin", "super_admin"].includes(profile))) {
    return "Admin interne";
  }
  if (role === "passenger" && profiles.length === 0) return "Utilisateur Voyageur";
  return "Utilisateur Pro";
}

function appsFrom(kind: string, profiles: string[]) {
  const apps = new Set<string>();
  if (kind === "Utilisateur Voyageur") apps.add("Voyageur");
  if (kind === "Admin interne") apps.add("Admin interne");
  if (profiles.length > 0 && kind !== "Admin interne") apps.add("Pro");
  if (profiles.includes("merchant")) apps.add("Marketplace");
  if (!apps.size) apps.add("Voyageur");
  return [...apps];
}

function contextString(context: Record<string, unknown> | null | undefined, keys: string[]) {
  for (const key of keys) {
    const value = context?.[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return null;
}

function groupByUser<T extends { user_id: string }>(items: T[]) {
  return items.reduce((groups, item) => {
    const current = groups.get(item.user_id) ?? [];
    current.push(item);
    groups.set(item.user_id, current);
    return groups;
  }, new Map<string, T[]>());
}

async function loadAuthUsers() {
  const service = getServiceClient();
  const byId = new Map<string, AuthUserLite>();
  if (!service) return byId;

  const { data, error } = await service.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (error) return byId;
  for (const user of data.users) {
    byId.set(user.id, user as AuthUserLite);
  }
  return byId;
}

export async function loadAdminStudioUsers(): Promise<AdminStudioUsersResult> {
  const hasSupabaseEnv = Boolean(process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY);
  if (!hasSupabaseEnv) {
    return {
      users: demoDataEnabled ? fallbackUsers : [],
      source: demoDataEnabled ? "demo" : "supabase",
      warning: "Supabase n'est pas configuré.",
    };
  }

  const supabase = await getReadableClient();
  const [
    profilesRes,
    depotsRes,
    assignmentsRes,
    overridesRes,
    driversRes,
    authUsers,
  ] = await Promise.all([
    supabase
      .from("user_profiles")
      .select("id, display_name, role, depot_id, created_at, updated_at")
      .order("created_at", { ascending: false }),
    supabase.from("depots").select("id, code, name"),
    supabase.from("profile_assignments").select("user_id, profile_key, context, is_active"),
    supabase.from("user_permission_overrides").select("user_id, permission, granted"),
    supabase.from("drivers").select("id, user_id, email, first_name, last_name, driver_number, depot_id, status, created_at"),
    loadAuthUsers(),
  ]);

  if (profilesRes.error) {
    return {
      users: demoDataEnabled ? fallbackUsers : [],
      source: demoDataEnabled ? "demo" : "supabase",
      warning: `Lecture Supabase impossible: ${profilesRes.error.message}`,
    };
  }

  const profiles = (profilesRes.data ?? []) as UserProfileRow[];
  const depots = new Map(((depotsRes.data ?? []) as DepotRow[]).map((depot) => [depot.id, depot]));
  const assignments = ((assignmentsRes.data ?? []) as AssignmentRow[]).filter((assignment) => assignment.is_active);
  const overrides = (overridesRes.data ?? []) as OverrideRow[];
  const drivers = (driversRes.data ?? []) as DriverRow[];

  const assignmentsByUser = groupByUser(assignments);
  const overridesByUser = groupByUser(overrides);
  const driversByUser = new Map(drivers.filter((driver) => driver.user_id).map((driver) => [driver.user_id as string, driver]));

  const users = profiles.map((profile) => {
    const userAssignments = assignmentsByUser.get(profile.id) ?? [];
    const assignmentProfiles = userAssignments.map((assignment) => assignment.profile_key);
    const profileKeys = assignmentProfiles.length ? assignmentProfiles : roleProfiles(profile.role);
    const kind = userKindFrom(profile.role, profileKeys);
    const driver = driversByUser.get(profile.id);
    const depot = driver?.depot_id ? depots.get(driver.depot_id) : profile.depot_id ? depots.get(profile.depot_id) : null;
    const authUser = authUsers.get(profile.id);
    const firstContext = userAssignments[0]?.context;
    const email = authUser?.email ?? driver?.email ?? "Email non exposé";
    const driverName = [driver?.first_name, driver?.last_name].filter(Boolean).join(" ");
    const name = profile.display_name
      || authUser?.user_metadata?.display_name
      || authUser?.user_metadata?.full_name
      || authUser?.user_metadata?.name
      || driverName
      || email;
    const grantedOverrides = (overridesByUser.get(profile.id) ?? [])
      .filter((override) => override.granted)
      .map((override) => override.permission);

    return {
      id: profile.id,
      name,
      email,
      profile: profileKeys.length ? profileKeys.map(profileLabel).join(", ") : profileFromRole(profile.role),
      role: profile.role,
      userKind: kind,
      network: contextString(firstContext, ["network", "reseau", "réseau"]) ?? (kind === "Admin interne" ? "Aule global" : "Naolib"),
      depot: contextString(firstContext, ["depot", "dépôt", "depot_name"]) ?? depot?.name ?? depot?.code ?? "-",
      authorizations: profileKeys.length ? profileKeys.map(profileLabel).join(", ") : profileFromRole(profile.role),
      status: driver?.status === "off" ? "Hors ligne" : "Actif",
      lastLogin: formatDateTime(authUser?.last_sign_in_at ?? profile.updated_at),
      createdAt: formatDate(authUser?.created_at ?? profile.created_at),
      apps: appsFrom(kind, profileKeys),
      permissions: grantedOverrides.length ? grantedOverrides : profileKeys,
    } satisfies AdminStudioUser;
  });

  const profileIds = new Set(profiles.map((profile) => profile.id));
  const driverOnlyUsers = drivers
    .filter((driver) => !driver.user_id || !profileIds.has(driver.user_id))
    .map((driver) => {
      const depot = driver.depot_id ? depots.get(driver.depot_id) : null;
      const name = [driver.first_name, driver.last_name].filter(Boolean).join(" ") || driver.email;
      return {
        id: `driver-${driver.id}`,
        name,
        email: driver.email,
        profile: "Conducteur",
        role: "driver",
        userKind: "Utilisateur Pro",
        network: "Naolib",
        depot: depot?.name ?? depot?.code ?? "-",
        authorizations: driver.driver_number ? `Matricule ${driver.driver_number}` : "Conducteur",
        status: driver.status === "off" ? "Hors ligne" : "Actif",
        lastLogin: "Jamais",
        createdAt: formatDate(driver.created_at),
        apps: ["Pro"],
        permissions: ["driver"],
      } satisfies AdminStudioUser;
    });

  const mergedUsers = [...users, ...driverOnlyUsers];
  if (!mergedUsers.length) {
    return {
      users: demoDataEnabled ? fallbackUsers : [],
      source: demoDataEnabled ? "demo" : "supabase",
      warning: "Aucun utilisateur trouvé dans user_profiles ou drivers.",
    };
  }

  return {
    users: mergedUsers,
    source: "supabase",
    warning: [assignmentsRes.error, overridesRes.error, driversRes.error, depotsRes.error]
      .filter(Boolean)
      .map((error) => error?.message)
      .join(" · ") || undefined,
  };
}

export async function loadAdminStudioUser(userId: string) {
  const result = await loadAdminStudioUsers();
  return {
    ...result,
    user: result.users.find((user) => user.id === userId) ?? result.users[0],
  };
}
