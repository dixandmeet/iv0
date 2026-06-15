"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight, Building2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { fadeInUp, viewTransition } from "./landing-motion";

export function LandingProCta() {
  return (
    <section
      className="section-padding"
      aria-labelledby="pro-cta-title"
    >
      <div className="section-container">
        <motion.div
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={fadeInUp}
          className="relative overflow-hidden rounded-3xl border border-primary/20 bg-gradient-to-br from-primary/10 via-background to-realtime/5 p-8 sm:p-12 lg:p-16"
        >
          <div
            className="pointer-events-none absolute -right-20 -top-20 h-64 w-64 rounded-full bg-primary/10 blur-3xl"
            aria-hidden
          />
          <div className="relative grid items-center gap-8 lg:grid-cols-[1fr_auto]">
            <div>
              <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-primary/15 text-primary">
                <Building2 className="h-6 w-6" aria-hidden />
              </div>
              <h2
                id="pro-cta-title"
                className="text-2xl font-bold sm:text-3xl"
              >
                Vous gérez un réseau de transport ?
              </h2>
              <p className="mt-4 max-w-xl text-muted-foreground">
                Découvrez Aule Pro, la plateforme d&apos;exploitation conçue
                pour les conducteurs, agents terrain, superviseurs et
                régulateurs.
              </p>
            </div>
            <Button asChild size="lg" className="shrink-0">
              <Link href="/pro">
                Découvrir Aule Pro
                <ArrowRight />
              </Link>
            </Button>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
