"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useAccess } from "@/components/access/access-provider";
import type { AppModule } from "@/lib/access/modules";

interface DashboardNavProps {
  collapsed?: boolean;
}

function isModuleActive(module: AppModule, pathname: string): boolean {
  if (!module.route) return false;
  if (module.route === "/dashboard") {
    return pathname === "/dashboard";
  }
  if (module.id === "ops.stations") {
    return (
      pathname === "/arrets" ||
      pathname.startsWith("/arrets/") ||
      pathname === "/stations" ||
      pathname.startsWith("/stations/")
    );
  }
  return pathname === module.route || pathname.startsWith(`${module.route}/`);
}

/**
 * Navigation dérivée du registre de modules (permissions × surface). Aucun lien
 * en dur : les sections et entrées visibles dépendent des profils de
 * l'utilisateur, résolus dans <AccessProvider>.
 */
export function DashboardNav({ collapsed = false }: DashboardNavProps) {
  const pathname = usePathname();
  const { navGroups } = useAccess();

  return (
    <nav className="dashboard-nav">
      {navGroups.map((group) => (
        <div key={group.group} className="dashboard-nav-group">
          <div className="dashboard-nav-group-label">{group.label}</div>
          {group.modules.map((module) => {
            const active = isModuleActive(module, pathname);
            return (
              <Link
                key={module.id}
                href={module.route!}
                className={`dashboard-nav-link${active ? " active" : ""}${collapsed ? " dashboard-nav-link--collapsed" : ""}`}
                title={collapsed ? module.label : undefined}
              >
                <module.icon
                  className="h-[18px] w-[18px] shrink-0"
                  strokeWidth={1.5}
                />
                <span className="dashboard-nav-link-label flex-1 truncate">
                  {module.label}
                </span>
              </Link>
            );
          })}
        </div>
      ))}
    </nav>
  );
}
