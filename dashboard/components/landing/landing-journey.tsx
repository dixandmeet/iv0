"use client";

import { motion } from "framer-motion";
import {
  Bell,
  Bus,
  Footprints,
  Route,
  Search,
  Timer,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { journeySteps } from "./landing-data";
import { fadeInUp, staggerContainer, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

const stepIcons = {
  search: Search,
  footprints: Footprints,
  timer: Timer,
  bus: Bus,
  route: Route,
  bell: Bell,
} as const;

export function LandingJourney() {
  return (
    <section
      id="comment-ca-marche"
      className="section-padding section-alt"
      aria-labelledby="journey-title"
    >
      <div className="section-container">
        <SectionHeading
          eyebrow="Comment ça marche"
          title="Du départ à l'arrivée en 6 étapes"
          titleId="journey-title"
          description="Aule vous guide à chaque moment de votre trajet, sans prise de tête."
          align="center"
          className="mx-auto"
        />

        <motion.ol
          className="relative grid gap-8 sm:grid-cols-2 lg:grid-cols-3 lg:gap-x-8 lg:gap-y-12"
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={staggerContainer}
        >
          {journeySteps.map((step, index) => {
            const Icon = stepIcons[step.icon as keyof typeof stepIcons] ?? Search;
            const isLast = index === journeySteps.length - 1;

            return (
              <motion.li
                key={step.step}
                variants={fadeInUp}
                className="relative flex gap-4 lg:flex-col lg:items-center lg:text-center"
              >
                <div className="relative flex shrink-0 flex-col items-center">
                  <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-primary text-primary-foreground shadow-glow">
                    <Icon className="h-5 w-5" aria-hidden />
                  </div>
                  <span className="mt-2 text-xs font-bold text-primary">
                    {String(step.step).padStart(2, "0")}
                  </span>
                  {!isLast && (
                    <div
                      className={cn(
                        "absolute top-12 hidden h-full w-px bg-border lg:hidden",
                        "sm:block sm:left-6 sm:top-14 sm:h-[calc(100%+2rem)] sm:w-px",
                        "lg:hidden",
                      )}
                      aria-hidden
                    />
                  )}
                </div>
                <div className="pt-1 lg:pt-4">
                  <h3 className="font-semibold">{step.title}</h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                    {step.description}
                  </p>
                </div>
              </motion.li>
            );
          })}
        </motion.ol>
      </div>
    </section>
  );
}
