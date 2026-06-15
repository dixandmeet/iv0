"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/theme-toggle";
import { cn } from "@/lib/utils";
import { proModules } from "@/components/landing/landing-data";

const proNav = [
  { href: "/pro", label: "Vue d'ensemble" },
  ...proModules.map((m) => ({ href: m.href, label: m.title })),
];

export function ProLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  return (
    <div className="min-h-screen bg-background">
      <header className="sticky top-0 z-50 border-b border-border/50 bg-background/80 backdrop-blur-xl">
        <div className="section-container flex h-16 items-center justify-between">
          <div className="flex items-center gap-4">
            <Link
              href="/"
              className="flex items-center gap-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
            >
              <ArrowLeft className="h-4 w-4" />
              <span className="hidden sm:inline">Voyageurs</span>
            </Link>
            <div className="h-5 w-px bg-border" aria-hidden />
            <Link href="/pro" className="flex items-center gap-2">
              <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-xs font-extrabold text-primary-foreground">
                A
              </span>
              <span className="font-bold">
                Aule <span className="text-primary">Pro</span>
              </span>
            </Link>
          </div>
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <Button asChild size="sm" variant="secondary">
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
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:bg-accent hover:text-foreground",
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
