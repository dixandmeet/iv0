"use client";

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type FormEvent,
} from "react";
import {
  Apple,
  ArrowUp,
  Bell,
  CarFront,
  CircleCheck,
  Map as MapIcon,
  Play,
  RadioTower,
  ShoppingBag,
  Smartphone,
  Users,
} from "lucide-react";
import Link from "next/link";
import { reverseGeocodeLocation } from "@/lib/geocode";
import { EnvironmentSectionMap, HeroInteractiveMap } from "./hero-phone-map";
import {
  AddressSuggestions,
  useAddressAutocomplete,
} from "./use-address-autocomplete";
import { useHeroWeather } from "./use-hero-weather";
import shared from "./scrolly-landing.module.css";
import styles from "./landing-classic.module.css";

const GEOLOCATION_CONSENT_KEY = "aule-landing-geolocation-consent";
const LOGO = "/uploads/logo-1783189856190.png";

const FOOTER_PRODUCT_LINKS = [
  { label: "Carte interactive", href: "/carte-immersive" },
  { label: "Fonctionnalités", href: "#fonctionnalites" },
  { label: "Services", href: "#services" },
  { label: "Vision", href: "#vision" },
  { label: "Télécharger", href: "#download" },
] as const;

const FOOTER_PRO_LINKS = [
  { label: "Découvrir le SAEIV", href: "/pro" },
  { label: "Fonctionnalités", href: "/pro#fonctionnalites" },
  { label: "Déploiement", href: "/pro#deploiement" },
  { label: "Connexion au dashboard", href: "/login" },
] as const;

const FOOTER_SUPPORT_LINKS = [
  { label: "Centre d'aide", href: "/aide" },
  { label: "Contact", href: "/contact" },
  { label: "Confidentialité", href: "/confidentialite" },
  { label: "Conditions", href: "/conditions" },
  { label: "Cookies", href: "/cookies" },
] as const;

const BENEFITS = [
  { Icon: Smartphone, title: "Une seule application", text: "Pour tous vos déplacements, sans jongler entre les apps." },
  { Icon: RadioTower, title: "Information enrichie", text: "Une information voyageur plus riche et plus fiable." },
  { Icon: MapIcon, title: "Carte temps réel", text: "Une carte interactive qui réunit toutes vos mobilités." },
  { Icon: Bell, title: "Notifications intelligentes", text: "Averti au bon moment, avant l'arrivée et la descente." },
  { Icon: Users, title: "Communauté progressive", text: "Signalements communautaires disponibles selon les réseaux." },
  { Icon: ShoppingBag, title: "Commerces · prochainement", text: "Commande et livraison font partie de la feuille de route." },
  { Icon: CarFront, title: "VTC & taxis · prochainement", text: "La réservation de courses n'est pas encore disponible." },
  { Icon: CircleCheck, title: "Pensée pour simplifier", text: "Une expérience conçue pour simplifier chaque déplacement." },
] as const;

type GeolocationConsent = "pending" | "accepted" | "declined";
type GeolocationStatus = "idle" | "locating" | "located" | "denied" | "unavailable" | "error";
type UserLocation = { lng: number; lat: number };

const panelStyle: CSSProperties = {
  border: "1px solid rgba(255,255,255,0.14)",
  background: "rgba(12,18,16,0.65)",
  backdropFilter: "blur(24px) saturate(1.3)",
  WebkitBackdropFilter: "blur(24px) saturate(1.3)",
  boxShadow: "0 30px 60px rgba(0,0,0,0.45)",
};

/** Révèle l'élément à l'entrée dans le viewport (fade + translateY). */
function Reveal({
  children,
  className,
  as: Tag = "div",
  delay = 0,
  id,
}: {
  children: React.ReactNode;
  className?: string;
  as?: "div" | "section" | "article";
  delay?: number;
  id?: string;
}) {
  const ref = useRef<HTMLElement | null>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const node = ref.current;
    if (!node) return undefined;

    // prefers-reduced-motion est géré en CSS (.reveal force alors la visibilité).
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setVisible(true);
            observer.disconnect();
          }
        });
      },
      { threshold: 0.16, rootMargin: "0px 0px -8% 0px" },
    );

    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  return (
    <Tag
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ref={ref as any}
      id={id}
      className={`${styles.reveal} ${className ?? ""}`}
      data-visible={visible ? "true" : "false"}
      style={delay ? ({ transitionDelay: `${delay}ms` } as CSSProperties) : undefined}
    >
      {children}
    </Tag>
  );
}

