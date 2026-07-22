import Link from "next/link";
import { ArrowLeft } from "lucide-react";
import { Button } from "@/components/ui/button";
import { ThemeToggle } from "@/components/theme-toggle";

const proNav = [
  { href: "/pro#fonctionnalites", label: "Fonctionnalités" },
  { href: "/pro#deploiement", label: "Déploiement" },
  { href: "mailto:contact@aule.fr?subject=Demande%20Aule%20Pro", label: "Nous contacter" },
];

export function ProLayout({ children }: { children: React.ReactNode }) {
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
            <Link href="/pro" className="group flex items-center gap-2.5">
              <span className="flex h-9 w-9 items-center justify-center overflow-hidden rounded-xl ring-1 ring-white/15 transition-transform duration-300 group-hover:scale-105">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src="/aule-logo.png" alt="Aule" width={36} height={36} className="h-full w-full object-cover" />
              </span>
              <span className="text-[15px] font-bold tracking-tight">
                Aule <span className="text-[#7DF7C0]">Pro</span>
              </span>
            </Link>
          </div>
          <div className="flex items-center gap-2">
            <ThemeToggle />
            <Button asChild size="sm" className="bg-blue-600 text-white hover:bg-blue-500">
              <Link href="/login">Connexion au dashboard</Link>
            </Button>
          </div>
        </div>
        <nav
          className="section-container flex gap-1 overflow-x-auto pb-3"
          aria-label="Navigation Aule Pro"
        >
          {proNav.map((item) => (
            <a
              key={item.href}
              href={item.href}
              className="shrink-0 rounded-lg px-4 py-2 text-sm font-medium text-slate-400 transition-colors hover:bg-white/10 hover:text-white"
            >
              {item.label}
            </a>
          ))}
        </nav>
      </header>
      <main>{children}</main>
    </div>
  );
}
