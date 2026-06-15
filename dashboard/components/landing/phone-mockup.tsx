"use client";

import { AnimatePresence, motion } from "framer-motion";
import { cn } from "@/lib/utils";
import { HeroPhoneMap, ScreenMap } from "./hero-phone-map";
import { scaleIn } from "./landing-motion";

type FloatingCardProps = {
  children: React.ReactNode;
  className?: string;
  delay?: number;
};

function FloatingCard({ children, className, delay = 0 }: FloatingCardProps) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20, scale: 0.95 }}
      animate={{ opacity: 1, y: 0, scale: 1 }}
      transition={{ delay, duration: 0.6, ease: [0.22, 1, 0.36, 1] }}
      className={cn(
        "absolute rounded-2xl border border-white/20 bg-white/90 px-3 py-2 shadow-lg backdrop-blur-md dark:border-white/10 dark:bg-slate-900/90",
        className,
      )}
    >
      {children}
    </motion.div>
  );
}

export function PhoneMockup({ className }: { className?: string }) {
  return (
    <motion.div
      className={cn("relative mx-auto w-full max-w-[280px] sm:max-w-[300px]", className)}
      initial="hidden"
      animate="visible"
      variants={scaleIn}
    >
      <div className="relative animate-float">
        {/* Phone frame */}
        <div className="relative overflow-hidden rounded-[2.5rem] border-[6px] border-slate-800 bg-slate-900 shadow-phone dark:border-slate-700">
          {/* Notch */}
          <div className="absolute left-1/2 top-0 z-20 h-6 w-28 -translate-x-1/2 rounded-b-2xl bg-slate-800" />

          {/* Screen */}
          <div className="relative aspect-[9/19.5] w-full overflow-hidden bg-[#0d1117]">
            <HeroPhoneMap className="absolute inset-0 z-0" />

            {/* Top bar */}
            <div className="absolute left-0 right-0 top-8 z-10 flex items-center justify-between px-4">
              <div className="rounded-full bg-black/40 px-3 py-1 text-[10px] font-medium text-white backdrop-blur-sm">
                14:32
              </div>
              <div className="flex gap-1">
                <div className="h-2 w-2 rounded-full bg-white/60" />
                <div className="h-2 w-2 rounded-full bg-white/60" />
                <div className="h-2 w-2 rounded-full bg-realtime" />
              </div>
            </div>

            {/* Bottom sheet */}
            <div className="absolute bottom-0 left-0 right-0 z-10 rounded-t-3xl bg-slate-900/95 p-4 backdrop-blur-md">
              <div className="mx-auto mb-3 h-1 w-10 rounded-full bg-white/20" />
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20 text-lg">
                  🚊
                </div>
                <div className="flex-1">
                  <p className="text-xs font-semibold text-white">Ligne 1 · Direction Nort sur Erdre</p>
                  <p className="text-[10px] text-slate-400">Arrêt Commerce → Gare Nord</p>
                </div>
                <div className="rounded-lg bg-realtime/20 px-2 py-1 text-xs font-bold text-realtime">
                  3 min
                </div>
              </div>
              <div className="mt-3 h-1.5 overflow-hidden rounded-full bg-white/10">
                <motion.div
                  className="h-full rounded-full bg-primary"
                  initial={{ width: "20%" }}
                  animate={{ width: "65%" }}
                  transition={{ duration: 3, repeat: Infinity, repeatType: "reverse" }}
                />
              </div>
            </div>
          </div>
        </div>

        {/* Floating elements */}
        <FloatingCard
          className="-left-8 top-16 sm:-left-16"
          delay={0.8}
        >
          <div className="flex items-center gap-2">
            <div className="h-2 w-2 rounded-full bg-realtime animate-pulse-soft" />
            <span className="text-xs font-semibold text-slate-800 dark:text-white">
              Tram 1 · 3 min
            </span>
          </div>
        </FloatingCard>

        <FloatingCard
          className="-right-6 top-1/3 sm:-right-14"
          delay={1.1}
        >
          <div className="text-center">
            <p className="text-[10px] text-slate-500 dark:text-slate-400">Alerte arrivée</p>
            <p className="text-xs font-bold text-primary">Dans 2 arrêts</p>
          </div>
        </FloatingCard>

        <FloatingCard
          className="-left-4 bottom-32 sm:-left-12"
          delay={1.4}
        >
          <div className="flex items-center gap-2">
            <span className="text-sm">🔄</span>
            <div>
              <p className="text-[10px] text-slate-500">Correspondance</p>
              <p className="text-xs font-semibold">Ligne C4 · Quai B</p>
            </div>
          </div>
        </FloatingCard>
      </div>
    </motion.div>
  );
}

export function AppScreenMockup({
  variant = "guidage",
  featured = false,
  fillHeight = false,
  className,
}: {
  variant?: string;
  featured?: boolean;
  fillHeight?: boolean;
  className?: string;
}) {
  const screens: Record<string, { title: string; subtitle: string; color: string }> = {
    guidage: {
      title: "Marchez 4 min vers Commerce",
      subtitle: "Puis prenez le Tram 1",
      color: "bg-primary",
    },
    notifications: {
      title: "Votre tram arrive",
      subtitle: "Ligne 1 · 2 minutes",
      color: "bg-realtime",
    },
    suivi: {
      title: "Tram en approche",
      subtitle: "Position en temps réel",
      color: "bg-amber-500",
    },
    descente: {
      title: "Descendez au prochain arrêt",
      subtitle: "Gare Nord · dans 1 min",
      color: "bg-red-500",
    },
    correspondance: {
      title: "Correspondance Ligne C4",
      subtitle: "Quai B · 5 min de marche",
      color: "bg-violet-500",
    },
  };

  const screen = screens[variant] ?? screens.guidage;

  return (
    <div
      className={cn(
        "overflow-hidden rounded-2xl border border-border bg-card shadow-glass",
        fillHeight && "flex min-h-0 flex-col",
        featured && "rounded-[1.75rem] border-border/60",
        className,
      )}
    >
      <div
        className={cn(
          "flex shrink-0 items-center gap-2 border-b border-border px-4 py-3",
          featured && "px-5 py-3.5",
        )}
      >
        <div className="h-2 w-2 rounded-full bg-realtime animate-pulse-soft" />
        <span className="text-xs font-medium text-muted-foreground">Aule</span>
      </div>
      <div
        className={cn(
          "relative min-h-0 overflow-hidden bg-[#0d1117]",
          fillHeight ? "flex-1" : featured ? "aspect-[9/16]" : "aspect-[4/3]",
        )}
      >
        <ScreenMap variant={variant} className="absolute inset-0 h-full w-full" />
        <AnimatePresence mode="wait">
          <motion.div
            key={variant}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -8 }}
            transition={{ duration: 0.25, ease: [0.22, 1, 0.36, 1] }}
            className={cn(
              "absolute rounded-xl p-3 text-white",
              featured ? "bottom-4 left-4 right-4 p-4" : "bottom-3 left-3 right-3",
              screen.color,
            )}
          >
            <p className={cn("font-bold", featured ? "text-sm" : "text-xs")}>
              {screen.title}
            </p>
            <p
              className={cn(
                "opacity-80",
                featured ? "mt-0.5 text-xs" : "text-[10px]",
              )}
            >
              {screen.subtitle}
            </p>
          </motion.div>
        </AnimatePresence>
      </div>
    </div>
  );
}
