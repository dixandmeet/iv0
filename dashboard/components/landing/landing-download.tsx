"use client";

import Link from "next/link";
import { motion } from "framer-motion";
import { ArrowRight } from "lucide-react";
import { fadeInUp, viewTransition } from "./landing-motion";

function QrCode() {
  const cells = [
    [1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1],
    [1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0, 0, 1],
    [1, 0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1],
    [1, 0, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 1],
    [1, 1, 1, 1, 1, 0, 1, 0, 1, 1, 1, 1, 1],
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0],
    [1, 0, 1, 1, 0, 0, 1, 0, 1, 1, 0, 1, 0],
    [0, 1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 0, 1],
    [1, 0, 1, 0, 0, 1, 1, 0, 1, 0, 1, 1, 0],
    [0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1],
    [1, 1, 1, 1, 1, 0, 1, 0, 1, 0, 1, 1, 1],
    [1, 0, 0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0],
    [1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1],
  ];

  return (
    <div
      className="rounded-2xl border border-border bg-white p-5 shadow-glass dark:bg-card"
      role="img"
      aria-label="QR code Aule bientôt disponible"
    >
      <svg viewBox="0 0 130 130" className="h-32 w-32">
        {cells.map((row, y) =>
          row.map((cell, x) =>
            cell ? (
              <rect
                key={`${x}-${y}`}
                x={x * 10}
                y={y * 10}
                width={10}
                height={10}
                fill="currentColor"
                className="text-foreground"
              />
            ) : null,
          ),
        )}
      </svg>
      <p className="mt-3 text-center text-xs text-muted-foreground">
        Bientôt disponible
      </p>
    </div>
  );
}

function StoreBadge({
  store,
}: {
  store: "apple" | "google";
}) {
  return (
    <div
      className="inline-flex w-full cursor-default items-center gap-4 rounded-2xl border border-border bg-card px-6 py-4 opacity-80 sm:w-auto sm:min-w-[220px]"
      aria-label={`${store === "apple" ? "App Store" : "Google Play"} : bientôt disponible`}
    >
      {store === "apple" ? (
        <svg viewBox="0 0 24 24" className="h-9 w-9 shrink-0" aria-hidden>
          <path
            fill="currentColor"
            d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"
          />
        </svg>
      ) : (
        <svg viewBox="0 0 24 24" className="h-9 w-9 shrink-0" aria-hidden>
          <path
            fill="currentColor"
            d="M3.609 1.814L13.792 12 3.61 22.186a1.372 1.372 0 01-.395-.983V2.797c0-.37.146-.72.394-.983zM14.5 12.707l2.302 2.302-10.937 6.333 8.635-8.635zM16.802 9.196l-2.302 2.302 2.302 2.303 5.988-3.46a1.05 1.05 0 000-1.82l-5.988-3.325zM5.864 2.658L16.8 8.99l-2.302 2.302L5.864 2.658z"
          />
        </svg>
      )}
      <div className="text-left">
        <p className="text-[11px] text-muted-foreground">{store === "apple" ? "App Store" : "Google Play"}</p>
        <p className="text-base font-semibold">
          Bientôt disponible
        </p>
      </div>
    </div>
  );
}

export function LandingDownload() {
  return (
    <section
      id="telecharger"
      className="section-padding"
      aria-labelledby="download-title"
    >
      <div className="section-container">
        <motion.div
          initial="hidden"
          whileInView="visible"
          viewport={viewTransition}
          variants={fadeInUp}
          className="relative overflow-hidden rounded-3xl border border-primary/20 bg-gradient-to-br from-primary/10 via-background to-realtime/5 p-8 sm:p-12 lg:p-16"
        >
          <div className="hero-mesh pointer-events-none absolute inset-0 opacity-60" aria-hidden />

          <div className="relative grid items-center gap-10 lg:grid-cols-[1fr_auto] lg:gap-16">
            <div className="text-center lg:text-left">
              <h2
                id="download-title"
                className="text-3xl font-bold tracking-tight sm:text-4xl"
              >
                Simplifiez vos trajets dès aujourd&apos;hui
              </h2>
              <p className="mt-4 max-w-lg text-base leading-relaxed text-muted-foreground sm:text-lg lg:mx-0">
                Aule sera bientôt disponible sur iOS et Android. Les liens
                officiels seront activés dès l&apos;ouverture des stores.
              </p>
              <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:justify-center lg:justify-start">
                <StoreBadge store="apple" />
                <StoreBadge store="google" />
              </div>
              <p className="mt-6 text-sm text-muted-foreground">
                Vous gérez un réseau de transport ?{" "}
                <Link
                  href="/pro"
                  className="font-medium text-primary underline-offset-4 hover:underline"
                >
                  Découvrez Aule Pro
                  <ArrowRight className="ml-0.5 inline h-3.5 w-3.5" />
                </Link>
              </p>
            </div>

            <div className="flex justify-center lg:justify-end">
              <div className="opacity-60" aria-hidden="true"><QrCode /></div>
            </div>
          </div>
        </motion.div>
      </div>
    </section>
  );
}
