import { PERMISSIONS, type Permission } from "./permissions";
import {
  CORE_PERMISSIONS,
  PROFILE_PERMISSIONS,
  type Profile,
} from "./profiles";
import {
  MODULE_GROUPS,
  MODULE_GROUP_LABELS,
  MODULE_REGISTRY,
  type AppModule,
  type ModuleGroup,
  type Surface,
} from "./modules";

/** Grant/révocation d'une permission, indépendamment des profils. */
export interface PermissionOverride {
  permission: Permission;
  granted: boolean;
}

/**
 * Calcule l'ensemble effectif des permissions d'un utilisateur :
 *   Core + union(profils) ± overrides.
 * `admin` reçoit toutes les permissions. C'est l'unique point de vérité pour
 * savoir « ce que l'utilisateur a le droit de faire ».
 */
export function resolvePermissions(
  profiles: Profile[],
  overrides: PermissionOverride[] = [],
): Set<Permission> {
  if (profiles.includes("admin") || profiles.includes("super_admin")) {
    return new Set(PERMISSIONS);
  }

  const perms = new Set<Permission>(CORE_PERMISSIONS);
  for (const profile of profiles) {
    for (const p of PROFILE_PERMISSIONS[profile]) perms.add(p);
  }
  for (const { permission, granted } of overrides) {
    if (granted) perms.add(permission);
    else perms.delete(permission);
  }
  return perms;
}

/** Un module est-il activé pour cet ensemble de permissions et cette surface ? */
export function isModuleEnabled(
  module: AppModule,
  permissions: Set<Permission>,
  surface: Surface,
): boolean {
  return (
    module.surfaces.includes(surface) && permissions.has(module.requires)
  );
}

export interface NavGroup {
  group: ModuleGroup;
  label: string;
  modules: AppModule[];
}

/**
 * Navigation dérivée : modules `ready`, autorisés par les permissions, présents
 * sur la surface, dédupliqués par route (plusieurs profils peuvent mener au même
 * écran — ex. `control.map_ops` et `ops.network_view` → `/dashboard`), puis
 * regroupés par section. La fusion multi-profils est ainsi automatique.
 */
export function getNavGroups(
  permissions: Set<Permission>,
  surface: Surface,
): NavGroup[] {
  const seenRoutes = new Set<string>();
  const byGroup = new Map<ModuleGroup, AppModule[]>();

  for (const appModule of MODULE_REGISTRY) {
    if (appModule.status !== "ready" || !appModule.route) continue;
    if (!isModuleEnabled(appModule, permissions, surface)) continue;
    if (seenRoutes.has(appModule.route)) continue;
    seenRoutes.add(appModule.route);

    const list = byGroup.get(appModule.group) ?? [];
    list.push(appModule);
    byGroup.set(appModule.group, list);
  }

  return MODULE_GROUPS.flatMap((group) => {
    const modules = byGroup.get(group);
    if (!modules || modules.length === 0) return [];
    return [{ group, label: MODULE_GROUP_LABELS[group], modules }];
  });
}
