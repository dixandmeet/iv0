"use client";

import { motion } from "framer-motion";
import { ArrowRight, Map } from "lucide-react";
import { Button } from "@/components/ui/button";
import { trustStats } from "./landing-data";
import { fadeInUp, staggerContainer } from "./landing-motion";
import { PhoneMockup } from "./phone-mockup";

export function LandingHero() {
  return (
    <section
      className="relative overflow-hidden pt-24 pb-20 sm:pt-28 sm:pb-24 lg:pt-36 lg:pb-32"
      aria-labelledby="hero-title"
    >
      <div className="hero-mesh pointer-events-none absolute inset-0" aria-hidden />
      <div className="section-container relative">
        <div className="grid items-center gap-14 lg:grid-cols-[1.1fr_0.9fr] lg:gap-20">
          <motion.div
            initial="hidden"
            animate="visible"
            variants={staggerContainer}
            className="text-center lg:text-left"
          >
            <motion.p
              variants={fadeInUp}
              className="mb-5 inline-flex items-center gap-2 rounded-full border border-primary/25 bg-primary/5 px-4 py-1.5 text-sm font-medium text-primary"
            >
              <span className="h-2 w-2 rounded-full bg-realtime animate-pulse-soft" />
              Temps réel · Naolib · Nantes
            </motion.p>

            <motion.h1
              id="hero-title"
              variants={fadeInUp}
              className="text-[2.75rem] font-extrabold leading-[1.05] tracking-tight sm:text-5xl lg:text-[3.75rem]"
            >
              Voyagez sereinement avec le{" "}
              <span className="text-gradient">GPS intelligent</span> du transport
              en commun
            </motion.h1>

            <motion.p
              variants={fadeInUp}
              className="mx-auto mt-6 max-w-xl text-base leading-relaxed text-muted-foreground sm:text-lg lg:mx-0"
            >
              Itinéraires multimodaux, suivi temps réel, favoris et alertes —
              Aule vous accompagne du départ à l&apos;arrivée, gratuitement.
            </motion.p>

            <motion.div
              variants={fadeInUp}
              className="mt-9 flex flex-col items-center gap-3 sm:flex-row sm:justify-center lg:justify-start"
            >
              <Button asChild size="lg" className="h-12 w-full px-8 sm:w-auto">
                <a href="#telecharger">
                  Télécharger l&apos;application
                  <ArrowRight className="ml-1" />
                </a>
              </Button>
              <Button
                asChild
                variant="outline"
                size="lg"
                className="h-12 w-full sm:w-auto"
              >
                <a href="#fonctionnalites">
                  <Map />
                  Voir les fonctionnalités
                </a>
              </Button>
            </motion.div>

            <motion.div
              variants={fadeInUp}
              className="mt-12 grid grid-cols-3 gap-4 border-t border-border/60 pt-8 lg:max-w-md"
            >
              {trustStats.map((stat) => (
                <div key={stat.label} className="text-center lg:text-left">
                  <p className="text-base font-bold sm:text-lg">{stat.value}</p>
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
