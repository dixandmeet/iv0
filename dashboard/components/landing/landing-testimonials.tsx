"use client";

import { motion } from "framer-motion";
import { Star } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { testimonials } from "./landing-data";
import { fadeInUp, staggerContainer, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

function StarRating({ rating }: { rating: number }) {
  return (
    <div
      className="flex gap-0.5"
      role="img"
      aria-label={`${rating} étoiles sur 5`}
    >
      {Array.from({ length: 5 }).map((_, i) => (
        <Star
          key={i}
          className={`h-4 w-4 ${
            i < rating
              ? "fill-amber-400 text-amber-400"
              : "fill-muted text-muted"
          }`}
          aria-hidden
        />
      ))}
    </div>
  );
}

export function LandingTestimonials() {
  return (
    <section className="section-padding bg-muted/30" aria-labelledby="testimonials-title">
      <div className="section-container">
        <SectionHeading
          eyebrow="Témoignages"
          title="Ce que disent les voyageurs"
          description="Des usagers quotidiens, étudiants et visiteurs qui ont adopté Aule."
          align="center"
        />

        <motion.div
          className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4"
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={staggerContainer}
        >
          {testimonials.map((t) => (
            <motion.div key={t.name} variants={fadeInUp}>
              <Card className="h-full border-border/60">
                <CardContent className="flex h-full flex-col p-6">
                  <StarRating rating={t.rating} />
                  <blockquote className="mt-4 flex-1 text-sm leading-relaxed text-muted-foreground">
                    &ldquo;{t.text}&rdquo;
                  </blockquote>
                  <div className="mt-4 flex items-center gap-3 border-t border-border pt-4">
                    <div
                      className="flex h-10 w-10 items-center justify-center rounded-full bg-primary/10 text-sm font-bold text-primary"
                      aria-hidden
                    >
                      {t.avatar}
                    </div>
                    <div>
                      <p className="text-sm font-semibold">{t.name}</p>
                      <p className="text-xs text-muted-foreground">{t.role}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </motion.div>
          ))}
        </motion.div>
      </div>
    </section>
  );
}
