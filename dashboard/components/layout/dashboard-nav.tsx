"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const links = [
  { href: "/dashboard", label: "Vue réseau" },
  { href: "/alertes", label: "Alertes" },
  { href: "/incidents", label: "Incidents" },
  { href: "/conducteurs", label: "Conducteurs" },
  { href: "/communication", label: "Communication" },
  { href: "/info-voyageur", label: "Info voyageur" },
  { href: "/missions", label: "Missions MSR" },
  { href: "/reporting", label: "Reporting" },
];

export function DashboardNav() {
  const pathname = usePathname();

  return (
    <nav>
      {links.map((link) => (
        <Link
          key={link.href}
          href={link.href}
          className={`nav-link${pathname.startsWith(link.href) ? " active" : ""}`}
        >
          {link.label}
        </Link>
      ))}
    </nav>
  );
}
