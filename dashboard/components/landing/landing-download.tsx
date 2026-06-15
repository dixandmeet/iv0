"use client";

import { motion } from "framer-motion";
import { appStoreUrl, playStoreUrl } from "./landing-data";
import { fadeInUp, viewTransition } from "./landing-motion";
import { SectionHeading } from "./section-heading";

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
      className="rounded-2xl border border-border bg-white p-4 shadow-glass"
      role="img"
      aria-label="QR code de téléchargement Aule"
    >
      <svg viewBox="0 0 130 130" className="h-28 w-28 sm:h-32 sm:w-32">
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
      <p className="mt-2 text-center text-xs text-muted-foreground">
        Scanner pour télécharger
      </p>
    </div>
  );
}

function StoreBadge({
  store,
  href,
}: {
  store: "apple" | "google";
  href: string;
}) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-3 rounded-xl border border-border bg-card px-5 py-3 transition-all hover:border-primary/30 hover:shadow-glass focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
      aria-label={
        store === "apple"
          ? "Télécharger sur l'App Store"
          : "Télécharger sur Google Play"
      }
    >
      {store === "apple" ? (
        <svg viewBox="0 0 24 24" className="h-8 w-8" aria-hidden>
          <path
            fill="currentColor"
            d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"
          />
        </svg>
      ) : (
        <svg viewBox="0 0 24 24" className="h-8 w-8" aria-hidden>
          <path
            fill="currentColor"
            d="M3.609 1.814L13.792 12 3.61 22.186a1.372 1.372 0 01-.395-.983V2.797c0-.37.146-.72.394-.983zM14.5 12.707l2.302 2.302-10.937 6.333 8.635-8.635zM16.802 9.196l-2.302 2.302 2.302 2.303 5.988-3.46a1.05 1.05 0 000-1.82l-5.988-3.325zM5.864 2.658L16.8 8.99l-2.302 2.302L5.864 2.658z"
          />
        </svg>
      )}
      <div className="text-left">
        <p className="text-[10px] text-muted-foreground">
          {store === "apple" ? "Télécharger sur l'" : "Disponible sur"}
        </p>
        <p className="text-sm font-semibold">
          {store === "apple" ? "App Store" : "Google Play"}
        </p>
      </div>
    </a>
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
          className="mx-auto max-w-3xl text-center"
        >
          <SectionHeading
            title="Simplifiez vos trajets dès aujourd'hui"
            description="Téléchargez Aule gratuitement et profitez d'un guidage intelligent pour tous vos déplacements en transport en commun."
            align="center"
            className="mx-auto"
          />

          <div className="mt-10 flex flex-col items-center gap-8 sm:flex-row sm:justify-center">
            <div className="flex flex-col gap-3 sm:items-end">
              <StoreBadge store="apple" href={appStoreUrl} />
              <StoreBadge store="google" href={playStoreUrl} />
            </div>
            <div className="hidden h-24 w-px bg-border sm:block" aria-hidden />
            <QrCode />
          </div>
        </motion.div>
      </div>
    </section>
  );
}
