"use client";

import { motion } from "framer-motion";
import {
  AlertTriangle,
  BellRing,
  Compass,
  MapPin,
  Radio,
  Route,
} from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { features } from "./landing-data";
import { fadeInUp, staggerContainer, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

const featureIcons = {
  route: Route,
  radio: Radio,
  "bell-ring": BellRing,
  "map-pin": MapPin,
  compass: Compass,
  "alert-triangle": AlertTriangle,
} as const;

export function LandingFeatures() {
  return (
    <section
      id="fonctionnalites"
      className="section-padding bg-muted/30"
      aria-labelledby="features-title"
    >
      <div className="section-container">
        <SectionHeading
          eyebrow="Fonctionnalités"
          title="Tout ce dont vous avez besoin pour voyager sereinement"
          description="Des outils pensés pour le quotidien des usagers des transports urbains."
          align="center"
        />

        <motion.div
          className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={staggerContainer}
        >
          {features.map((feature) => {
            const Icon = featureIcons[feature.icon];
            return (
              <motion.div
                key={feature.title}
                variants={fadeInUp}
                whileHover={{ y: -4 }}
                transition={{ type: "spring", stiffness: 400, damping: 25 }}
              >
                <Card className="group h-full cursor-default border-border/60 bg-card transition-all hover:border-primary/30 hover:shadow-glow">
                  <CardContent className="p-6">
                    <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
                      <Icon className="h-6 w-6" aria-hidden />
                    </div>
                    <h3 className="mb-2 text-base font-semibold">
                      {feature.title}
                    </h3>
                    <p className="text-sm leading-relaxed text-muted-foreground">
                      {feature.description}
                    </p>
                  </CardContent>
                </Card>
              </motion.div>
            );
          })}
        </motion.div>
      </div>
    </section>
  );
}