export function LandingClassic({ fontClassName = "" }: { fontClassName?: string }) {
  const progressBarRef = useRef<HTMLDivElement>(null);
  const originUsesCurrentLocationRef = useRef(true);
  const [geoConsent, setGeoConsent] = useState<GeolocationConsent>("pending");
  const [consentReady, setConsentReady] = useState(false);
  const [geoStatus, setGeoStatus] = useState<GeolocationStatus>("idle");
  const [userLocation, setUserLocation] = useState<UserLocation | undefined>();
  const [originUsesCurrentLocation, setOriginUsesCurrentLocation] = useState(true);
  const [showBackToTop, setShowBackToTop] = useState(false);

  const markOriginAsCustom = useCallback(() => {
    originUsesCurrentLocationRef.current = false;
    setOriginUsesCurrentLocation(false);
  }, []);

  const originAddress = useAddressAutocomplete({
    initialQuery: "38 Rue de l'Ouche Buron, 44300 Nantes",
    onUserInput: markOriginAsCustom,
  });
  const destinationAddress = useAddressAutocomplete();
  const setOriginAddressValue = originAddress.setValue;

  const requestGeolocation = useCallback(() => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      setGeoStatus("unavailable");
      return;
    }

    setGeoStatus("locating");
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const location = {
          lng: position.coords.longitude,
          lat: position.coords.latitude,
        };

        setUserLocation(location);
        setGeoStatus("located");

        if (originUsesCurrentLocationRef.current) {
          setOriginUsesCurrentLocation(true);
          setOriginAddressValue("Votre position actuelle", {
            label: "Votre position actuelle",
            ...location,
          });

          void reverseGeocodeLocation(location)
            .then((result) => {
              if (!result || !originUsesCurrentLocationRef.current) return;
              setOriginAddressValue(result.label, result);
            })
            .catch(() => {});
        }
      },
      (error) => {
        setGeoStatus(error.code === error.PERMISSION_DENIED ? "denied" : "error");
      },
      {
        enableHighAccuracy: true,
        maximumAge: 60_000,
        timeout: 12_000,
      },
    );
  }, [setOriginAddressValue]);

  const acceptGeolocation = useCallback(() => {
    window.localStorage.setItem(GEOLOCATION_CONSENT_KEY, "accepted");
    setGeoConsent("accepted");
    setConsentReady(true);
    requestGeolocation();
  }, [requestGeolocation]);

  const declineGeolocation = useCallback(() => {
    window.localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
    setGeoConsent("declined");
    setConsentReady(true);
    setGeoStatus("denied");
  }, []);

  const handleItinerarySubmit = useCallback(
    (event: FormEvent<HTMLFormElement>) => {
      event.preventDefault();

      const origin = originAddress.selected ?? originAddress.pickActiveSuggestion();
      const destination =
        destinationAddress.selected ?? destinationAddress.pickActiveSuggestion();
      const destinationQuery = destinationAddress.query.trim();

      if (!destination && destinationQuery.length < 3) {
        destinationAddress.setError("Saisissez une destination ou choisissez une adresse.");
        return;
      }

      const params = new URLSearchParams({ route: "1" });
      const originQuery = originAddress.query.trim();

      if (origin) {
        params.set("fromLat", String(origin.lat));
        params.set("fromLng", String(origin.lng));
        params.set("from", origin.label);
      } else if (userLocation && originUsesCurrentLocation) {
        params.set("fromLat", String(userLocation.lat));
        params.set("fromLng", String(userLocation.lng));
        params.set("from", "Votre position actuelle");
      } else if (originQuery.length >= 3) {
        params.set("from", originQuery);
      }

      if (destination) {
        params.set("toLat", String(destination.lat));
        params.set("toLng", String(destination.lng));
        params.set("to", destination.label);
      } else {
        params.set("to", destinationQuery);
      }

      params.set("mode", "transit");
      window.location.assign(`/carte-immersive?${params.toString()}`);
    },
    [destinationAddress, originAddress, originUsesCurrentLocation, userLocation],
  );

  useEffect(() => {
    const updateBackToTopVisibility = () => {
      setShowBackToTop(window.scrollY > Math.min(window.innerHeight * 0.75, 600));
    };

    const updateProgress = () => {
      const bar = progressBarRef.current;
      if (!bar) return;
      const docH = document.documentElement.scrollHeight - window.innerHeight;
      bar.style.width = `${(docH > 0 ? (window.scrollY / docH) * 100 : 0).toFixed(2)}%`;
    };

    const onScroll = () => {
      updateBackToTopVisibility();
      updateProgress();
    };

    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", updateProgress, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", updateProgress);
    };
  }, []);

  useEffect(() => {
    let cancelled = false;

    const timer = window.setTimeout(() => {
      const savedConsent = window.localStorage.getItem(GEOLOCATION_CONSENT_KEY);

      if (savedConsent === "accepted") {
        setGeoConsent("accepted");
        setConsentReady(true);
        requestGeolocation();
        return;
      }

      if (savedConsent === "declined") {
        window.localStorage.removeItem(GEOLOCATION_CONSENT_KEY);
      }

      if (navigator.permissions) {
        void navigator.permissions
          .query({ name: "geolocation" as PermissionName })
          .then((permission) => {
            if (cancelled) return;

            if (permission.state === "granted") {
              window.localStorage.setItem(GEOLOCATION_CONSENT_KEY, "accepted");
              setGeoConsent("accepted");
              setConsentReady(true);
              requestGeolocation();
              return;
            }

            setConsentReady(true);
          })
          .catch(() => {
            if (!cancelled) setConsentReady(true);
          });
        return;
      }

      setConsentReady(true);
    }, 0);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [requestGeolocation]);

  const scrollToTop = useCallback(() => {
    window.scrollTo({
      top: 0,
      behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
    });
  }, []);

  const mapFocusLocation = originAddress.selected ?? userLocation;
  const heroWeather = useHeroWeather(mapFocusLocation);

  return (
    <div className={`${shared.root} ${shared.variantB} ${styles.page} ${fontClassName}`}>
      <div className={shared.ambient} aria-hidden="true">
        <div className={shared.ambientOne} />
        <div className={shared.ambientTwo} />
        <div className={shared.ambientShade} />
      </div>

      {/* Voile sombre translucide global (même esprit que le voile du hero). */}
      <div className={styles.pageVeil} aria-hidden="true" />

      <nav className={shared.nav} aria-label="Navigation principale">
        <div className={shared.navBrand}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={LOGO} alt="Aule" />
          <span>Aule</span>
        </div>
        <div className={shared.navAudience}>
          <a href="#fonctionnalites" data-hover className={shared.navLink}>
            Voyageurs
          </a>
          <a href="/pro" data-hover className={shared.navLink}>
            Professionnels
          </a>
          <a href="#services" data-hover className={shared.navLink}>
            Partenaires
          </a>
        </div>
        <div className={shared.navActions}>
          <a href="/carte-immersive" data-hover className={shared.navGhost}>
            Découvrir
          </a>
          <a href="/login" data-hover className={shared.navGhost}>
            Connexion
          </a>
          <a href="#download" data-hover className={shared.navPrimary}>
            Télécharger
          </a>
        </div>
      </nav>

      <div className={shared.progressTrack} aria-hidden="true">
        <div ref={progressBarRef} />
      </div>

      <button
        type="button"
        className={`${shared.backToTop} ${showBackToTop ? shared.backToTopVisible : ""}`}
        onClick={scrollToTop}
        aria-label="Revenir en haut de la page"
        title="Revenir en haut"
        aria-hidden={!showBackToTop}
        tabIndex={showBackToTop ? 0 : -1}
      >
        <ArrowUp size={21} strokeWidth={2.4} aria-hidden="true" />
      </button>

      <main>
        {/* ---- HERO ---- */}
        <section
          className={styles.hero}
          data-period={heroWeather.period}
          data-weather={heroWeather.condition}
        >
          <div className={`${shared.mapHero} ${styles.heroBg}`} aria-hidden="true">
            <HeroInteractiveMap
              className={shared.mapHeroCanvas}
              focusLocation={mapFocusLocation}
              userLocation={userLocation}
              weather={heroWeather}
            />
            <div className={shared.weatherScene}>
              <span className={`${shared.weatherCloud} ${shared.weatherCloudOne}`} />
              <span className={`${shared.weatherCloud} ${shared.weatherCloudTwo}`} />
              <span className={shared.weatherRain} />
              <span className={shared.weatherSnow} />
              <span className={shared.weatherLightning} />
            </div>
            <div className={shared.mapHeroVeil} />
          </div>

          <div className={shared.weatherStatus} aria-label={`Météo actuelle : ${heroWeather.label}`}>
            <span aria-hidden="true" />
            <div>
              <strong>{heroWeather.temperature != null ? `${Math.round(heroWeather.temperature)}°` : "Nantes"}</strong>
              <small>{heroWeather.label}</small>
            </div>
          </div>

          <div className={styles.heroInner}>
            <div className={styles.heroContent}>
              <div className={shared.heroBadge}>
                <span className={shared.pulseDot} /> SAEIV — Système d&apos;aide à
                l&apos;exploitation et à l&apos;information voyageurs
              </div>
              <h1 className={shared.heroTitle}>
                L&apos;information voyageurs et les <span>outils métier</span>, réunis.
              </h1>
              <p className={shared.heroCopy}>
                Aule centralise et diffuse les informations utiles aux voyageurs en temps
                réel, tout en donnant aux professionnels du transport et aux partenaires les
                outils pour les produire, les enrichir et piloter le réseau.
              </p>
              <div className={shared.heroActions}>
                <a href="/carte-immersive" data-hover className={shared.btnGlass}>
                  Explorer la carte voyageurs
                </a>
                <a href="/pro" data-hover className={shared.btnPrimary}>
                  Découvrir Aule Pro
                </a>
              </div>
            </div>

            <form className={styles.itineraryCard} onSubmit={handleItinerarySubmit}>
              <div className={shared.itineraryHeader}>
                <div>
                  <span>Nouvel itinéraire</span>
                  <strong>Où allons-nous aujourd&apos;hui ?</strong>
                </div>
              </div>
              <div className={shared.itineraryFields}>
                <label className={shared.itineraryField}>
                  <span className={shared.routeDot} aria-hidden="true" />
                  <span>
                    <small>
                      {originUsesCurrentLocation && (geoStatus === "located" || geoStatus === "locating")
                        ? "Départ · position actuelle"
                        : "Départ"}
                    </small>
                    <input
                      type="text"
                      value={
                        geoStatus === "locating" && originUsesCurrentLocation
                          ? "Localisation en cours..."
                          : originAddress.query
                      }
                      placeholder="Adresse de départ"
                      aria-label="Départ"
                      role="combobox"
                      aria-autocomplete="list"
                      aria-expanded={originAddress.open}
                      aria-controls={originAddress.listboxId}
                      aria-activedescendant={
                        originAddress.open && originAddress.activeIndex >= 0
                          ? `${originAddress.listboxId}-${originAddress.activeIndex}`
                          : undefined
                      }
                      autoComplete="street-address"
                      onChange={(event) => originAddress.handleChange(event.target.value)}
                      onFocus={originAddress.handleFocus}
                      onKeyDown={originAddress.handleKeyDown}
                    />
                  </span>
                  {originAddress.selected || (geoStatus === "located" && originUsesCurrentLocation) ? (
                    <i aria-hidden="true">✓</i>
                  ) : null}
                </label>
                <label className={shared.itineraryField}>
                  <span className={shared.routeSquare} aria-hidden="true" />
                  <span>
                    <small>Destination</small>
                    <input
                      type="text"
                      value={destinationAddress.query}
                      placeholder="Saisissez une adresse ou un lieu"
                      aria-label="Destination"
                      role="combobox"
                      aria-autocomplete="list"
                      aria-expanded={destinationAddress.open}
                      aria-controls={destinationAddress.listboxId}
                      aria-activedescendant={
                        destinationAddress.open && destinationAddress.activeIndex >= 0
                          ? `${destinationAddress.listboxId}-${destinationAddress.activeIndex}`
                          : undefined
                      }
                      autoComplete="street-address"
                      onChange={(event) => destinationAddress.handleChange(event.target.value)}
                      onFocus={destinationAddress.handleFocus}
                      onKeyDown={destinationAddress.handleKeyDown}
                    />
                  </span>
                </label>
              </div>
              <AddressSuggestions autocomplete={originAddress} label="Suggestions d'adresses de départ" />
              <AddressSuggestions autocomplete={destinationAddress} label="Suggestions d'adresses de destination" />
              <div className={shared.itineraryFooter}>
                <span>Appuyez sur Entrée pour calculer</span>
                <button type="submit" data-hover>
                  Calculer l&apos;itinéraire
                  <span aria-hidden="true">→</span>
                </button>
              </div>
            </form>
          </div>

          <div className={shared.scrollCue} aria-hidden="true">
            <span>Suivez le parcours</span>
            <svg width="17" height="25" viewBox="0 0 17 25" className={shared.scrollHint}>
              <rect x="1" y="1" width="15" height="23" rx="7.5" fill="none" stroke="rgba(255,255,255,0.45)" strokeWidth="1.5" />
              <circle cx="8.5" cy="8" r="2.2" fill="#33BFA3" />
            </svg>
          </div>
        </section>

        {/* ---- 01 · Une seule carte ---- */}
        <section id="fonctionnalites" className={`${styles.section} ${styles.blendTop}`}>
          <Reveal className={styles.sectionInner}>
            <div className={styles.colText}>
              <div className={styles.eyebrow}>01 — Une seule carte</div>
              <h2 className={styles.colTitle}>Une carte qui comprend votre environnement.</h2>
              <p className={styles.colCopy}>
                Vous n&apos;avez plus besoin d&apos;utiliser plusieurs applications. Toutes les
                informations essentielles sont réunies sur une seule carte.
              </p>
            </div>
            <div className={`${styles.colVisual} ${styles.mapCol}`}>
              <EnvironmentSectionMap />
            </div>
          </Reveal>
        </section>

        {/* ---- 02 · Temps réel (inversé) ---- */}
        <section className={styles.section}>
          <Reveal className={styles.sectionInner} data-reverse="true">
            <div className={styles.colText}>
              <div className={styles.eyebrow}>02 — Temps réel</div>
              <h2 className={styles.colTitle}>Suivez votre véhicule en direct.</h2>
              <p className={styles.colCopy}>
                Position en direct, trajet restant, arrêts desservis et prochains arrêts, temps
                estimé avant l&apos;arrivée. Anticipez votre déplacement et sachez précisément
                quand votre véhicule arrive.
              </p>
            </div>
            <div className={styles.colVisual}>
              <div className={shared.trackingCard} style={panelStyle}>
                <div className={shared.lineHeader}><span>T3</span> Tram T3 · direction Gare</div>
                <div className={shared.arrivalRow}>
                  <div>
                    <div className={shared.muted}>Arrivée à votre arrêt</div>
                    <div className={shared.bigEta}>4 min</div>
                  </div>
                  <div className={shared.platform}>Quai B<br /><strong>Hôtel de Ville</strong></div>
                </div>
                {[
                  { name: "Hôtel de Ville", eta: "4 min", active: true },
                  { name: "Place Carnot", eta: "7 min", active: false },
                  { name: "Gare centrale", eta: "12 min", active: false },
                ].map(({ name, eta, active }) => (
                  <div key={name} className={shared.stopRow}>
                    <span className={active ? shared.stopDotActive : shared.stopDot} />
                    {name}
                    <span>{eta}</span>
                  </div>
                ))}
              </div>
            </div>
          </Reveal>
        </section>

        {/* ---- 03 · Accompagnement ---- */}
        <section className={styles.section}>
          <Reveal className={styles.sectionInner}>
            <div className={styles.colText}>
              <div className={styles.eyebrow}>03 — Accompagnement</div>
              <h2 className={styles.colTitle}>Ne manquez plus votre arrêt.</h2>
              <p className={styles.colCopy}>
                L&apos;application vous accompagne avant, pendant et jusqu&apos;à la fin de votre trajet.
              </p>
            </div>
            <div className={styles.colVisual}>
              <div className={shared.notificationStack}>
                <div className={shared.notificationCard} style={panelStyle}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={LOGO} alt="" />
                  <div>
                    <div className={shared.notificationMeta}><strong>Aule</strong><span>maintenant</span></div>
                    <div className={shared.notificationTitle}>Votre tram T3 arrive 🚋</div>
                    <div className={shared.notificationText}>À 2 minutes de l&apos;arrêt. Dirigez-vous vers le quai B.</div>
                  </div>
                </div>
                <div className={shared.greenCallout}>🚪 Préparez votre descente · Gare centrale</div>
                <div className={shared.progressCard}>
                  <div><span>Progression du trajet</span><strong>68%</strong></div>
                  <span><i /></span>
                </div>
              </div>
            </div>
          </Reveal>
        </section>

        {/* ---- 04 · Commerces partenaires (inversé) ---- */}
        <section id="services" className={styles.section}>
          <Reveal className={styles.sectionInner} data-reverse="true">
            <div className={styles.colText}>
              <div className={styles.eyebrow}>04 — Commerces partenaires · Prochainement</div>
              <h2 className={styles.colTitle}>Les services de proximité arrivent bientôt.</h2>
              <p className={styles.colCopy}>
                La commande auprès de commerces partenaires et la livraison sur le trajet sont
                en préparation. Elles ne sont pas encore disponibles dans Aule.
              </p>
            </div>
            <div className={styles.colVisual}>
              <div className={shared.orderStack}>
                <div className={shared.orderCard} style={panelStyle}>
                  <div className={shared.orderHeader}><strong>☕ Exemple de parcours</strong><span>Prochainement</span></div>
                  <div><span>Cappuccino x1</span><span>3,80 €</span></div>
                  <div><span>Croissant x2</span><span>2,40 €</span></div>
                  <div className={shared.orderTotal}><strong>Total</strong><strong>6,20 €</strong></div>
                </div>
                <div className={shared.deliveryCard}>🛵 Livraison sur le trajet <strong>Prochainement</strong></div>
              </div>
            </div>
          </Reveal>
        </section>

        {/* ---- 05 · VTC & Taxi (centré) ---- */}
        <section className={`${styles.section} ${styles.sectionCentered}`}>
          <Reveal className={styles.centeredInner}>
            <div className={styles.eyebrow}>05 — VTC &amp; Taxi · Prochainement</div>
            <h2 className={shared.centerTitle}>Besoin d&apos;une autre solution ?</h2>
            <p className={shared.centerCopy}>
              La réservation de VTC et de taxis est une évolution envisagée. Aucun service de
              course n&apos;est encore réservable dans Aule.
            </p>
            <div className={shared.modeCards}>
              <div><span>🚗</span><div><strong>VTC</strong><small>Bientôt disponible</small></div></div>
              <div><span>🚕</span><div><strong>Taxi</strong><small>Bientôt disponible</small></div></div>
            </div>
          </Reveal>
        </section>

        {/* ---- 06 · La communauté (centré) ---- */}
        <section id="communaute" className={`${styles.section} ${styles.sectionCentered}`}>
          <Reveal className={styles.centeredInner}>
            <div className={styles.eyebrow}>06 — La communauté · Déploiement progressif</div>
            <h2 className={shared.centerTitle}>Des contributions communautaires encadrées.</h2>
            <p className={shared.centerCopy}>
              Les signalements et informations partagées seront activés progressivement selon
              les réseaux. Leur disponibilité n&apos;est pas encore généralisée.
            </p>
            <div className={shared.chips}>
              {["🚏 Véhicule chargé", "⚠ Perturbation", "🚧 Incident", "🚦 Circulation difficile", "👥 Affluence modérée"].map((item) => (
                <span key={item}>{item}</span>
              ))}
            </div>
          </Reveal>
        </section>

        {/* ---- 07 · La vision (centré) ---- */}
        <section id="vision" className={`${styles.section} ${styles.sectionCentered}`}>
          <Reveal className={styles.centeredInner}>
            <div className={styles.eyebrow}>07 — La vision</div>
            <h2 className={shared.visionTitle}>Une application qui évolue avec <span>votre ville</span>.</h2>
            <p className={shared.centerCopy}>
              Aule prévoit de connecter progressivement les acteurs de la mobilité. Les VTC,
              taxis et commerces présentés ci-dessous font partie de la feuille de route et ne
              sont pas encore disponibles.
            </p>
            <div className={shared.squareChips}>
              {["🚶 Voyageurs", "Conducteurs", "Opérateurs", "🚗 VTC", "🚕 Taxis", "🛍️ Commerces"].map((item) => (
                <span key={item}>{item}</span>
              ))}
            </div>
          </Reveal>
        </section>

        {/* ---- 08 · Les bénéfices ---- */}
        <section className={shared.benefits}>
          <div>
            <Reveal className={shared.sectionHead}>
              <div className={styles.eyebrow}>08 — Les bénéfices</div>
              <h2>Pourquoi choisir Aule ?</h2>
            </Reveal>
            <Reveal className={shared.benefitGrid}>
              {BENEFITS.map(({ Icon, title, text }, index) => (
                <article key={title} className={index === 7 ? shared.highlightBenefit : undefined}>
                  <span className={shared.benefitIcon} aria-hidden="true">
                    <Icon size={22} strokeWidth={2.1} />
                  </span>
                  <h3>{title}</h3>
                  <p>{text}</p>
                </article>
              ))}
            </Reveal>
          </div>
        </section>
      </main>

      {/* ---- Téléchargement ---- */}
      <section id="download" className={shared.download}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={LOGO} alt="Aule" />
        <h2>Aule arrive bientôt<br />sur les stores.</h2>
        <p>L&apos;application iOS et Android est en préparation. Les liens officiels seront activés dès l&apos;ouverture des stores.</p>
        <div>
          <span className={`${shared.storeLight} ${shared.storeUnavailable}`} aria-disabled="true">
            <span className={shared.storeIcon} aria-hidden="true">
              <Apple size={26} strokeWidth={2.4} />
            </span>
            <span><small>App Store</small><strong>Bientôt disponible</strong></span>
          </span>
          <span className={`${shared.storeDark} ${shared.storeUnavailable}`} aria-disabled="true">
            <span className={shared.storeIcon} aria-hidden="true">
              <Play size={22} fill="currentColor" strokeWidth={2.4} />
            </span>
            <span><small>Google Play</small><strong>Bientôt disponible</strong></span>
          </span>
        </div>
      </section>

      {/* ---- Footer ---- */}
      <footer className={shared.footer} role="contentinfo">
        <div className={shared.footerInner}>
          <div className={shared.footerMain}>
            <Link href="/" className={shared.footerBrand} data-hover aria-label="Retour à l'accueil Aule">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={LOGO} alt="" />
              <span>Aule</span>
            </Link>
            <p className={shared.footerText}>
              Le GPS intelligent qui réunit itinéraires, temps réel, alertes, services partenaires
              et mobilité professionnelle dans une seule expérience.
            </p>
            <div className={shared.footerBadges} aria-label="Informations clés">
              <span>Pilote Nantes</span>
              <span>Voyageurs &amp; Pro</span>
              <span>Temps réel</span>
            </div>
            <div className={shared.footerStoreLinks} aria-label="Disponibilité d'Aule sur les stores">
              <span className={`${shared.footerStoreLink} ${shared.storeUnavailable}`} aria-disabled="true">
                <Apple size={18} strokeWidth={2.3} aria-hidden="true" />
                <span>App Store · bientôt</span>
              </span>
              <span className={`${shared.footerStoreLink} ${shared.storeUnavailable}`} aria-disabled="true">
                <Play size={16} fill="currentColor" strokeWidth={2.3} aria-hidden="true" />
                <span>Google Play · bientôt</span>
              </span>
            </div>
          </div>

          <nav className={shared.footerColumn} aria-label="Produit">
            <h2>Produit</h2>
            {FOOTER_PRODUCT_LINKS.map((link) => (
              <a key={link.label} href={link.href} data-hover>
                {link.label}
              </a>
            ))}
          </nav>

          <nav className={shared.footerColumn} aria-label="Aule Pro">
            <h2>Aule Pro</h2>
            {FOOTER_PRO_LINKS.map((link) => (
              <a key={link.label} href={link.href} data-hover>
                {link.label}
              </a>
            ))}
          </nav>

          <nav className={shared.footerColumn} aria-label="Support et légal">
            <h2>Support</h2>
            {FOOTER_SUPPORT_LINKS.map((link) => (
              <a key={link.label} href={link.href} data-hover>
                {link.label}
              </a>
            ))}
          </nav>
        </div>

        <div className={shared.footerBottom}>
          <span>© 2026 Aule. Tous droits réservés.</span>
          <span>
            Aule · Aule Pro · Mobilités connectées · Météo par{" "}
            <a href="https://open-meteo.com/" target="_blank" rel="noreferrer">Open-Meteo</a>
          </span>
        </div>
      </footer>

      {consentReady && geoConsent === "pending" ? (
        <div className={shared.consentBanner} role="dialog" aria-live="polite" aria-label="Consentement à la géolocalisation">
          <div>
            <strong>Autoriser la géolocalisation ?</strong>
            <p>
              Aule utilise votre position pour centrer la carte, afficher les transports autour de vous
              et proposer des actions rapides adaptées à votre trajet.
            </p>
          </div>
          <div>
            <button type="button" onClick={declineGeolocation}>
              Plus tard
            </button>
            <button type="button" onClick={acceptGeolocation}>
              Autoriser ma position
            </button>
          </div>
        </div>
      ) : null}
    </div>
  );
}
