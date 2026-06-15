"use client";

import { motion } from "framer-motion";
import { ArrowRight, Map } from "lucide-react";
import { Button } from "@/components/ui/button";
import { fadeInUp, staggerContainer } from "./landing-motion";
import { PhoneMockup } from "./phone-mockup";

export function LandingHero() {
  return (
    <section
      className="relative overflow-hidden pt-24 pb-16 sm:pt-28 sm:pb-20 lg:pt-32 lg:pb-28"
      aria-labelledby="hero-title"
    >
      <div
        className="pointer-events-none absolute inset-0 bg-hero-glow"
        aria-hidden
      />
      <div className="section-container">
        <div className="grid items-center gap-12 lg:grid-cols-2 lg:gap-16">
          <motion.div
            initial="hidden"
            animate="visible"
            variants={staggerContainer}
            className="text-center lg:text-left"
          >
            <motion.p
              variants={fadeInUp}
              className="mb-4 inline-flex items-center gap-2 rounded-full border border-primary/20 bg-primary/5 px-4 py-1.5 text-sm font-medium text-primary"
            >
              <span className="h-2 w-2 rounded-full bg-realtime animate-pulse-soft" />
              Temps réel · Nantes disponible
            </motion.p>

            <motion.h1
              id="hero-title"
              variants={fadeInUp}
              className="text-4xl font-extrabold tracking-tight sm:text-5xl lg:text-[3.25rem] lg:leading-[1.1]"
            >
              Le GPS intelligent pour vos trajets en{" "}
              <span className="text-gradient">transport en commun</span>
            </motion.h1>

            <motion.p
              variants={fadeInUp}
              className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-muted-foreground sm:text-lg lg:mx-0"
            >
              Trouvez le meilleur itinéraire, suivez votre bus ou tram en temps
              réel et recevez des alertes avant son arrivée.
            </motion.p>

            <motion.div
              variants={fadeInUp}
              className="mt-8 flex flex-col items-center gap-3 sm:flex-row sm:justify-center lg:justify-start"
            >
              <Button asChild size="lg" className="w-full sm:w-auto">
                <a href="#telecharger">
                  Télécharger l&apos;application
                  <ArrowRight className="ml-1" />
                </a>
              </Button>
              <Button
                asChild
                variant="secondary"
                size="lg"
                className="w-full sm:w-auto"
              >
                <a href="#reseaux">
                  <Map />
                  Découvrir la carte
                </a>
              </Button>
            </motion.div>

            <motion.div
              variants={fadeInUp}
              className="mt-10 flex flex-wrap items-center justify-center gap-6 lg:justify-start"
            >
              {[
                { value: "4.8★", label: "Note App Store" },
                { value: "Temps réel", label: "Suivi véhicules" },
                { value: "Gratuit", label: "Pour les voyageurs" },
              ].map((stat) => (
                <div key={stat.label} className="text-center lg:text-left">
                  <p className="text-lg font-bold">{stat.value}</p>
                  <p className="text-xs text-muted-foreground">{stat.label}</p>
                </div>
              ))}
            </motion.div>
          </motion.div>

          <div className="relative flex justify-center lg:justify-end">
            <div
              className="pointer-events-none absolute inset-0 rounded-full bg-primary/10 blur-3xl"
              aria-hidden
            />
            <PhoneMockup />
          </div>
        </div>
      </div>
    </section>
  );
}
