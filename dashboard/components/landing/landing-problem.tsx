"use client";

import { motion } from "framer-motion";
import {
  AlertTriangle,
  Clock,
  EyeOff,
  MapPin,
  Shuffle,
} from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { problems } from "./landing-data";
import { fadeInUp, staggerContainer, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

const iconMap = {
  clock: Clock,
  shuffle: Shuffle,
  alert: AlertTriangle,
  "map-pin": MapPin,
  "eye-off": EyeOff,
} as const;

export function LandingProblem() {
  return (
    <section className="section-padding bg-muted/40" aria-labelledby="problem-title">
      <div className="section-container">
        <SectionHeading
          eyebrow="Le constat"
          title="Prendre les transports devrait être plus simple"
          description="Chaque jour, des millions de voyageurs font face aux mêmes frustrations. Aule a été conçu pour y répondre."
          align="center"
        />

        <motion.div
          className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3"
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={staggerContainer}
        >
          {problems.map((problem) => {
            const Icon = iconMap[problem.icon];
            return (
              <motion.div key={problem.title} variants={fadeInUp}>
                <Card className="h-full border-border/60 bg-card/80 transition-shadow hover:shadow-glass">
                  <CardContent className="p-6">
                    <div className="mb-4 flex h-11 w-11 items-center justify-center rounded-xl bg-destructive/10 text-destructive">
                      <Icon className="h-5 w-5" aria-hidden />
                    </div>
                    <h3 id="problem-title" className="mb-2 font-semibold">
                      {problem.title}
                    </h3>
                    <p className="text-sm leading-relaxed text-muted-foreground">
                      {problem.description}
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
