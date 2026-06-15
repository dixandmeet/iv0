"use client";

import { motion, useScroll, useTransform } from "framer-motion";
import { useRef } from "react";
import {
  Bell,
  Bus,
  Footprints,
  Route,
  Search,
  Timer,
} from "lucide-react";
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

export function LandingSolution() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start end", "end start"],
  });
  const lineWidth = useTransform(scrollYProgress, [0.1, 0.8], ["0%", "100%"]);

  return (
    <section
      id="comment-ca-marche"
      className="section-padding"
      aria-labelledby="solution-title"
    >
      <div className="section-container">
        <SectionHeading
          eyebrow="La solution"
          title="Aule vous guide du départ à l'arrivée"
          description="Un parcours fluide, étape par étape, pour ne plus jamais vous sentir perdu dans le réseau."
          align="center"
        />

        <div ref={containerRef} className="relative">
          {/* Progress line - desktop */}
          <div
            className="absolute left-0 right-0 top-8 hidden h-0.5 bg-border lg:block"
            aria-hidden
          >
            <motion.div
              className="h-full origin-left bg-gradient-to-r from-primary to-realtime"
              style={{ width: lineWidth }}
            />
          </div>

          <motion.ol
            className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3"
            initial="hidden"
            whileInView="visible"
            viewport={viewTransition}
            variants={staggerContainer}
          >
            {journeySteps.map((step, index) => {
              const Icon = stepIcons[step.icon];
              return (
                <motion.li
                  key={step.step}
                  variants={fadeInUp}
                  className="relative"
                >
                  <div className="glass-card flex h-full flex-col p-6 transition-transform hover:-translate-y-1">
                    <div className="mb-4 flex items-center gap-3">
                      <div className="relative flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-primary text-primary-foreground shadow-md">
                        <Icon className="h-5 w-5" aria-hidden />
                        <span className="absolute -right-1 -top-1 flex h-5 w-5 items-center justify-center rounded-full bg-realtime text-[10px] font-bold text-white">
                          {step.step}
                        </span>
                      </div>
                      {index < journeySteps.length - 1 && (
                        <div
                          className="hidden flex-1 border-t border-dashed border-border lg:block"
                          aria-hidden
                        />
                      )}
                    </div>
                    <h3 className="mb-2 font-semibold">{step.title}</h3>
                    <p className="text-sm leading-relaxed text-muted-foreground">
                      {step.description}
                    </p>
                  </div>
                </motion.li>
              );
            })}
          </motion.ol>
        </div>
      </div>
    </section>
  );
}
