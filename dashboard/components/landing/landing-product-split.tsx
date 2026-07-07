"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight, Building2, Smartphone } from "lucide-react";
import { Button } from "@/components/ui/button";
import { productSplit } from "./landing-data";
import { fadeInUp, staggerContainer, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

export function LandingProductSplit() {
  const { traveler, pro } = productSplit;

  return (
    <section
      id="produits"
      className="section-padding section-alt"
      aria-labelledby="products-title"
    >
      <div className="section-container">
        <SectionHeading
          eyebrow="Deux applications, un écosystème"
          title="Aule pour voyager, Aule Pro pour exploiter"
          titleId="products-title"
          description="Une expérience voyageur gratuite et une plateforme professionnelle pour les réseaux de transport."
          align="center"
          className="mx-auto"
        />

        <motion.div
          className="grid gap-6 lg:grid-cols-2"
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={staggerContainer}
        >
          <motion.article
            variants={fadeInUp}
            className="group relative overflow-hidden rounded-3xl border border-primary/20 bg-gradient-to-br from-primary/5 via-background to-background p-8 shadow-glass transition-all hover:border-primary/40 hover:shadow-glow"
          >
            <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-primary/10 text-primary transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
              <Smartphone className="h-7 w-7" aria-hidden />
            </div>
            <p className="text-sm font-semibold uppercase tracking-wider text-primary">
              {traveler.eyebrow}
            </p>
            <h3 className="mt-2 text-2xl font-bold">{traveler.title}</h3>
            <p className="mt-3 text-muted-foreground">{traveler.description}</p>
            <ul className="mt-6 space-y-2">
              {traveler.highlights.map((item) => (
                <li
                  key={item}
                  className="flex items-center gap-2 text-sm text-foreground/80"
                >
                  <span className="h-1.5 w-1.5 rounded-full bg-realtime" />
                  {item}
                </li>
              ))}
            </ul>
            <Button asChild className="mt-8" size="lg">
              <a href={traveler.ctaPrimary.href}>
                {traveler.ctaPrimary.label}
                <ArrowRight className="ml-1" />
              </a>
            </Button>
          </motion.article>

          <motion.article
            variants={fadeInUp}
            className="group relative overflow-hidden rounded-3xl border border-border bg-card p-8 shadow-glass transition-all hover:border-primary/30 hover:shadow-glow"
          >
            <div className="mb-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-muted text-foreground transition-colors group-hover:bg-primary group-hover:text-primary-foreground">
              <Building2 className="h-7 w-7" aria-hidden />
            </div>
            <p className="text-sm font-semibold uppercase tracking-wider text-muted-foreground">
              {pro.eyebrow}
            </p>
            <h3 className="mt-2 text-2xl font-bold">{pro.title}</h3>
            <p className="mt-3 text-muted-foreground">{pro.description}</p>
            <ul className="mt-6 space-y-2">
              {pro.highlights.map((item) => (
                <li
                  key={item}
                  className="flex items-center gap-2 text-sm text-foreground/80"
                >
                  <span className="h-1.5 w-1.5 rounded-full bg-primary" />
                  {item}
                </li>
              ))}
            </ul>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row">
              <Button asChild size="lg">
                <Link href={pro.ctaPrimary.href}>
                  {pro.ctaPrimary.label}
                  <ArrowRight className="ml-1" />
                </Link>
              </Button>
              <Button asChild variant="outline" size="lg">
                <Link href={pro.ctaSecondary.href}>{pro.ctaSecondary.label}</Link>
              </Button>
            </div>
          </motion.article>
        </motion.div>
      </div>
    </section>
  );
}
