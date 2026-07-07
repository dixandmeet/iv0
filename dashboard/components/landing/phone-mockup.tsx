"use client";

import { motion } from "framer-motion";
import { Home, Star } from "lucide-react";
import { cn } from "@/lib/utils";
import { HeroPhoneMap } from "./hero-phone-map";
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
        <div className="relative overflow-hidden rounded-[2.5rem] border-[6px] border-slate-800 bg-slate-900 shadow-phone dark:border-slate-700">
          <div className="absolute left-1/2 top-0 z-20 h-6 w-28 -translate-x-1/2 rounded-b-2xl bg-slate-800" />

          <div className="relative aspect-[9/19.5] w-full overflow-hidden bg-[#0d1117]">
            <HeroPhoneMap className="absolute inset-0 z-0" />

            <div className="absolute left-0 right-0 top-8 z-10 flex items-center justify-between px-4">
              <div className="rounded-full bg-black/40 px-3 py-1 text-[10px] font-medium text-white backdrop-blur-sm">
                08:15
              </div>
              <div className="flex gap-1">
                <div className="h-2 w-2 rounded-full bg-white/60" />
                <div className="h-2 w-2 rounded-full bg-white/60" />
                <div className="h-2 w-2 rounded-full bg-realtime" />
              </div>
            </div>

            {/* Quick trips bar */}
            <div className="absolute left-3 right-3 top-16 z-10 flex gap-2">
              {[
                { icon: Home, label: "Domicile", active: true },
                { icon: Star, label: "Favoris", active: false },
              ].map(({ icon: Icon, label, active }) => (
                <div
                  key={label}
                  className={cn(
                    "flex items-center gap-1.5 rounded-full px-2.5 py-1 text-[10px] font-medium backdrop-blur-md",
                    active
                      ? "bg-primary/90 text-white"
                      : "bg-black/40 text-white/80",
                  )}
                >
                  <Icon className="h-3 w-3" aria-hidden />
                  {label}
                </div>
              ))}
            </div>

            {/* Bottom sheet */}
            <div className="absolute bottom-0 left-0 right-0 z-10 rounded-t-3xl bg-slate-900/95 p-4 backdrop-blur-md">
              <div className="mx-auto mb-3 h-1 w-10 rounded-full bg-white/20" />
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/20 text-lg">
                  🚊
                </div>
                <div className="flex-1">
                  <p className="text-xs font-semibold text-white">
                    Tram 1 · Direction Nort sur Erdre
                  </p>
                  <p className="text-[10px] text-slate-400">
                    Commerce → Gare Nord · trajet récurrent
                  </p>
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
                  transition={{
                    duration: 3,
                    repeat: Infinity,
                    repeatType: "reverse",
                  }}
                />
              </div>
            </div>
          </div>
        </div>

        <FloatingCard className="-left-8 top-20 sm:-left-16" delay={0.8}>
          <div className="flex items-center gap-2">
            <Star className="h-3 w-3 fill-amber-400 text-amber-400" aria-hidden />
            <span className="text-xs font-semibold text-slate-800 dark:text-white">
              Arrêt favori · Commerce
            </span>
          </div>
        </FloatingCard>

        <FloatingCard className="-right-6 top-1/3 sm:-right-14" delay={1.1}>
          <div className="text-center">
            <p className="text-[10px] text-slate-500 dark:text-slate-400">
              Alerte arrivée
            </p>
            <p className="text-xs font-bold text-primary">Dans 2 arrêts</p>
          </div>
        </FloatingCard>

        <FloatingCard className="-left-4 bottom-36 sm:-left-12" delay={1.4}>
          <div className="flex items-center gap-2">
            <Home className="h-3.5 w-3.5 text-primary" aria-hidden />
            <div>
              <p className="text-[10px] text-slate-500">Trajet récurrent</p>
              <p className="text-xs font-semibold">Domicile → Travail</p>
            </div>
          </div>
        </FloatingCard>
      </div>
    </motion.div>
  );
}
