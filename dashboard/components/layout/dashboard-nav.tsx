"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  AlertTriangle,
  BarChart3,
  Bus,
  Megaphone,
  MessageSquare,
  Radio,
  Settings,
  Shield,
  Users,
  type LucideIcon,
} from "lucide-react";

interface NavLink {
  href: string;
  label: string;
  icon: LucideIcon;
  isActive?: (pathname: string) => boolean;
}

const links: NavLink[] = [
  {
    href: "/dashboard",
    label: "Lignes du réseau",
    icon: Radio,
    isActive: (pathname) =>
      pathname === "/dashboard" || pathname.startsWith("/dashboard/"),
  },
  { href: "/alertes", label: "Alertes", icon: AlertTriangle },
  { href: "/incidents", label: "Incidents", icon: Shield },
  { href: "/conducteurs", label: "Conducteurs", icon: Users },
  { href: "/dashboard", label: "Véhicules", icon: Bus },
  { href: "/communication", label: "Communication", icon: MessageSquare },
  { href: "/info-voyageur", label: "Info voyageurs", icon: Megaphone },
  { href: "/reporting", label: "Reporting", icon: BarChart3 },
  { href: "/missions", label: "Missions MSR", icon: Shield },
  { href: "#", label: "Paramètres", icon: Settings },
];

interface DashboardNavProps {
  collapsed?: boolean;
}

export function DashboardNav({ collapsed = false }: DashboardNavProps) {
  const pathname = usePathname();

  return (
    <nav className="dashboard-nav">
      {links.map((link) => {
        const isActive =
          link.isActive?.(pathname) ??
          (link.href !== "#" &&
            link.href !== "/dashboard" &&
            (pathname === link.href || pathname.startsWith(`${link.href}/`)));

        return (
          <Link
            key={`${link.href}-${link.label}`}
            href={link.href}
            className={`dashboard-nav-link${isActive ? " active" : ""}${collapsed ? " dashboard-nav-link--collapsed" : ""}`}
            title={collapsed ? link.label : undefined}
          >
            <link.icon className="h-[18px] w-[18px] shrink-0" strokeWidth={1.5} />
            <span className="dashboard-nav-link-label flex-1 truncate">{link.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
