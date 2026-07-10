"use client";

import { useEffect, useState } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { DashboardLogo } from "@/components/layout/dashboard-logo";
import { DashboardNav } from "@/components/layout/dashboard-nav";
import { ProfileSwitcher } from "@/components/access/profile-switcher";
import { DashboardUserCard } from "@/components/layout/dashboard-user-card";
import { SignOutButton } from "@/components/layout/sign-out-button";

const STORAGE_KEY = "dashboard-sidebar-collapsed";

interface DashboardShellProps {
  displayName: string;
  role: string;
  children: React.ReactNode;
}

export function DashboardShell({
  displayName,
  role,
  children,
}: DashboardShellProps) {
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored === "true") setCollapsed(true);
  }, []);

  function toggleCollapsed() {
    setCollapsed((prev) => {
      const next = !prev;
      localStorage.setItem(STORAGE_KEY, String(next));
      return next;
    });
  }

  return (
    <div
      className={`dashboard-shell dark${collapsed ? " dashboard-shell--collapsed" : ""}`}
    >
      <aside className="dashboard-sidebar">
        <div className="dashboard-sidebar-header">
          <DashboardLogo collapsed={collapsed} />
          <button
            type="button"
            className="dashboard-sidebar-toggle"
            onClick={toggleCollapsed}
            aria-label={collapsed ? "Agrandir le menu" : "Réduire le menu"}
            aria-expanded={!collapsed}
          >
            {collapsed ? (
              <ChevronRight className="h-4 w-4" strokeWidth={1.5} />
            ) : (
              <ChevronLeft className="h-4 w-4" strokeWidth={1.5} />
            )}
          </button>
        </div>
        <ProfileSwitcher collapsed={collapsed} />
        <DashboardNav collapsed={collapsed} />
        <div className="dashboard-sidebar-footer">
          <DashboardUserCard
            displayName={displayName}
            role={role}
            collapsed={collapsed}
          />
          <SignOutButton collapsed={collapsed} />
        </div>
      </aside>

      <div className="dashboard-content">{children}</div>
    </div>
  );
}
