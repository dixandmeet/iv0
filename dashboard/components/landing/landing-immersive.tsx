"use client";

import { useState } from "react";
import { motion } from "framer-motion";
import {
  ArrowRightLeft,
  BellRing,
  LogOut,
  Navigation,
  Radio,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { immersiveHighlights } from "./landing-data";
import { fadeInUp, staggerContainer, viewTransition } from "./landing-motion";
import { AppScreenMockup } from "./phone-mockup";
import { SectionHeading } from "./section-heading";

const highlightIcons = {
  navigation: Navigation,
  "bell-ring": BellRing,
  radio: Radio,
  "log-out": LogOut,
  "arrow-right-left": ArrowRightLeft,
} as const;

export function LandingImmersive() {
  const [activeIndex, setActiveIndex] = useState(0);
  const active = immersiveHighlights[activeIndex];

  return (
    <section
      id="experience"
      className="section-padding bg-muted/20"
      aria-labelledby="immersive-title"
    >
      <div className="section-container">
        <SectionHeading
          eyebrow="Expérience"
          titleId="immersive-title"
          title="Un GPS conçu pour les transports en commun"
          description="Pas une simple carte : un compagnon de voyage qui comprend les spécificités du réseau — guidage, alertes et suivi en temps réel."
          align="center"
        />

        <motion.div
          className="grid items-stretch gap-6 lg:grid-cols-2 lg:gap-14"
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={staggerContainer}
        >
          <motion.div
            variants={fadeInUp}
            className="order-2 flex flex-col gap-3 lg:order-1"
          >
            {immersiveHighlights.map((item, i) => {
              const Icon = highlightIcons[item.icon];
              const isActive = activeIndex === i;

              return (
                <button
                  key={item.title}
                  type="button"
                  onClick={() => setActiveIndex(i)}
                  aria-pressed={isActive}
                  className={cn(
                    "glass-card flex w-full gap-4 p-5 text-left transition-all",
                    isActive
                      ? "border-primary/40 bg-primary/5 shadow-glow"
                      : "hover:border-primary/20 hover:bg-card",
                  )}
                >
                  <div
                    className={cn(
                      "flex h-10 w-10 shrink-0 items-center justify-center rounded-xl transition-colors",
                      isActive
                        ? "bg-primary text-primary-foreground"
                        : "bg-primary/10 text-primary",
                    )}
                  >
                    <Icon className="h-5 w-5" aria-hidden />
                  </div>
                  <div className="min-w-0 flex-1">
                    <h3 className="font-semibold">{item.title}</h3>
                    <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
                      {item.description}
                    </p>
                  </div>
                </button>
              );
            })}
          </motion.div>

          <motion.div
            variants={fadeInUp}
            className="relative order-1 flex h-full min-h-[240px] lg:order-2 lg:min-h-0"
          >
            <div
              className="pointer-events-none absolute -inset-4 rounded-[2rem] bg-gradient-to-br from-primary/15 via-transparent to-realtime/10 blur-2xl lg:-inset-6"
              aria-hidden
            />

            <div className="relative flex h-full w-full flex-col">
              <AppScreenMockup
                variant={active.screen}
                featured
                fillHeight
                className="relative flex min-h-0 flex-1 flex-col shadow-phone"
              />

              <p className="mt-3 shrink-0 text-center text-sm text-muted-foreground">
                <span className="font-medium text-foreground">
                  {active.title}
                </span>
                {" · "}
                Aperçu de l&apos;application
              </p>
            </div>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}
