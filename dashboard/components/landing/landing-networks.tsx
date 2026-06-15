"use client";

import { motion } from "framer-motion";
import { Plus } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { networks } from "./landing-data";
import { CoverageMap } from "./coverage-map";
import { fadeInUp, staggerContainer, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

export function LandingNetworks() {
  return (
    <section
      id="reseaux"
      className="section-padding bg-muted/40"
      aria-labelledby="networks-title"
    >
      <div className="section-container">
        <SectionHeading
          eyebrow="Couverture"
          title="Réseaux couverts"
          description="Une architecture évolutive pour déployer Aule ville par ville. Nantes est notre réseau pilote."
          align="center"
        />

        <motion.div
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={fadeInUp}
          className="relative mb-10 overflow-hidden rounded-3xl border border-border bg-card shadow-glass"
        >
          <div className="relative aspect-[16/7] min-h-[220px] sm:min-h-[320px]">
            <CoverageMap className="absolute inset-0" />
            <div
              className="pointer-events-none absolute inset-0 z-[2] bg-gradient-to-t from-card/80 via-transparent to-card/20"
              aria-hidden
            />
          </div>
        </motion.div>

        <motion.div
          className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={staggerContainer}
        >
          {networks.map((network) => (
            <motion.article
              key={network.id}
              variants={fadeInUp}
              className="glass-card p-5"
            >
              <div className="mb-3 flex items-center justify-between">
                <h3 className="font-semibold">{network.city}</h3>
                {network.status === "pilot" ? (
                  <Badge variant="realtime">Pilote</Badge>
                ) : (
                  <Badge variant="secondary">Bientôt</Badge>
                )}
              </div>
              <p className="mb-3 text-sm text-muted-foreground">
                {network.operator}
              </p>
              <div className="flex flex-wrap gap-1.5">
                {network.modes.map((mode) => (
                  <span
                    key={mode}
                    className="rounded-md bg-muted px-2 py-0.5 text-xs text-muted-foreground"
                  >
                    {mode}
                  </span>
                ))}
              </div>
            </motion.article>
          ))}

          <motion.article
            variants={fadeInUp}
            className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-border p-5 text-center"
          >
            <Plus className="mb-2 h-8 w-8 text-muted-foreground" />
            <p className="text-sm font-medium">Votre ville</p>
            <p className="text-xs text-muted-foreground">Prochainement</p>
          </motion.article>
        </motion.div>
      </div>
    </section>
  );
}
