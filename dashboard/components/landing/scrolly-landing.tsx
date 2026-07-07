"use client";

import { useCallback, useEffect, useRef, type CSSProperties } from "react";
import styles from "./scrolly-landing.module.css";

const LOGO = "/aule-logo.png";
const SECTION_COUNT = 9;
const SCROLL_HEIGHT_VH = SECTION_COUNT * 120;

// La nouvelle étape Voyageurs s'insère entre les deux premières frames
// historiques afin de conserver la synchronisation des huit scènes existantes.
const VIDEO_PROGRESS_BY_SECTION = [
  0,
  1 / 14,
  1 / 7,
  2 / 7,
  3 / 7,
  4 / 7,
  5 / 7,
  6 / 7,
  1,
] as const;

const STEP_BY_HASH: Record<string, number> = {
  "#accueil": 0,
  "#voyageurs": 1,
  "#temps-reel": 2,
  "#notifications": 3,
  "#trajet": 4,
  "#communaute": 5,
  "#commercants": 6,
  "#aule-pro": 7,
  "#reseau-vivant": 8,
};

const travelerPillars = [
  {
    icon: "🧭",
    title: "Organisez votre trajet",
    description:
      "Itinéraires multimodaux, favoris, trajets récurrents et options d’accessibilité.",
  },
  {
    icon: "📡",
    title: "Voyagez en temps réel",
    description:
      "Position des véhicules, ETA, alertes d’arrivée et perturbations sur votre parcours.",
  },
  {
    icon: "🤝",
    title: "Enrichissez le réseau",
    description:
      "Partage GPS consenti et anonymisé, incidents, retards et affluence signalés.",
  },
  {
    icon: "🚕",
    title: "Prolongez votre trajet",
    description:
      "VTC, taxis et commandes commerçantes synchronisés avec votre heure d’arrivée.",
    status: "Bientôt disponible",
  },
] as const;

// ---- Styles partagés (identiques d'une section à l'autre) ----
const eyebrow: CSSProperties = {
  display: "inline-block",
  fontSize: 13,
  letterSpacing: "0.16em",
  textTransform: "uppercase",
  color: "#33BFA3",
  marginBottom: 18,
  padding: "6px 14px",
  borderRadius: 999,
  background: "rgba(5,8,7,0.55)",
  backdropFilter: "blur(12px)",
  WebkitBackdropFilter: "blur(12px)",
  border: "1px solid rgba(51,191,163,0.25)",
};

const featureIcon: CSSProperties = {
  display: "inline-flex",
  alignItems: "center",
  justifyContent: "center",
  width: 34,
  height: 34,
  flex: "none",
  borderRadius: 10,
  background: "rgba(51,191,163,0.12)",
  border: "1px solid rgba(51,191,163,0.25)",
};

const chip: CSSProperties = {
  fontSize: 14,
  padding: "10px 16px",
  borderRadius: 999,
  background: "rgba(12,18,16,0.6)",
  backdropFilter: "blur(16px)",
  border: "1px solid rgba(255,255,255,0.14)",
};

const proTag: CSSProperties = {
  padding: "14px 12px",
  borderRadius: 16,
  background: "rgba(12,18,16,0.6)",
  backdropFilter: "blur(16px)",
  border: "1px solid rgba(255,255,255,0.12)",
  fontSize: 13.5,
};

const footerColTitle: CSSProperties = {
  fontSize: 12,
  letterSpacing: "0.12em",
  textTransform: "uppercase",
  color: "rgba(255,255,255,0.4)",
  marginBottom: 16,
};

const footerColList: CSSProperties = {
  display: "flex",
  flexDirection: "column",
  gap: 11,
};

type ScrollyLandingProps = {
  /** Classe injectée par next/font pour exposer --font-space-grotesk. */
  fontClassName?: string;
};

