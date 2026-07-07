"use client";

import { motion } from "framer-motion";
import {
  Accessibility,
  AlertTriangle,
  BellRing,
  Compass,
  Home,
  Map,
  MapPin,
  Radio,
  Route,
  Star,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { bentoFeatures } from "./landing-data";
import { bentoItem, bentoStagger, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

const featureIcons = {
  route: Route,
  radio: Radio,
  star: Star,
  home: Home,
  map: Map,
  accessibility: Accessibility,
  "bell-ring": BellRing,
  compass: Compass,
  "alert-triangle": AlertTriangle,
  "map-pin": MapPin,
} as const;

export function LandingFeaturesBento() {
  return (
    <section
      id="fonctionnalites"
      className="section-padding"
      aria-labelledby="features-title"
    >
      <div className="section-container">
        <SectionHeading
          eyebrow="Fonctionnalités"
          title="Tout pour voyager sereinement"
          titleId="features-title"
          description="Des outils pensés pour le quotidien, enrichis en continu sur le réseau pilote Naolib."
          align="center"
          className="mx-auto"
        />

        <motion.div
          className="bento-grid"
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={bentoStagger}
        >
          {bentoFeatures.map((feature) => {
            const Icon =
              featureIcons[feature.icon as keyof typeof featureIcons] ?? Route;
            const isLarge = feature.size === "lg";

            return (
              <motion.div
                key={feature.title}
                variants={bentoItem}
                whileHover={{ y: -3 }}
                transition={{ type: "spring", stiffness: 400, damping: 25 }}
                className={cn(
                  "group rounded-2xl border border-border/60 bg-card p-6 transition-all hover:border-primary/30 hover:shadow-glow",
                  isLarge ? "bento-cell-lg" : "bento-cell-sm",
                )}
              >
                <div
                  className={cn(
                    "mb-4 flex items-center justify-center rounded-2xl bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground",
                    isLarge ? "h-14 w-14" : "h-11 w-11",
                  )}
                >
                  <Icon className={isLarge ? "h-7 w-7" : "h-5 w-5"} aria-hidden />
                </div>
                <h3
                  className={cn(
                    "font-semibold",
                    isLarge ? "text-xl" : "text-base",
                  )}
                >
                  {feature.title}
                </h3>
                <p
                  className={cn(
                    "mt-2 leading-relaxed text-muted-foreground",
                    isLarge ? "text-sm sm:text-base" : "text-sm",
                  )}
                >
                  {feature.description}
                </p>
              </motion.div>
            );
          })}
        </motion.div>
      </div>
    </section>
  );
}
