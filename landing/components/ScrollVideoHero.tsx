"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";

type ScrollVideoHeroProps = {
  /** Chemin de la vidéo (dans /public), ex. "/hero-scroll.mp4" */
  src: string;
  /**
   * Hauteur du container en multiples de 100vh (3 => 300vh).
   * Réduit automatiquement à 2 sur mobile (< 768px).
   */
  scrollLength?: number;
  /** Contenu affiché en overlay par-dessus la vidéo */
  children?: ReactNode;
};

export default function ScrollVideoHero({
  src,
  scrollLength = 3,
  children,
}: ScrollVideoHeroProps) {
  const containerRef = useRef<HTMLElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);

  // null = pas encore mesuré (SSR) — on rend 300vh par défaut, corrigé au mount
  const [reducedMotion, setReducedMotion] = useState<boolean>(false);
  const [effectiveLength, setEffectiveLength] = useState<number>(scrollLength);

  // --- Media queries : prefers-reduced-motion + mobile (< 768px) ---
  useEffect(() => {
    const mqMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const mqMobile = window.matchMedia("(max-width: 767px)");

    const update = (): void => {
      setReducedMotion(mqMotion.matches);
      // Sur mobile, scroll plus court (max 2 écrans)
      setEffectiveLength(mqMobile.matches ? Math.min(scrollLength, 2) : scrollLength);
    };
    update();

    mqMotion.addEventListener("change", update);
    mqMobile.addEventListener("change", update);
    return () => {
      mqMotion.removeEventListener("change", update);
      mqMobile.removeEventListener("change", update);
    };
  }, [scrollLength]);

  // --- Mode reduced-motion : lecture normale en boucle, pas de scrubbing ---
  useEffect(() => {
    const video = videoRef.current;
    if (!video) return;
    if (reducedMotion) {
      video.loop = true;
      // play() peut être rejeté (politique autoplay) — on ignore silencieusement
      void video.play().catch(() => undefined);
    } else {
      video.pause();
      video.loop = false;
    }
  }, [reducedMotion]);

  // --- Boucle rAF de scrubbing ---
  useEffect(() => {
    if (reducedMotion) return; // pas de scrubbing en reduced-motion

    const container = containerRef.current;
    const video = videoRef.current;
    if (!container || !video) return;

    let rafId = 0;
    let duration = 0;
    let lastSeek = -1;

    // duration n'est connue qu'après loadedmetadata
    const onMeta = (): void => {
      duration = video.duration;
    };
    if (video.readyState >= HTMLMediaElement.HAVE_METADATA) {
      duration = video.duration;
    } else {
      video.addEventListener("loadedmetadata", onMeta);
    }

    const tick = (): void => {
      rafId = requestAnimationFrame(tick);
      if (!duration || Number.isNaN(duration)) return;

      // Calcul de la progression :
      // rect.top vaut 0 quand le haut du container touche le haut du viewport,
      // et -(hauteur - viewport) quand le bas du container touche le bas du viewport.
      // progress passe donc de 0 à 1 pendant toute la phase "sticky".
      const rect = container.getBoundingClientRect();
      const scrollable = rect.height - window.innerHeight;
      const progress =
        scrollable > 0 ? Math.min(1, Math.max(0, -rect.top / scrollable)) : 0;

      // Petite marge avant la fin pour éviter l'affichage de la frame "ended"
      const target = progress * Math.max(0, duration - 0.05);

      // Un seek est coûteux : on ne réassigne currentTime que si la cible
      // a bougé d'au moins ~1/60s depuis le dernier seek.
      if (Math.abs(target - lastSeek) > 1 / 60) {
        video.currentTime = target;
        lastSeek = target;
      }
    };
    rafId = requestAnimationFrame(tick);

    // Nettoyage : on annule le rAF et on retire le listener
    return () => {
      cancelAnimationFrame(rafId);
      video.removeEventListener("loadedmetadata", onMeta);
    };
  }, [reducedMotion]);

  return (
    <section
      ref={containerRef}
      // En reduced-motion, un simple écran suffit (pas de zone de scrub)
      style={{ height: reducedMotion ? "100vh" : `${effectiveLength * 100}vh` }}
      className="relative"
    >
      <div className="sticky top-0 h-screen overflow-hidden">
        <video
          ref={videoRef}
          src={src}
          muted
          playsInline
          preload="auto"
          className="h-full w-full object-cover"
        />
        {/* Voile sombre pour la lisibilité du texte */}
        <div className="pointer-events-none absolute inset-0 bg-black/30" />
        {/* Contenu overlay */}
        <div className="absolute inset-0">{children}</div>
      </div>
    </section>
  );
}
