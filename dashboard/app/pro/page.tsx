import type { Metadata } from "next";
import Link from "next/link";
import {
  ArrowRight,
  Monitor,
  Settings,
  Shield,
  BusFront,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { proModules } from "@/components/landing/landing-data";
import { ProHero } from "@/components/pro/pro-sections";

export const metadata: Metadata = {
  title: "Aule Pro — Plateforme d'exploitation transport",
  description:
    "Plateforme professionnelle pour conducteurs, agents MSR, superviseurs et régulateurs de réseaux de transport en commun.",
};

const iconMap = {
  monitor: Monitor,
  shield: Shield,
  "steering-wheel": BusFront,
  settings: Settings,
} as const;

export default function ProPage() {
  return (
    <>
      <ProHero
        title="La plateforme d'exploitation pour les réseaux de transport"
        description="Aule Pro unifie l'expérience terrain et le poste de contrôle. Des données fiables en temps réel pour améliorer la qualité de l'information voyageur."
      />

      <section className="section-padding">
        <div className="section-container">
          <h2 className="mb-8 text-2xl font-bold">Modules professionnels</h2>
          <div className="grid gap-6 sm:grid-cols-2">
            {proModules.map((module) => {
              const Icon = iconMap[module.icon];
              return (
                <Card
                  key={module.href}
                  className="group transition-all hover:border-primary/30 hover:shadow-glass"
                >
                  <CardContent className="p-6">
                    <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
                      <Icon className="h-6 w-6" aria-hidden />
                    </div>
                    <h3 className="text-lg font-semibold">{module.title}</h3>
                    <p className="mt-2 text-sm text-muted-foreground">
                      {module.description}
                    </p>
                    <Button asChild variant="ghost" className="mt-4 px-0">
                      <Link href={module.href}>
                        En savoir plus
                        <ArrowRight className="h-4 w-4" />
                      </Link>
                    </Button>
                  </CardContent>
                </Card>
              );
            })}
          </div>

          <div className="mt-16 rounded-3xl border border-primary/20 bg-primary/5 p-8 text-center sm:p-12">
            <h2 className="text-2xl font-bold">
              Prêt à piloter votre réseau ?
            </h2>
            <p className="mx-auto mt-4 max-w-lg text-muted-foreground">
              Connectez-vous avec votre compte régulateur, superviseur MSR ou
              administrateur.
            </p>
            <Button asChild size="lg" className="mt-6">
              <Link href="/login">Accéder au poste de contrôle</Link>
            </Button>
          </div>
        </div>
      </section>
    </>
  );
}
