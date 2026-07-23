"use client";

import { motion } from "framer-motion";
import { Clock, Lock, Shield, Users } from "lucide-react";
import { communityHighlights } from "./landing-data";
import { fadeInUp, staggerContainer, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

const communityIcons = {
  shield: Shield,
  clock: Clock,
  lock: Lock,
  users: Users,
} as const;

export function LandingCommunity() {
  return (
    <section
      id="communaute"
      className="section-padding"
      aria-labelledby="community-title"
    >
      <div className="section-container">
        <div className="grid items-center gap-12 lg:grid-cols-2 lg:gap-16">
          <SectionHeading
            eyebrow="Données communautaires · Déploiement progressif"
            title="Une contribution encadrée, activée réseau par réseau"
            titleId="community-title"
            description="Les fonctions communautaires sont encore en cours de déploiement. Elles ne sont activées qu'après validation des règles de confidentialité et de modération du réseau concerné."
            align="left"
            className="mb-0 lg:max-w-lg"
          />

          <motion.div
            className="grid gap-4 sm:grid-cols-2"
            initial="hidden"
            whileInView="visible"
            viewport={viewTransition}
            variants={staggerContainer}
          >
            {communityHighlights.map((item) => {
              const Icon =
                communityIcons[item.icon as keyof typeof communityIcons] ??
                Shield;
              return (
                <motion.article
                  key={item.title}
                  variants={fadeInUp}
                  className="rounded-2xl border border-border/60 bg-card p-5 transition-all hover:border-realtime/30 hover:shadow-glass"
                >
                  <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-realtime/10 text-realtime">
                    <Icon className="h-5 w-5" aria-hidden />
                  </div>
                  <h3 className="font-semibold">{item.title}</h3>
                  <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
                    {item.description}
                  </p>
                </motion.article>
              );
            })}
          </motion.div>
        </div>
      </div>
    </section>
  );
}
