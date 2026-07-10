"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ArrowLeft, LockKeyhole } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/theme-toggle";
import { cn } from "@/lib/utils";

const proNav = [
  { href: "/pro", label: "Écosystème" },
  { href: "/pro/conducteur", label: "Conducteur" },
  { href: "/pro/controleur", label: "Contrôleur" },
  { href: "/pro/exploitation", label: "Exploitation" },
  { href: "/pro/vtc", label: "VTC" },
  { href: "/pro/commercant", label: "Commerçant" },
];

export function ProLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  return (
    <div className="min-h-screen bg-[#050b18]">
      <header className="sticky top-0 z-50 border-b border-white/10 bg-[#050b18]/85 text-white backdrop-blur-xl">
        <div className="section-container flex h-16 items-center justify-between">
          <div className="flex items-center gap-4">
            <Link
              href="/"
              className="flex items-center gap-2 text-sm text-slate-400 transition-colors hover:text-white"
            >
              <ArrowLeft className="h-4 w-4" />
              <span className="hidden sm:inline">Voyageurs</span>
            </Link>
            <div className="h-5 w-px bg-white/10" aria-hidden />
            <Link href="/pro" className="flex items-center gap-2">
              <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-blue-600 text-xs font-extrabold text-white">
                A
              </span>
              <span className="font-bold">
                Aule <span className="text-blue-300">Pro</span>
              </span>
            </Link>
          </div>
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <Button asChild size="sm" variant="secondary" className="border-white/10 bg-white/5 text-white hover:bg-white/10">
              <Link href="/admin">
                <LockKeyhole className="h-4 w-4" />
                Admin
              </Link>
            </Button>
            <Button asChild size="sm" className="bg-blue-600 text-white hover:bg-blue-500">
              <Link href="/login">Connexion</Link>
            </Button>
          </div>
        </div>
        <nav
          className="section-container flex gap-1 overflow-x-auto pb-3"
          aria-label="Navigation Aule Pro"
        >
          {proNav.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                "shrink-0 rounded-lg px-4 py-2 text-sm font-medium transition-colors",
                pathname === item.href
                  ? "bg-blue-600 text-white"
                  : "text-slate-400 hover:bg-white/10 hover:text-white",
              )}
            >
              {item.label}
            </Link>
          ))}
        </nav>
      </header>
      <main>{children}</main>
    </div>
  );
}