export function ScrollyLanding({ fontClassName = "" }: ScrollyLandingProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  const containerRef = useRef<HTMLElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const progressBarRef = useRef<HTMLDivElement>(null);

  const navigateToStep = useCallback((index: number, hash?: string) => {
    const container = containerRef.current;
    const video = videoRef.current;
    if (!container) return;

    const scrollable = container.offsetHeight - window.innerHeight;
    const top =
      container.offsetTop + ((index + 0.5) / SECTION_COUNT) * scrollable;
    const reducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    if (video?.duration) {
      video.pause();
      video.currentTime =
        VIDEO_PROGRESS_BY_SECTION[index] *
        Math.max(0, video.duration - 0.05);
    }

    if (hash) window.history.replaceState(null, "", hash);
    window.scrollTo({
      top,
      behavior: reducedMotion ? "auto" : "smooth",
    });
  }, []);

  useEffect(() => {
    const container = containerRef.current;
    const video = videoRef.current;
    const progressBar = progressBarRef.current;
    if (!container || !video) return;

    const reducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)",
    ).matches;

    const cleanups: Array<() => void> = [];
    let rafId = 0;
    let snapRaf = 0;
    let stepSafety = 0;
    let duration = 0;

    // État de la navigation par étapes / lecture vidéo
    let videoTarget: number | null = null;
    let videoDir = 0;
    let revFrom = 0;
    let revStart = 0;
    let revDur = 0;
    let stepBusy = false;
    let stepCooldown = 0;


    // ===== Câblage vidéo : source adaptée + durée =====
    const sections = Array.from(
      container.querySelectorAll<HTMLElement>("[data-sec]"),
    );
    const onMeta = () => {
      duration = video.duration;
    };
    video.addEventListener("loadedmetadata", onMeta);
    cleanups.push(() => video.removeEventListener("loadedmetadata", onMeta));

    const isMobile = window.matchMedia("(max-width: 767px)").matches;
    video.src = isMobile ? "/hero-scroll-mobile.mp4" : "/hero-scroll-final.mp4";
    if (reducedMotion) {
      video.loop = true;
      void video.play().catch(() => {});
    } else {
      video.pause();
      video.currentTime = 0;
      videoTarget = 0;
      videoDir = 0;
    }

    // ===== Navigation par étapes : un geste = une étape =====
    if (!reducedMotion) {
      const N = SECTION_COUNT;
      const RATE = 2.2; // vitesse de lecture pendant une transition

      const targetForSection = (i: number) => {
        const scrollable = container.offsetHeight - window.innerHeight;
        return container.offsetTop + ((i + 0.5) / N) * scrollable;
      };

      const timeForSection = (i: number) => {
        const seg = Math.max(0, duration - 0.05);
        return VIDEO_PROGRESS_BY_SECTION[i] * seg;
      };

      const playVideoTo = (destTime: number, dir: number) => {
        if (!duration) return 0;
        videoTarget = destTime;
        videoDir = dir;
        const segSec = Math.abs(destTime - video.currentTime);
        const playMs = Math.max(420, (segSec / RATE) * 1000);
        if (dir > 0) {
          video.playbackRate = RATE;
          void video.play().catch(() => {});
        } else {
          revFrom = video.currentTime;
          revStart = performance.now();
          revDur = playMs;
        }
        return playMs;
      };

      const currentIndex = () => {
        const scrollable = container.offsetHeight - window.innerHeight;
        const overall = (window.scrollY - container.offsetTop) / scrollable;
        return Math.max(0, Math.min(N - 1, Math.round(overall * N - 0.5)));
      };

      const inStepZone = () => {
        const scrollable = container.offsetHeight - window.innerHeight;
        const overall = (window.scrollY - container.offsetTop) / scrollable;
        return overall >= -0.01 && overall <= 1.01;
      };

      const animateTo = (destY: number, dur: number) => {
        if (snapRaf) cancelAnimationFrame(snapRaf);
        const startY = window.scrollY;
        const dist = destY - startY;
        if (Math.abs(dist) < 2) return;
        const t0 = performance.now();
        const frame = (now: number) => {
          const t = Math.min(1, (now - t0) / dur);
          const e = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
          window.scrollTo(0, startY + dist * e);
          if (t < 1) snapRaf = requestAnimationFrame(frame);
          else snapRaf = 0;
        };
        snapRaf = requestAnimationFrame(frame);
      };

      const step = (dir: number) => {
        const cur = currentIndex();
        const next = Math.max(0, Math.min(N - 1, cur + dir));
        if (next === cur) return false;
        stepBusy = true;
        const playMs = playVideoTo(timeForSection(next), dir);
        animateTo(targetForSection(next), Math.max(playMs, 380));
        if (stepSafety) clearTimeout(stepSafety);
        stepSafety = window.setTimeout(
          () => {
            videoDir = 0;
            stepBusy = false;
            stepCooldown = performance.now() + 120;
            video.pause();
          },
          Math.max(playMs, 380) + 700,
        );
        return true;
      };

      const shouldHandle = (dir: number) => {
        if (!inStepZone()) return false;
        const cur = currentIndex();
        if (dir > 0 && cur === N - 1) return false; // sortie vers le footer
        if (dir < 0 && cur === 0) return false; // au-dessus du hero
        return true;
      };

      const busy = () => stepBusy || performance.now() < stepCooldown;

      // Molette / trackpad
      const onWheel = (e: WheelEvent) => {
        const dir = e.deltaY > 0 ? 1 : -1;
        if (!shouldHandle(dir)) return;
        e.preventDefault();
        if (busy()) return;
        step(dir);
      };
      window.addEventListener("wheel", onWheel, { passive: false });
      cleanups.push(() => window.removeEventListener("wheel", onWheel));

      // Tactile
      let touchY = 0;
      const onTouchStart = (e: TouchEvent) => {
        touchY = e.touches[0].clientY;
      };
      const onTouchMove = (e: TouchEvent) => {
        const dy = touchY - e.touches[0].clientY;
        const dir = dy > 0 ? 1 : -1;
        if (!shouldHandle(dir)) return;
        e.preventDefault();
        if (busy()) return;
        if (Math.abs(dy) > 22) {
          step(dir);
          touchY = e.touches[0].clientY;
        }
      };
      window.addEventListener("touchstart", onTouchStart, { passive: true });
      window.addEventListener("touchmove", onTouchMove, { passive: false });
      cleanups.push(() =>
        window.removeEventListener("touchstart", onTouchStart),
      );
      cleanups.push(() => window.removeEventListener("touchmove", onTouchMove));

      // Clavier
      const onKey = (e: KeyboardEvent) => {
        let dir = 0;
        if (e.key === "ArrowDown" || e.key === "PageDown" || e.key === " ")
          dir = 1;
        else if (e.key === "ArrowUp" || e.key === "PageUp") dir = -1;
        if (!dir || !shouldHandle(dir)) return;
        e.preventDefault();
        if (busy()) return;
        step(dir);
      };
      window.addEventListener("keydown", onKey);
      cleanups.push(() => window.removeEventListener("keydown", onKey));
    }

    const smooth = (a: number, b: number, x: number) => {
      const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
      return t * t * (3 - 2 * t);
    };

    // ===== Boucle rAF : scrub vidéo + orchestration =====
    const tick = () => {
      rafId = requestAnimationFrame(tick);

      const rect = container.getBoundingClientRect();
      const scrollable = rect.height - window.innerHeight;
      const overall =
        scrollable > 0 ? Math.min(1, Math.max(0, -rect.top / scrollable)) : 0;

      if (progressBar)
        progressBar.style.width = (overall * 100).toFixed(2) + "%";

      // Lecture par étapes : la vidéo joue puis se met en pause sur la frame cible
      if (!reducedMotion && duration && videoTarget != null) {
        if (videoDir > 0) {
          if (video.currentTime >= videoTarget || video.ended) {
            video.pause();
            video.currentTime = Math.min(videoTarget, duration - 0.05);
            videoDir = 0;
            stepBusy = false;
            stepCooldown = performance.now() + 120;
          }
        } else if (videoDir < 0) {
          const t = Math.min(1, (performance.now() - revStart) / revDur);
          video.currentTime = revFrom + (videoTarget - revFrom) * t;
          if (t >= 1) {
            videoDir = 0;
            stepBusy = false;
            stepCooldown = performance.now() + 120;
          }
        }
      }

      // Orchestration : chaque section occupe 1/9 du scroll
      const n = sections.length;
      for (let i = 0; i < n; i++) {
        const el = sections[i];
        const p = overall * n - i;
        if (p < -0.25 || p > 1.25) {
          el.style.opacity = "0";
          el.style.visibility = "hidden";
          continue;
        }
        el.style.visibility = "visible";
        const fadeIn = i === 0 ? 1 : smooth(0.04, 0.2, p);
        const fadeOut = i === n - 1 ? 1 : 1 - smooth(0.84, 0.99, p);
        const vis = fadeIn * fadeOut;
        el.style.opacity = vis.toFixed(3);
        if (reducedMotion) continue;
        el.style.filter =
          vis > 0.98 ? "none" : "blur(" + ((1 - vis) * 10).toFixed(1) + "px)";
        const drift = (1 - fadeIn) * 70 - (1 - fadeOut) * 70;
        const pars = el.querySelectorAll<HTMLElement>("[data-par]");
        for (const layer of pars) {
          const speed = parseFloat(layer.getAttribute("data-par") ?? "1") || 1;
          layer.style.transform =
            "translateY(" +
            (drift * speed).toFixed(1) +
            "px) scale(" +
            (0.965 + 0.035 * vis).toFixed(4) +
            ")";
        }
      }
    };
    rafId = requestAnimationFrame(tick);

    return () => {
      cancelAnimationFrame(rafId);
      if (snapRaf) cancelAnimationFrame(snapRaf);
      if (stepSafety) clearTimeout(stepSafety);
      for (const fn of cleanups) fn();
    };
  }, []);

  useEffect(() => {
    const index = STEP_BY_HASH[window.location.hash];
    if (index === undefined) return;

    const video = videoRef.current;
    const syncVideo = () => {
      if (!video?.duration) return;
      video.pause();
      video.currentTime =
        VIDEO_PROGRESS_BY_SECTION[index] *
        Math.max(0, video.duration - 0.05);
    };
    const frame = requestAnimationFrame(() => navigateToStep(index));

    if (video?.readyState && video.readyState >= 1) syncVideo();
    else video?.addEventListener("loadedmetadata", syncVideo, { once: true });

    return () => {
      cancelAnimationFrame(frame);
      video?.removeEventListener("loadedmetadata", syncVideo);
    };
  }, [navigateToStep]);

  return (
    <div
      ref={rootRef}
      className={`${styles.root} ${fontClassName}`}
    >
      {/* ============ NAV GLASS FIXE ============ */}
      <nav
        className={styles.nav}
        aria-label="Navigation principale"
        style={{
          position: "fixed",
          top: 16,
          left: "50%",
          transform: "translateX(-50%)",
          zIndex: 60,
          display: "flex",
          alignItems: "center",
          gap: 28,
          padding: "10px 12px 10px 18px",
          borderRadius: 999,
          background: "rgba(10,14,13,0.55)",
          backdropFilter: "blur(20px) saturate(1.4)",
          WebkitBackdropFilter: "blur(20px) saturate(1.4)",
          border: "1px solid rgba(255,255,255,0.1)",
          maxWidth: "calc(100vw - 24px)",
          flexWrap: "wrap",
          justifyContent: "center",
        }}
      >
        <div
          className={styles.navBrand}
          style={{ display: "flex", alignItems: "center", gap: 9 }}
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img
            src={LOGO}
            alt="Aule"
            style={{ width: 26, height: 26, objectFit: "contain" }}
          />
          <span
            style={{ fontWeight: 600, fontSize: 16, letterSpacing: "0.01em" }}
          >
            Aule
          </span>
        </div>
        <div
          className={styles.navAudience}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 4,
            fontSize: 13.5,
            color: "rgba(255,255,255,0.65)",
          }}
        >
          <a
            href="#voyageurs"
            onClick={(event) => {
              event.preventDefault();
              navigateToStep(1, "#voyageurs");
            }}
            data-hover
            className={styles.navLink}
            style={{ padding: "7px 12px" }}
          >
            Voyageurs
          </a>
          <a
            href="#commercants"
            onClick={(event) => {
              event.preventDefault();
              navigateToStep(6, "#commercants");
            }}
            data-hover
            className={styles.navLink}
            style={{ padding: "7px 12px" }}
          >
            Commerçants
          </a>
          <a href="/pro" data-hover className={styles.navLink} style={{ padding: "7px 12px" }}>
            Aule Pro
          </a>
        </div>
        <div
          className={styles.navActions}
          style={{ display: "flex", alignItems: "center", gap: 8 }}
        >
          <a
            href="/carte-immersive"
            data-hover
            className={styles.navGhost}
            style={{ fontSize: 13.5, padding: "9px 14px" }}
          >
            Découvrir
          </a>
          <a
            href="/login"
            data-hover
            className={styles.navGhost}
            style={{ fontSize: 13.5, padding: "9px 14px" }}
          >
            Connexion
          </a>
          <a
            href="#commencer"
            data-hover
            className={styles.navPrimary}
            style={{ fontSize: 13.5, padding: "9px 18px" }}
          >
            Commencer
          </a>
        </div>
      </nav>

      {/* barre de progression du scroll */}
      <div
        style={{
          position: "fixed",
          top: 0,
          left: 0,
          right: 0,
          height: 2,
          zIndex: 61,
          background: "transparent",
        }}
      >
        <div
          ref={progressBarRef}
          style={{
            width: "0%",
            height: "100%",
            background: "linear-gradient(90deg, #17A08A, #33BFA3)",
          }}
        />
      </div>

      {/* ============ SCROLLYTELLING : container géant ============ */}
      <section
        ref={containerRef}
        style={{ position: "relative", height: `${SCROLL_HEIGHT_VH}vh` }}
      >
        <div style={{ position: "sticky", top: 0, height: "100dvh", overflow: "hidden" }}>
          <video
            ref={videoRef}
            muted
            playsInline
            preload="auto"
            style={{
              position: "absolute",
              inset: 0,
              width: "100%",
              height: "100%",
              objectFit: "cover",
            }}
          />
          {/* voiles : lisibilité + vignettage */}
          <div
            style={{
              position: "absolute",
              inset: 0,
              background: "rgba(0,0,0,0.32)",
              pointerEvents: "none",
            }}
          />
          <div
            style={{
              position: "absolute",
              inset: 0,
              background:
                "radial-gradient(ellipse 120% 90% at 50% 45%, transparent 55%, rgba(5,8,7,0.75) 100%)",
              pointerEvents: "none",
            }}
          />

          {/* ======== SECTION 1 — Hero ======== */}
          <div
            id="accueil"
            data-sec="0"
            style={{
              position: "absolute",
              inset: 0,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              textAlign: "center",
              padding: "0 24px",
              willChange: "opacity, transform, filter",
            }}
          >
            <div
              data-par="1"
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 0,
                willChange: "transform",
              }}
            >
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: 8,
                  padding: "7px 16px",
                  borderRadius: 999,
                  background: "rgba(255,255,255,0.07)",
                  backdropFilter: "blur(14px)",
                  border: "1px solid rgba(255,255,255,0.12)",
                  fontSize: 13,
                  color: "rgba(255,255,255,0.8)",
                  marginBottom: 28,
                }}
              >
                <span
                  className={styles.pulseDot}
                  style={{
                    width: 7,
                    height: 7,
                    borderRadius: "50%",
                    background: "#33BFA3",
                  }}
                />
                Cartographie collaborative en temps réel
              </div>
              <h1
                style={{
                  margin: 0,
                  fontSize: "clamp(44px, 7vw, 96px)",
                  lineHeight: 1.02,
                  fontWeight: 700,
                  letterSpacing: "-0.03em",
                  maxWidth: 1000,
                  textWrap: "balance",
                }}
              >
                Les transports,
                <br />
                enfin <span style={{ color: "#33BFA3" }}>en temps réel</span>.
              </h1>
              <p
                style={{
                  margin: "26px 0 0",
                  fontSize: "clamp(16px, 1.6vw, 20px)",
                  lineHeight: 1.55,
                  color: "rgba(255,255,255,0.75)",
                  maxWidth: 540,
                  textWrap: "pretty",
                }}
              >
                Ne subissez plus les transports. Anticipez-les grâce à une
                cartographie collaborative en temps réel.
              </p>
              <div
                style={{
                  display: "flex",
                  gap: 14,
                  marginTop: 40,
                  flexWrap: "wrap",
                  justifyContent: "center",
                }}
              >
                <a
                  href="#commencer"
                  data-hover
                  className={styles.btnPrimary}
                  style={{ fontSize: 16, padding: "15px 30px" }}
                >
                  Rejoindre Aule
                </a>
                <a
                  href="#voyageurs"
                  onClick={(event) => {
                    event.preventDefault();
                    navigateToStep(1, "#voyageurs");
                  }}
                  data-hover
                  className={styles.btnGlass}
                  style={{ fontSize: 16, padding: "15px 30px" }}
                >
                  Découvrir
                </a>
              </div>
            </div>
            {/* indicateur de scroll */}
            <div
              style={{
                position: "absolute",
                bottom: 34,
                left: "50%",
                transform: "translateX(-50%)",
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 10,
                color: "rgba(255,255,255,0.6)",
                fontSize: 12,
                letterSpacing: "0.14em",
                textTransform: "uppercase",
              }}
            >
              <span>Suivez le trajet</span>
              <svg width="18" height="26" viewBox="0 0 18 26" className={styles.scrollHint}>
                <rect
                  x="1"
                  y="1"
                  width="16"
                  height="24"
                  rx="8"
                  fill="none"
                  stroke="rgba(255,255,255,0.5)"
                  strokeWidth="1.5"
                />
                <circle cx="9" cy="8" r="2.4" fill="#33BFA3" />
              </svg>
            </div>
          </div>

          {/* ======== SECTION 2 — Voyageurs ======== */}
          <div
            id="voyageurs"
            data-sec="1"
            style={{
              opacity: 0,
              visibility: "hidden",
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              padding: "0 clamp(24px, 7vw, 120px)",
              willChange: "opacity, transform, filter",
            }}
          >
            <div
              data-layout="travelers"
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 48,
                width: "100%",
              }}
            >
              <div
                data-copy
                data-par="1"
                style={{
                  maxWidth: 430,
                  willChange: "transform",
                }}
              >
                <div style={eyebrow}>01 — Voyageurs</div>
                <h2
                  style={{
                    margin: 0,
                    fontSize: "clamp(34px, 4.2vw, 58px)",
                    lineHeight: 1.05,
                    fontWeight: 700,
                    letterSpacing: "-0.025em",
                    textWrap: "balance",
                  }}
                >
                  Tout votre trajet dans une seule application.
                </h2>
                <p
                  style={{
                    margin: "22px 0 0",
                    fontSize: 17,
                    lineHeight: 1.6,
                    color: "rgba(255,255,255,0.75)",
                    maxWidth: 410,
                    textWrap: "pretty",
                  }}
                >
                  Aule relie transport, communauté et services de proximité
                  pour vous accompagner avant, pendant et après le trajet.
                </p>
              </div>

              <div
                data-traveler-grid
                data-par="1.5"
                style={{
                  width: "min(570px, 100%)",
                  display: "grid",
                  gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
                  gap: 12,
                  willChange: "transform",
                }}
              >
                {travelerPillars.map((pillar) => (
                  <article
                    key={pillar.title}
                    data-traveler-card
                    style={{
                      minHeight: 158,
                      padding: 18,
                      borderRadius: 20,
                      background: "rgba(12,18,16,0.65)",
                      backdropFilter: "blur(24px) saturate(1.3)",
                      WebkitBackdropFilter: "blur(24px) saturate(1.3)",
                      border: "1px solid rgba(255,255,255,0.14)",
                      boxShadow: "0 24px 55px rgba(0,0,0,0.3)",
                      display: "flex",
                      flexDirection: "column",
                      alignItems: "flex-start",
                    }}
                  >
                    <div
                      style={{
                        display: "flex",
                        alignItems: "center",
                        justifyContent: "space-between",
                        gap: 8,
                        width: "100%",
                        marginBottom: 13,
                      }}
                    >
                      <span style={featureIcon}>{pillar.icon}</span>
                      {"status" in pillar && (
                        <span
                          data-upcoming-badge
                          style={{
                            padding: "5px 8px",
                            borderRadius: 999,
                            background: "rgba(51,191,163,0.12)",
                            border: "1px solid rgba(51,191,163,0.28)",
                            color: "#A9F0E4",
                            fontSize: 10.5,
                            fontWeight: 600,
                            whiteSpace: "nowrap",
                          }}
                        >
                          {pillar.status}
                        </span>
                      )}
                    </div>
                    <h3
                      style={{
                        margin: 0,
                        fontSize: 16,
                        lineHeight: 1.25,
                        fontWeight: 600,
                      }}
                    >
                      {pillar.title}
                    </h3>
                    <p
                      style={{
                        margin: "8px 0 0",
                        fontSize: 13,
                        lineHeight: 1.48,
                        color: "rgba(255,255,255,0.65)",
                      }}
                    >
                      {pillar.description}
                    </p>
                  </article>
                ))}
              </div>
            </div>
          </div>

          {/* ======== SECTION 3 — Localisez ======== */}
          <div
            id="temps-reel"
            data-sec="2"
            style={{
              opacity: 0,
              visibility: "hidden",
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              padding: "0 clamp(24px, 7vw, 120px)",
              willChange: "opacity, transform, filter",
            }}
          >
            <div
              data-layout="location"
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 48,
                width: "100%",
                flexWrap: "wrap",
              }}
            >
              <div
                data-copy
                data-par="1"
                style={{ maxWidth: 500, willChange: "transform" }}
              >
                <div style={eyebrow}>02 — Localisez</div>
                <h2
                  style={{
                    margin: 0,
                    fontSize: "clamp(34px, 4.2vw, 58px)",
                    lineHeight: 1.05,
                    fontWeight: 700,
                    letterSpacing: "-0.025em",
                    textWrap: "balance",
                  }}
                >
                  Voyez réellement où se trouve votre véhicule.
                </h2>
                <p
                  style={{
                    margin: "22px 0 0",
                    fontSize: 17,
                    lineHeight: 1.6,
                    color: "rgba(255,255,255,0.75)",
                    maxWidth: 430,
                    textWrap: "pretty",
                  }}
                >
                  Visualisez votre bus ou votre tram en temps réel, suivez son
                  déplacement et estimez précisément son heure d&apos;arrivée.
                </p>
                <div style={{ display: "flex", flexDirection: "column", gap: 2, marginTop: 30 }}>
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 14,
                      padding: "13px 0",
                      borderTop: "1px solid rgba(255,255,255,0.09)",
                    }}
                  >
                    <span style={featureIcon}>📍</span>
                    <span style={{ fontSize: 15, color: "rgba(255,255,255,0.9)" }}>
                      Position GPS rafraîchie toutes les secondes
                    </span>
                  </div>
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 14,
                      padding: "13px 0",
                      borderTop: "1px solid rgba(255,255,255,0.09)",
                    }}
                  >
                    <span style={featureIcon}>⏱</span>
                    <span style={{ fontSize: 15, color: "rgba(255,255,255,0.9)" }}>
                      ETA recalculée en continu selon le trafic réel
                    </span>
                  </div>
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: 14,
                      padding: "13px 0",
                      borderTop: "1px solid rgba(255,255,255,0.09)",
                      borderBottom: "1px solid rgba(255,255,255,0.09)",
                    }}
                  >
                    <span style={featureIcon}>🚌</span>
                    <span style={{ fontSize: 15, color: "rgba(255,255,255,0.9)" }}>
                      Tous les bus, trams et métros de votre réseau
                    </span>
                  </div>
                </div>
                <div style={{ display: "flex", gap: 34, marginTop: 26 }}>
                  <div>
                    <div
                      style={{
                        fontSize: 28,
                        fontWeight: 700,
                        color: "#33BFA3",
                        letterSpacing: "-0.02em",
                      }}
                    >
                      ±30 s
                    </div>
                    <div style={{ fontSize: 13, color: "rgba(255,255,255,0.55)" }}>
                      précision d&apos;arrivée
                    </div>
                  </div>
                  <div>
                    <div
                      style={{
                        fontSize: 28,
                        fontWeight: 700,
                        color: "#33BFA3",
                        letterSpacing: "-0.02em",
                      }}
                    >
                      100 %
                    </div>
                    <div style={{ fontSize: 13, color: "rgba(255,255,255,0.55)" }}>
                      du réseau couvert
                    </div>
                  </div>
                </div>
              </div>
              {/* phone : carte + véhicule + ETA */}
              <div
                data-panel="phone"
                data-par="1.6"
                style={{
                  width: 290,
                  flex: "none",
                  borderRadius: 34,
                  background: "rgba(12,18,16,0.6)",
                  backdropFilter: "blur(24px) saturate(1.3)",
                  border: "1px solid rgba(255,255,255,0.14)",
                  padding: 12,
                  boxShadow: "0 40px 80px rgba(0,0,0,0.5)",
                  willChange: "transform",
                }}
              >
                <div style={{ borderRadius: 24, overflow: "hidden", background: "#0B100F" }}>
                  <div
                    style={{
                      position: "relative",
                      height: 330,
                      background: "linear-gradient(160deg, #0E1614, #0A1210)",
                    }}
                  >
                    <svg
                      viewBox="0 0 290 330"
                      style={{ position: "absolute", inset: 0, width: "100%", height: "100%" }}
                    >
                      <path
                        d="M-10 240 L70 235 L120 200 L150 140 L210 110 L300 90"
                        fill="none"
                        stroke="rgba(255,255,255,0.08)"
                        strokeWidth="22"
                        strokeLinecap="round"
                      />
                      <path
                        d="M-10 280 L90 285 L180 250 L300 245"
                        fill="none"
                        stroke="rgba(255,255,255,0.06)"
                        strokeWidth="14"
                        strokeLinecap="round"
                      />
                      <path
                        className={styles.dashPath}
                        d="M-10 240 L70 235 L120 200 L150 140 L210 110 L300 90"
                        fill="none"
                        stroke="#17A08A"
                        strokeWidth="4"
                        strokeDasharray="10 10"
                      />
                      <circle className={styles.pulseDot} cx="150" cy="140" r="7" fill="#33BFA3" />
                      <circle cx="250" cy="98" r="6" fill="#fff" opacity="0.9" />
                    </svg>
                    <div
                      style={{
                        position: "absolute",
                        left: 14,
                        top: 14,
                        display: "flex",
                        alignItems: "center",
                        gap: 8,
                        padding: "8px 12px",
                        borderRadius: 12,
                        background: "rgba(10,14,13,0.75)",
                        backdropFilter: "blur(12px)",
                        border: "1px solid rgba(255,255,255,0.1)",
                        fontSize: 12.5,
                      }}
                    >
                      <span
                        style={{
                          display: "inline-flex",
                          alignItems: "center",
                          justifyContent: "center",
                          width: 22,
                          height: 22,
                          borderRadius: 7,
                          background: "#17A08A",
                          fontWeight: 700,
                          fontSize: 11,
                          color: "#04211c",
                        }}
                      >
                        T3
                      </span>
                      Tram T3 · direction Gare
                    </div>
                  </div>
                  <div
                    style={{
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "space-between",
                      padding: "14px 16px",
                      borderTop: "1px solid rgba(255,255,255,0.07)",
                    }}
                  >
                    <div>
                      <div style={{ fontSize: 12, color: "rgba(255,255,255,0.55)" }}>
                        Arrivée à votre arrêt
                      </div>
                      <div style={{ fontSize: 21, fontWeight: 700, color: "#33BFA3" }}>
                        4 min
                      </div>
                    </div>
                    <div
                      style={{
                        fontSize: 12,
                        color: "rgba(255,255,255,0.55)",
                        textAlign: "right",
                      }}
                    >
                      Suivi en direct
                      <br />
                      <span style={{ color: "#fff" }}>Quai B · Hôtel de Ville</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* ======== SECTION 4 — Montez au bon moment ======== */}
          <div
            id="notifications"
            data-sec="3"
            style={{
              opacity: 0,
              visibility: "hidden",
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              padding: "0 clamp(24px, 7vw, 120px)",
              willChange: "opacity, transform, filter",
            }}
          >
            <div
              data-layout="notification"
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 48,
                width: "100%",
                flexWrap: "wrap-reverse",
              }}
            >
              <div
                data-panel="notification"
                data-par="1.6"
                style={{
                  width: 340,
                  flex: "none",
                  display: "flex",
                  flexDirection: "column",
                  gap: 14,
                  willChange: "transform",
                }}
              >
                <div
                  style={{
                    borderRadius: 20,
                    background: "rgba(12,18,16,0.65)",
                    backdropFilter: "blur(24px) saturate(1.3)",
                    border: "1px solid rgba(255,255,255,0.14)",
                    padding: "16px 18px",
                    boxShadow: "0 30px 60px rgba(0,0,0,0.45)",
                    display: "flex",
                    gap: 13,
                    alignItems: "flex-start",
                  }}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={LOGO}
                    alt=""
                    style={{
                      width: 34,
                      height: 34,
                      objectFit: "contain",
                      borderRadius: 9,
                      background: "rgba(255,255,255,0.06)",
                      padding: 3,
                    }}
                  />
                  <div style={{ flex: 1 }}>
                    <div
                      style={{
                        display: "flex",
                        justifyContent: "space-between",
                        fontSize: 12,
                        color: "rgba(255,255,255,0.5)",
                        marginBottom: 3,
                      }}
                    >
                      <span style={{ fontWeight: 600, color: "rgba(255,255,255,0.85)" }}>
                        Aule
                      </span>
                      <span>maintenant</span>
                    </div>
                    <div style={{ fontSize: 14.5, fontWeight: 600 }}>
                      Votre tram T3 arrive 🚋
                    </div>
                    <div
                      style={{
                        fontSize: 13.5,
                        color: "rgba(255,255,255,0.65)",
                        lineHeight: 1.45,
                      }}
                    >
                      À 2 minutes de l&apos;arrêt Hôtel de Ville. Dirigez-vous
                      vers le quai B.
                    </div>
                  </div>
                </div>
                <div
                  style={{
                    display: "flex",
                    alignItems: "center",
                    gap: 10,
                    padding: "12px 16px",
                    borderRadius: 16,
                    background: "rgba(51,191,163,0.1)",
                    border: "1px solid rgba(51,191,163,0.25)",
                    fontSize: 13.5,
                    color: "#A9F0E4",
                  }}
                >
                  <span
                    className={styles.pulseDot}
                    style={{ width: 8, height: 8, borderRadius: "50%", background: "#33BFA3" }}
                  />
                  Portes ouvertes · montez maintenant
                </div>
              </div>
              <div
                data-copy
                data-par="1"
                style={{ maxWidth: 480, willChange: "transform" }}
              >
                <div style={eyebrow}>03 — Montez au bon moment</div>
                <h2
                  style={{
                    margin: 0,
                    fontSize: "clamp(34px, 4.2vw, 58px)",
                    lineHeight: 1.05,
                    fontWeight: 700,
                    letterSpacing: "-0.025em",
                    textWrap: "balance",
                  }}
                >
                  Ne courez plus après votre tram.
                </h2>
                <p
                  style={{
                    margin: "22px 0 0",
                    fontSize: 17,
                    lineHeight: 1.6,
                    color: "rgba(255,255,255,0.75)",
                    maxWidth: 420,
                    textWrap: "pretty",
                  }}
                >
                  Recevez une notification lorsque votre véhicule approche de
                  votre arrêt.
                </p>
              </div>
            </div>
          </div>

          {/* ======== SECTION 5 — Voyagez sereinement ======== */}
          <div
            id="trajet"
            data-sec="4"
            style={{
              opacity: 0,
              visibility: "hidden",
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              padding: "0 clamp(24px, 7vw, 120px)",
              willChange: "opacity, transform, filter",
            }}
          >
            <div
              data-layout="trip"
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 48,
                width: "100%",
                flexWrap: "wrap",
              }}
            >
              <div
                data-copy
                data-par="1"
                style={{ maxWidth: 460, willChange: "transform" }}
              >
                <div style={eyebrow}>04 — Voyagez sereinement</div>
                <h2
                  style={{
                    margin: 0,
                    fontSize: "clamp(34px, 4.2vw, 58px)",
                    lineHeight: 1.05,
                    fontWeight: 700,
                    letterSpacing: "-0.025em",
                    textWrap: "balance",
                  }}
                >
                  Toutes les informations utiles pendant votre trajet.
                </h2>
              </div>
              {/* panneau trajet */}
              <div
                data-panel="trip"
                data-par="1.6"
                style={{
                  width: 330,
                  flex: "none",
                  borderRadius: 24,
                  background: "rgba(12,18,16,0.65)",
                  backdropFilter: "blur(24px) saturate(1.3)",
                  border: "1px solid rgba(255,255,255,0.14)",
                  padding: 20,
                  boxShadow: "0 30px 60px rgba(0,0,0,0.45)",
                  willChange: "transform",
                }}
              >
                <div
                  style={{
                    display: "flex",
                    justifyContent: "space-between",
                    alignItems: "baseline",
                    marginBottom: 16,
                  }}
                >
                  <div style={{ fontWeight: 600, fontSize: 15 }}>Tram T3 → Gare</div>
                  <div style={{ fontSize: 13, color: "#33BFA3", fontWeight: 600 }}>
                    12 min restantes
                  </div>
                </div>
                <div style={{ display: "flex", flexDirection: "column", gap: 0 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "9px 0" }}>
                    <span
                      style={{
                        width: 10,
                        height: 10,
                        borderRadius: "50%",
                        background: "#33BFA3",
                        flex: "none",
                      }}
                    />
                    <span style={{ fontSize: 14, color: "rgba(255,255,255,0.9)" }}>
                      Hôtel de Ville
                    </span>
                    <span
                      style={{
                        marginLeft: "auto",
                        fontSize: 12,
                        color: "rgba(255,255,255,0.45)",
                      }}
                    >
                      à bord
                    </span>
                  </div>
                  <div
                    style={{
                      width: 1.5,
                      height: 14,
                      background: "rgba(255,255,255,0.15)",
                      marginLeft: 4,
                    }}
                  />
                  <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "9px 0" }}>
                    <span
                      style={{
                        width: 10,
                        height: 10,
                        borderRadius: "50%",
                        border: "2px solid rgba(255,255,255,0.35)",
                        boxSizing: "border-box",
                        flex: "none",
                      }}
                    />
                    <span style={{ fontSize: 14, color: "rgba(255,255,255,0.75)" }}>
                      Place Carnot
                    </span>
                    <span
                      style={{
                        marginLeft: "auto",
                        fontSize: 12,
                        color: "rgba(255,255,255,0.45)",
                      }}
                    >
                      3 min
                    </span>
                  </div>
                  <div
                    style={{
                      width: 1.5,
                      height: 14,
                      background: "rgba(255,255,255,0.15)",
                      marginLeft: 4,
                    }}
                  />
                  <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "9px 0" }}>
                    <span
                      style={{
                        width: 10,
                        height: 10,
                        borderRadius: "50%",
                        border: "2px solid rgba(255,255,255,0.35)",
                        boxSizing: "border-box",
                        flex: "none",
                      }}
                    />
                    <span style={{ fontSize: 14, color: "rgba(255,255,255,0.75)" }}>
                      Gare centrale
                    </span>
                    <span
                      style={{
                        marginLeft: "auto",
                        fontSize: 12,
                        color: "rgba(255,255,255,0.45)",
                      }}
                    >
                      12 min
                    </span>
                  </div>
                </div>
                <div style={{ display: "flex", gap: 8, marginTop: 16, flexWrap: "wrap" }}>
                  <span
                    style={{
                      fontSize: 12.5,
                      padding: "6px 11px",
                      borderRadius: 999,
                      background: "rgba(255,183,77,0.12)",
                      border: "1px solid rgba(255,183,77,0.3)",
                      color: "#FFD9A0",
                    }}
                  >
                    ⚠ Ralentissement ligne B
                  </span>
                  <span
                    style={{
                      fontSize: 12.5,
                      padding: "6px 11px",
                      borderRadius: 999,
                      background: "rgba(255,255,255,0.07)",
                      border: "1px solid rgba(255,255,255,0.12)",
                      color: "rgba(255,255,255,0.75)",
                    }}
                  >
                    Correspondance M1 · quai 2
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* ======== SECTION 6 — Communauté ======== */}
          <div
            id="communaute"
            data-sec="5"
            style={{
              opacity: 0,
              visibility: "hidden",
              position: "absolute",
              inset: 0,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              textAlign: "center",
              padding: "0 24px",
              willChange: "opacity, transform, filter",
            }}
          >
            <div data-par="1" style={{ maxWidth: 720, willChange: "transform" }}>
              <div style={eyebrow}>05 — La communauté</div>
              <h2
                style={{
                  margin: 0,
                  fontSize: "clamp(34px, 4.5vw, 62px)",
                  lineHeight: 1.05,
                  fontWeight: 700,
                  letterSpacing: "-0.025em",
                  textWrap: "balance",
                }}
              >
                Des informations enrichies par toute la communauté.
              </h2>
              <p
                style={{
                  margin: "22px auto 0",
                  fontSize: 17,
                  lineHeight: 1.6,
                  color: "rgba(255,255,255,0.75)",
                  maxWidth: 480,
                  textWrap: "pretty",
                }}
              >
                Deux façons de contribuer, toujours sous votre contrôle, pour
                rendre le réseau plus précis pour tout le monde.
              </p>
            </div>
            <div
              data-community-modes
              data-par="1.5"
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(2, minmax(0, 1fr))",
                gap: 12,
                marginTop: 34,
                width: "min(820px, 100%)",
                willChange: "transform",
              }}
            >
              <article
                data-community-mode
                style={{
                  padding: 20,
                  borderRadius: 20,
                  background: "rgba(51,191,163,0.12)",
                  border: "1px solid rgba(51,191,163,0.3)",
                  textAlign: "left",
                  backdropFilter: "blur(20px)",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                  <span style={featureIcon}>📡</span>
                  <div>
                    <div style={{ fontSize: 15.5, fontWeight: 600 }}>
                      Contribution automatique
                    </div>
                    <div
                      style={{
                        marginTop: 2,
                        fontSize: 11.5,
                        color: "#A9F0E4",
                        textTransform: "uppercase",
                        letterSpacing: "0.08em",
                      }}
                    >
                      Avec votre accord
                    </div>
                  </div>
                </div>
                <p
                  style={{
                    margin: "14px 0 0",
                    fontSize: 13.5,
                    lineHeight: 1.5,
                    color: "rgba(255,255,255,0.72)",
                  }}
                >
                  Une position GPS anonymisée aide à confirmer le passage et la
                  progression des véhicules.
                </p>
              </article>

              <article
                data-community-mode
                style={{
                  padding: 20,
                  borderRadius: 20,
                  background: "rgba(12,18,16,0.65)",
                  border: "1px solid rgba(255,255,255,0.14)",
                  textAlign: "left",
                  backdropFilter: "blur(20px)",
                }}
              >
                <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
                  <span style={featureIcon}>🙋</span>
                  <div style={{ fontSize: 15.5, fontWeight: 600 }}>
                    Signalements volontaires
                  </div>
                </div>
                <p
                  style={{
                    margin: "14px 0 12px",
                    fontSize: 13.5,
                    lineHeight: 1.5,
                    color: "rgba(255,255,255,0.72)",
                  }}
                >
                  Partagez ce que vous observez pour informer immédiatement les
                  autres voyageurs.
                </p>
                <div
                  data-community-chips
                  style={{
                    display: "flex",
                    gap: 6,
                    flexWrap: "wrap",
                  }}
                >
                  <span style={{ ...chip, padding: "6px 9px", fontSize: 11.5 }}>
                    🚧 Incident
                  </span>
                  <span style={{ ...chip, padding: "6px 9px", fontSize: 11.5 }}>
                    ⏱ Retard
                  </span>
                  <span style={{ ...chip, padding: "6px 9px", fontSize: 11.5 }}>
                    👥 Affluence
                  </span>
                </div>
              </article>
            </div>
          </div>

          {/* ======== SECTION 7 — Services ======== */}
          <div
            id="commercants"
            data-sec="6"
            style={{
              opacity: 0,
              visibility: "hidden",
              position: "absolute",
              inset: 0,
              display: "flex",
              alignItems: "center",
              padding: "0 clamp(24px, 7vw, 120px)",
              willChange: "opacity, transform, filter",
            }}
          >
            <div
              data-layout="commerce"
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                gap: 48,
                width: "100%",
                flexWrap: "wrap",
              }}
            >
              <div
                data-copy
                data-par="1"
                style={{ maxWidth: 470, willChange: "transform" }}
              >
                <div style={eyebrow}>06 — Bientôt disponible</div>
                <h2
                  style={{
                    margin: 0,
                    fontSize: "clamp(34px, 4.2vw, 58px)",
                    lineHeight: 1.05,
                    fontWeight: 700,
                    letterSpacing: "-0.025em",
                    textWrap: "balance",
                  }}
                >
                  Réservez et commandez, sans interrompre votre trajet.
                </h2>
                <p
                  style={{
                    margin: "22px 0 0",
                    fontSize: 17,
                    lineHeight: 1.6,
                    color: "rgba(255,255,255,0.75)",
                    maxWidth: 430,
                    textWrap: "pretty",
                  }}
                >
                  Préparez le premier ou le dernier kilomètre et retrouvez vos
                  commandes à l’arrivée. Aule ajuste le rendez-vous à votre ETA.
                </p>
              </div>
              {/* aperçus des futurs services */}
              <div
                data-panel="commerce"
                data-par="1.6"
                style={{
                  width: 380,
                  flex: "none",
                  display: "flex",
                  flexDirection: "column",
                  gap: 12,
                  willChange: "transform",
                }}
              >
                <div
                  data-service-card
                  style={{
                    borderRadius: 20,
                    background: "rgba(12,18,16,0.65)",
                    backdropFilter: "blur(24px) saturate(1.3)",
                    border: "1px solid rgba(255,255,255,0.14)",
                    padding: "16px 18px",
                    boxShadow: "0 30px 60px rgba(0,0,0,0.45)",
                  }}
                >
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      marginBottom: 12,
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <span style={featureIcon}>🚕</span>
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 14.5 }}>
                          VTC &amp; taxis
                        </div>
                        <div
                          style={{
                            marginTop: 2,
                            fontSize: 11.5,
                            color: "rgba(255,255,255,0.5)",
                          }}
                        >
                          Premier et dernier kilomètre
                        </div>
                      </div>
                    </div>
                    <span
                      data-upcoming-badge
                      style={{
                        padding: "5px 8px",
                        borderRadius: 999,
                        background: "rgba(51,191,163,0.12)",
                        border: "1px solid rgba(51,191,163,0.28)",
                        color: "#A9F0E4",
                        fontSize: 10.5,
                        fontWeight: 600,
                        whiteSpace: "nowrap",
                      }}
                    >
                      Bientôt disponible
                    </span>
                  </div>
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      fontSize: 13.5,
                      color: "rgba(255,255,255,0.75)",
                      padding: "6px 0",
                      borderTop: "1px solid rgba(255,255,255,0.07)",
                    }}
                  >
                    <span>Prise en charge · Gare Nord</span>
                    <span style={{ color: "#33BFA3", fontWeight: 600 }}>
                      ETA 12 min
                    </span>
                  </div>
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      fontSize: 13.5,
                      color: "rgba(255,255,255,0.75)",
                      padding: "6px 0",
                      borderTop: "1px solid rgba(255,255,255,0.07)",
                    }}
                  >
                    <span>Horaire ajusté à l’arrivée réelle</span>
                    <span style={{ color: "#33BFA3" }}>↻</span>
                  </div>
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      fontSize: 14,
                      fontWeight: 600,
                      paddingTop: 10,
                      borderTop: "1px solid rgba(255,255,255,0.12)",
                      marginTop: 4,
                    }}
                  >
                    <span>Réservation intégrée</span>
                    <span style={{ color: "#33BFA3" }}>Bientôt</span>
                  </div>
                </div>
                <div
                  data-service-card
                  style={{
                    borderRadius: 20,
                    background: "rgba(12,18,16,0.65)",
                    backdropFilter: "blur(24px) saturate(1.3)",
                    border: "1px solid rgba(255,255,255,0.14)",
                    padding: "16px 18px",
                    boxShadow: "0 30px 60px rgba(0,0,0,0.45)",
                  }}
                >
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      gap: 10,
                      marginBottom: 12,
                    }}
                  >
                    <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                      <span style={featureIcon}>🛍️</span>
                      <div>
                        <div style={{ fontWeight: 600, fontSize: 14.5 }}>
                          Commerçants
                        </div>
                        <div
                          style={{
                            marginTop: 2,
                            fontSize: 11.5,
                            color: "rgba(255,255,255,0.5)",
                          }}
                        >
                          Repas, courses et achats
                        </div>
                      </div>
                    </div>
                    <span
                      data-upcoming-badge
                      style={{
                        padding: "5px 8px",
                        borderRadius: 999,
                        background: "rgba(51,191,163,0.12)",
                        border: "1px solid rgba(51,191,163,0.28)",
                        color: "#A9F0E4",
                        fontSize: 10.5,
                        fontWeight: 600,
                        whiteSpace: "nowrap",
                      }}
                    >
                      Bientôt disponible
                    </span>
                  </div>
                  <p
                    style={{
                      margin: 0,
                      fontSize: 13.5,
                      lineHeight: 1.5,
                      color: "rgba(255,255,255,0.75)",
                    }}
                  >
                    Commandez pendant le trajet et choisissez le retrait ou la
                    remise à proximité de votre arrêt.
                  </p>
                  <div
                    style={{
                      display: "flex",
                      justifyContent: "space-between",
                      alignItems: "center",
                      marginTop: 13,
                      paddingTop: 11,
                      borderTop: "1px solid rgba(255,255,255,0.08)",
                      fontSize: 12.5,
                      color: "rgba(255,255,255,0.58)",
                    }}
                  >
                    <span>Retrait · Quai B</span>
                    <span style={{ color: "#33BFA3", fontWeight: 600 }}>
                      Prêt à l’arrivée
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* ======== SECTION 8 — Aule Pro ======== */}
          <div
            id="aule-pro"
            data-sec="7"
            style={{
              opacity: 0,
              visibility: "hidden",
              position: "absolute",
              inset: 0,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              textAlign: "center",
              padding: "0 24px",
              willChange: "opacity, transform, filter",
            }}
          >
            <div data-par="1" style={{ maxWidth: 760, willChange: "transform" }}>
              <div style={eyebrow}>07 — Aule Pro</div>
              <h2
                style={{
                  margin: 0,
                  fontSize: "clamp(34px, 4.5vw, 62px)",
                  lineHeight: 1.05,
                  fontWeight: 700,
                  letterSpacing: "-0.025em",
                  textWrap: "balance",
                }}
              >
                Pensée aussi pour ceux qui font vivre le réseau.
              </h2>
              <p
                style={{
                  margin: "22px auto 0",
                  fontSize: 17,
                  lineHeight: 1.6,
                  color: "rgba(255,255,255,0.75)",
                  maxWidth: 520,
                  textWrap: "pretty",
                }}
              >
                Conducteurs, contrôleurs, agents d&apos;intervention,
                superviseurs — leurs informations terrain améliorent aussi votre
                trajet.
              </p>
            </div>
            <div
              data-par="1.5"
              style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fit, minmax(150px, 1fr))",
                gap: 10,
                marginTop: 40,
                width: "min(720px, 100%)",
                willChange: "transform",
              }}
            >
              <div style={proTag}>Prise de service</div>
              <div style={proTag}>Missions &amp; équipes</div>
              <div style={proTag}>Géolocalisation véhicule</div>
              <div style={proTag}>Messagerie terrain</div>
              <div style={proTag}>Contrôle &amp; intervention</div>
              <div style={proTag}>Échanges de services</div>
            </div>
          </div>

          {/* ======== SECTION 9 — Réseau vivant ======== */}
          <div
            id="reseau-vivant"
            data-sec="8"
            style={{
              opacity: 0,
              visibility: "hidden",
              position: "absolute",
              inset: 0,
              display: "flex",
              flexDirection: "column",
              alignItems: "center",
              justifyContent: "center",
              textAlign: "center",
              padding: "0 24px",
              willChange: "opacity, transform, filter",
            }}
          >
            <div data-par="1" style={{ maxWidth: 860, willChange: "transform" }}>
              <div style={eyebrow}>08 — Un réseau vivant</div>
              <h2
                style={{
                  margin: 0,
                  fontSize: "clamp(40px, 6vw, 84px)",
                  lineHeight: 1.02,
                  fontWeight: 700,
                  letterSpacing: "-0.03em",
                  textWrap: "balance",
                }}
              >
                Chaque trajet améliore <span style={{ color: "#33BFA3" }}>le suivant</span>.
              </h2>
              <p
                style={{
                  margin: "26px auto 0",
                  fontSize: "clamp(16px, 1.6vw, 19px)",
                  lineHeight: 1.6,
                  color: "rgba(255,255,255,0.75)",
                  maxWidth: 560,
                  textWrap: "pretty",
                }}
              >
                Grâce à la communauté et aux professionnels, Aule construit la
                vision la plus précise du réseau de transport.
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* ============ FOOTER CTA ============ */}
      <footer
        id="commencer"
        className={styles.downloadFooter}
        style={{
          position: "relative",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          textAlign: "center",
          padding: "140px 24px 60px",
          background: "linear-gradient(180deg, #050807, #071110)",
        }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={LOGO}
          alt="Aule"
          style={{ width: 76, height: 76, objectFit: "contain" }}
        />
        <h2
          style={{
            margin: "28px 0 0",
            fontSize: "clamp(32px, 4.5vw, 60px)",
            fontWeight: 700,
            letterSpacing: "-0.025em",
            lineHeight: 1.05,
            textWrap: "balance",
          }}
        >
          Les transports, enfin en temps réel.
        </h2>
        <div
          className={styles.storeActions}
          style={{
            display: "flex",
            gap: 14,
            marginTop: 38,
            flexWrap: "wrap",
            justifyContent: "center",
          }}
        >
          <a
            href="/signup"
            data-hover
            className={styles.btnPrimary}
            style={{ fontSize: 16, padding: "15px 30px" }}
          >
            Créer mon compte gratuitement
          </a>
          <a
            href="/login"
            data-hover
            className={styles.btnGlass}
            style={{ fontSize: 16, padding: "15px 30px" }}
          >
            J&apos;ai déjà un compte
          </a>
          <a
            href="/pro"
            data-hover
            className={styles.btnGlass}
            style={{ fontSize: 16, padding: "15px 30px" }}
          >
            Découvrir Aule Pro
          </a>
        </div>
      </footer>

      {/* ============ FOOTER (liens) ============ */}
      <footer
        className={styles.linkFooter}
        style={{
          background: "#071110",
          borderTop: "1px solid rgba(255,255,255,0.07)",
          padding: "72px clamp(24px, 7vw, 120px) 40px",
        }}
      >
        <div
          className={styles.footerGrid}
          style={{
            maxWidth: 1160,
            margin: "0 auto",
            display: "grid",
            gridTemplateColumns: "1.4fr repeat(3, 1fr)",
            gap: "48px 32px",
          }}
        >
          <div style={{ minWidth: 200 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 9, marginBottom: 16 }}>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={LOGO}
                alt="Aule"
                style={{ width: 30, height: 30, objectFit: "contain" }}
              />
              <span style={{ fontWeight: 600, fontSize: 18 }}>Aule</span>
            </div>
            <p
              style={{
                margin: "0 0 20px",
                fontSize: 14,
                lineHeight: 1.6,
                color: "rgba(255,255,255,0.5)",
                maxWidth: 280,
              }}
            >
              La plateforme qui connecte voyageurs, professionnels du transport
              et commerçants de proximité.
            </p>
          </div>
          <div>
            <div style={footerColTitle}>Produit</div>
            <div style={footerColList}>
              <a href="#voyageurs" onClick={(event) => {
                event.preventDefault();
                navigateToStep(1, "#voyageurs");
              }} data-hover className={styles.footerLink}>Voyageurs</a>
              <a href="#temps-reel" onClick={(event) => {
                event.preventDefault();
                navigateToStep(2, "#temps-reel");
              }} data-hover className={styles.footerLink}>Temps réel</a>
              <a href="#notifications" onClick={(event) => {
                event.preventDefault();
                navigateToStep(3, "#notifications");
              }} data-hover className={styles.footerLink}>Notifications</a>
              <a href="#commercants" onClick={(event) => {
                event.preventDefault();
                navigateToStep(6, "#commercants");
              }} data-hover className={styles.footerLink}>Services à l’arrivée</a>
              <a href="#communaute" onClick={(event) => {
                event.preventDefault();
                navigateToStep(5, "#communaute");
              }} data-hover className={styles.footerLink}>Communauté</a>
            </div>
          </div>
          <div>
            <div style={footerColTitle}>Écosystème</div>
            <div style={footerColList}>
              <a href="/pro" data-hover className={styles.footerLink}>Aule Pro</a>
              <a href="/pro" data-hover className={styles.footerLink}>Opérateurs</a>
              <a href="#commercants" onClick={(event) => {
                event.preventDefault();
                navigateToStep(6, "#commercants");
              }} data-hover className={styles.footerLink}>Commerçants</a>
              <a href="/login" data-hover className={styles.footerLink}>Espace Pro</a>
            </div>
          </div>
          <div>
            <div style={footerColTitle}>Accès</div>
            <div style={footerColList}>
              <a href="#commencer" data-hover className={styles.footerLink}>Rejoindre Aule</a>
              <a href="/login" data-hover className={styles.footerLink}>Connexion</a>
              <a href="/signup" data-hover className={styles.footerLink}>Créer un compte</a>
              <a href="/pro" data-hover className={styles.footerLink}>Découvrir la plateforme</a>
            </div>
          </div>
        </div>
        <div
          style={{
            maxWidth: 1160,
            margin: "56px auto 0",
            paddingTop: 24,
            borderTop: "1px solid rgba(255,255,255,0.07)",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            gap: 20,
            flexWrap: "wrap",
          }}
        >
          <div style={{ fontSize: 13, color: "rgba(255,255,255,0.4)" }}>
            © 2026 Aule — voyageurs, professionnels et commerçants, connectés.
          </div>
        </div>
      </footer>

    </div>
  );
}
