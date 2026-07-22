"use client";

import {
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
  type CSSProperties,
  type FormEvent,
  type KeyboardEvent,
} from "react";
import {
  Apple,
  Bell,
  CarFront,
  CircleCheck,
  Map,
  Play,
  RadioTower,
  ShoppingBag,
  Smartphone,
  ArrowUp,
  Users,
} from "lucide-react";
import Link from "next/link";
import {
  reverseGeocodeLocation,
  searchAddresses,
  type GeocodeResult,
} from "@/lib/geocode";
import { EnvironmentSectionMap, HeroInteractiveMap, HeroPhoneMap, ScreenMap } from "./hero-phone-map";
import styles from "./scrolly-landing.module.css";
import { useHeroWeather } from "./use-hero-weather";

const GEOLOCATION_CONSENT_KEY = "aule-landing-geolocation-consent";
const LOGO = "/uploads/logo-1783189856190.png";
const BUS_ICON = "/uploads/bus-icon-cropped.png";
const TRAM_ICON = "/uploads/tram-icon-cropped.png";

const STAGE_SECTIONS = [
  "hero",
  "map",
  "tracking",
  "support",
  "commerce",
  "rides",
  "community",
  "vision",
] as const;

const FOOTER_PRODUCT_LINKS = [
  { label: "Carte interactive", href: "/carte-immersive" },
  { label: "Fonctionnalités", href: "#fonctionnalites", stageIndex: 1 },
  { label: "Services", href: "#services", stageIndex: 4 },
  { label: "Vision", href: "#vision", stageIndex: 7 },
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

type ScrollyLandingProps = {
  /** Classe injectée par next/font pour exposer --font-space-grotesk. */
  fontClassName?: string;
};

type GeolocationConsent = "pending" | "accepted" | "declined";
type GeolocationStatus = "idle" | "locating" | "located" | "denied" | "unavailable" | "error";
type UserLocation = { lng: number; lat: number };

function splitAddressLabel(labelText: string) {
  const [title, ...details] = labelText.split(",");

  return {
    title: title.trim(),
    details: details.join(",").trim(),
  };
}

function useAddressAutocomplete({
  initialQuery = "",
  onUserInput,
}: {
  initialQuery?: string;
  onUserInput?: () => void;
} = {}) {
  const listboxId = useId();
  const abortRef = useRef<AbortController | null>(null);
  const [query, setQuery] = useState(initialQuery);
  const [suggestions, setSuggestions] = useState<GeocodeResult[]>([]);
  const [selected, setSelected] = useState<GeocodeResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeIndex, setActiveIndex] = useState(-1);

  const clearSearch = useCallback(() => {
    abortRef.current?.abort();
    setSuggestions([]);
    setOpen(false);
    setActiveIndex(-1);
    setLoading(false);
  }, []);

  const pick = useCallback((result: GeocodeResult) => {
    setQuery(result.label);
    setSelected(result);
    setSuggestions([]);
    setOpen(false);
    setError(null);
    setActiveIndex(-1);
  }, []);

  const setValue = useCallback((value: string, result?: GeocodeResult | null) => {
    setQuery(value);
    setSelected(result ?? null);
    setSuggestions([]);
    setOpen(false);
    setError(null);
    setActiveIndex(-1);
    setLoading(false);
  }, []);

  const handleChange = useCallback(
    (nextValue: string) => {
      setQuery(nextValue);
      setSelected(null);
      setError(null);
      onUserInput?.();

      if (nextValue.trim().length < 3) {
        clearSearch();
      }
    },
    [clearSearch, onUserInput],
  );

  const handleFocus = useCallback(() => {
    setOpen(suggestions.length > 0);
  }, [suggestions.length]);

  const pickActiveSuggestion = useCallback(() => {
    if (suggestions.length === 0) return null;
    const nextIndex = activeIndex >= 0 ? activeIndex : 0;
    const result = suggestions[nextIndex];
    pick(result);
    return result;
  }, [activeIndex, pick, suggestions]);

  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLInputElement>) => {
      if (event.key === "ArrowDown" && suggestions.length > 0) {
        event.preventDefault();
        setOpen(true);
        setActiveIndex((current) => (current + 1) % suggestions.length);
        return;
      }

      if (event.key === "ArrowUp" && suggestions.length > 0) {
        event.preventDefault();
        setOpen(true);
        setActiveIndex((current) => (current <= 0 ? suggestions.length - 1 : current - 1));
        return;
      }

      if (event.key === "Enter" && open && suggestions.length > 0) {
        event.preventDefault();
        pickActiveSuggestion();
        return;
      }

      if (event.key === "Escape") {
        setOpen(false);
      }
    },
    [open, pickActiveSuggestion, suggestions.length],
  );

  useEffect(() => {
    const trimmedQuery = query.trim();

    if (trimmedQuery.length < 3 || selected?.label === query) {
      return undefined;
    }

    const controller = new AbortController();
    abortRef.current?.abort();
    abortRef.current = controller;

    const timer = window.setTimeout(() => {
      setLoading(true);
      setError(null);

      void searchAddresses(trimmedQuery, controller.signal)
        .then((results) => {
          setSuggestions(results);
          setOpen(results.length > 0);
          setActiveIndex(results.length > 0 ? 0 : -1);
          setError(
            results.length === 0
              ? "Aucune adresse trouvée. Ajoutez la ville ou le code postal."
              : null,
          );
        })
        .catch((searchError: unknown) => {
          if (controller.signal.aborted) return;

          setSuggestions([]);
          setOpen(false);
          setActiveIndex(-1);
          setError(
            searchError instanceof Error
              ? searchError.message
              : "Impossible de rechercher cette adresse.",
          );
        })
        .finally(() => {
          if (!controller.signal.aborted) {
            setLoading(false);
          }
        });
    }, 260);

    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [query, selected?.label]);

  useEffect(() => {
    return () => abortRef.current?.abort();
  }, []);

  return {
    activeIndex,
    error,
    handleChange,
    handleFocus,
    handleKeyDown,
    listboxId,
    loading,
    open,
    pick,
    pickActiveSuggestion,
    query,
    selected,
    setError,
    setOpen,
    setValue,
    suggestions,
  };
}

type AddressAutocompleteState = ReturnType<typeof useAddressAutocomplete>;

function AddressSuggestions({
  autocomplete,
  label,
}: {
  autocomplete: AddressAutocompleteState;
  label: string;
}) {
  if (
    !autocomplete.loading &&
    !autocomplete.error &&
    autocomplete.suggestions.length === 0
  ) {
    return null;
  }

  return (
    <div
      id={autocomplete.listboxId}
      className={styles.addressAutocomplete}
      role="listbox"
      aria-label={label}
    >
      {autocomplete.loading ? (
        <div className={styles.addressAutocompleteStatus}>Recherche d&apos;adresses...</div>
      ) : null}
      {!autocomplete.loading
        ? autocomplete.suggestions.map((result, index) => {
          const address = splitAddressLabel(result.label);
          const isActive = autocomplete.open && index === autocomplete.activeIndex;

          return (
            <button
              key={`${result.lng}-${result.lat}-${result.label}`}
              id={`${autocomplete.listboxId}-${index}`}
              type="button"
              role="option"
              aria-selected={isActive}
              className={`${styles.addressSuggestion} ${isActive ? styles.addressSuggestionActive : ""}`}
              onMouseDown={(event) => {
                event.preventDefault();
                autocomplete.pick(result);
              }}
              onClick={() => autocomplete.pick(result)}
            >
              <span className={styles.addressSuggestionPin} aria-hidden="true" />
              <span>
                <strong>{address.title}</strong>
                {address.details ? <small>{address.details}</small> : null}
              </span>
            </button>
          );
        })
        : null}
      {!autocomplete.loading && autocomplete.error ? (
        <div className={styles.addressAutocompleteStatus}>{autocomplete.error}</div>
      ) : null}
    </div>
  );
}

type StageContentProps = {
  children: React.ReactNode;
  index: number;
  reverse?: boolean;
  centered?: boolean;
  fullBleed?: boolean;
};

const screen: CSSProperties = {
  position: "absolute",
  inset: 0,
  display: "flex",
  alignItems: "center",
  padding: "0 clamp(24px, 7vw, 120px)",
  willChange: "opacity, transform, filter",
};

const panel: CSSProperties = {
  border: "1px solid rgba(255,255,255,0.14)",
  background: "rgba(12,18,16,0.65)",
  backdropFilter: "blur(24px) saturate(1.3)",
  WebkitBackdropFilter: "blur(24px) saturate(1.3)",
  boxShadow: "0 30px 60px rgba(0,0,0,0.45)",
};

const label: CSSProperties = {
  fontSize: 12.5,
  letterSpacing: "0.16em",
  textTransform: "uppercase",
  color: "#33BFA3",
  marginBottom: 16,
};

function IconImage({
  src,
  alt,
  color,
}: {
  src: string;
  alt: string;
  color: string;
}) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        width: 32,
        height: 32,
        margin: -16,
        borderRadius: "11px 11px 11px 3px",
        background: color,
      }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt={alt} style={{ width: 19, height: 19, objectFit: "contain" }} />
    </div>
  );
}

function StageContent({ children, index, reverse, centered, fullBleed }: StageContentProps) {
  const sectionId =
    index === 1 ? "fonctionnalites" : index === 4 ? "services" : index === 7 ? "vision" : undefined;

  return (
    <div
      id={sectionId}
      data-sec
      data-screen-label={`${String(index + 1).padStart(2, "0")} ${STAGE_SECTIONS[index]}`}
      style={{
        ...screen,
        opacity: index === 0 ? 1 : 0,
        visibility: index === 0 ? "visible" : "hidden",
        flexDirection: centered ? "column" : undefined,
        justifyContent: centered ? "center" : undefined,
        textAlign: centered ? "center" : undefined,
        padding: centered ? "0 24px" : fullBleed ? 0 : screen.padding,
      }}
    >
      <div
        data-layout={centered ? "centered" : fullBleed ? "fullbleed" : reverse ? "reverse" : "split"}
        style={{
          display: "flex",
          alignItems: "center",
          justifyContent: centered ? "center" : "space-between",
          gap: centered ? 24 : fullBleed ? 0 : 52,
          width: "100%",
          height: fullBleed ? "100%" : undefined,
          maxWidth: centered ? 760 : fullBleed ? "none" : 1180,
          margin: fullBleed ? 0 : "0 auto",
          flexWrap: centered ? "nowrap" : fullBleed ? "nowrap" : "wrap",
          flexDirection: centered ? "column" : reverse ? "row-reverse" : undefined,
        }}
      >
        {children}
      </div>
    </div>
  );
}

function MapPreview({ compact = false }: { compact?: boolean }) {
  return (
    <div
      data-par="1.6"
      style={{
        width: compact ? 320 : 270,
        flex: "none",
        padding: compact ? 12 : 10,
        borderRadius: compact ? 30 : 42,
        background: compact ? "rgba(12,18,16,0.6)" : "linear-gradient(160deg, #1a2220, #0a0e0d)",
        border: "1px solid rgba(255,255,255,0.14)",
        boxShadow: compact
          ? "0 40px 80px rgba(0,0,0,0.5)"
          : "0 50px 100px rgba(0,0,0,0.6), inset 0 1px 0 rgba(255,255,255,0.08)",
        backdropFilter: compact ? "blur(24px) saturate(1.3)" : undefined,
      }}
    >
      <div
        style={{
          position: "relative",
          height: compact ? 300 : 540,
          borderRadius: compact ? 22 : 34,
          overflow: "hidden",
          background: "radial-gradient(120% 90% at 30% 20%, #123028, #0A1210)",
        }}
      >
        {compact ? (
          <ScreenMap variant="guidage" className={styles.phoneMap} />
        ) : (
          <HeroPhoneMap className={styles.phoneMap} />
        )}
        <div className={styles.phoneMapShade} />
        <div
          className={styles.pulseDot}
          style={{
            position: "absolute",
            zIndex: 2,
            left: compact ? 180 : 138,
            top: compact ? 90 : 216,
            width: 18,
            height: 18,
            margin: -9,
            borderRadius: "50%",
            background: "#33BFA3",
            border: "3px solid #04211c",
            boxShadow: "0 0 0 4px rgba(51,191,163,0.25)",
          }}
        />
        <div style={{ position: "absolute", zIndex: 3, left: compact ? 100 : 86, top: compact ? 150 : 108 }}>
          <IconImage src={BUS_ICON} alt="Bus" color="#E8B45A" />
        </div>
        <div style={{ position: "absolute", zIndex: 3, left: compact ? 245 : 196, top: compact ? 75 : 162 }}>
          <IconImage src={TRAM_ICON} alt="Tram" color="#33BFA3" />
        </div>
        <div
          style={{
            position: "absolute",
            zIndex: 3,
            left: compact ? 60 : 64,
            top: compact ? 235 : 280,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: compact ? 26 : 28,
            height: compact ? 26 : 28,
            margin: compact ? -13 : -14,
            borderRadius: "9px 9px 9px 3px",
            background: "#7C93F0",
            fontSize: 12,
          }}
        >
          🚗
        </div>
        <div
          style={{
            position: "absolute",
            zIndex: 3,
            left: compact ? 250 : 208,
            top: compact ? 200 : 280,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: compact ? 26 : 28,
            height: compact ? 26 : 28,
            margin: compact ? -13 : -14,
            borderRadius: "9px 9px 9px 3px",
            background: compact ? "#E88AB0" : "#F0C645",
            fontSize: 12,
          }}
        >
          {compact ? "🛍️" : "🚕"}
        </div>
        {!compact ? (
          <div
            style={{
              position: "absolute",
              zIndex: 4,
              left: 16,
              right: 16,
              top: 16,
              display: "flex",
              alignItems: "center",
              gap: 9,
              padding: "10px 13px",
              borderRadius: 13,
              background: "rgba(10,14,13,0.78)",
              backdropFilter: "blur(12px)",
              border: "1px solid rgba(255,255,255,0.1)",
              fontSize: 12.5,
              color: "rgba(255,255,255,0.55)",
            }}
          >
            🔍 Autour de vous
          </div>
        ) : null}
      </div>
      {compact ? (
        <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "14px 6px 6px", fontSize: 13, color: "rgba(255,255,255,0.75)" }}>
          🔍 <span>Tout autour de vous, en un coup d&apos;oeil</span>
        </div>
      ) : null}
    </div>
  );
}

function TextBlock({
  eyebrow,
  title,
  children,
  maxWidth = 470,
}: {
  eyebrow: string;
  title: React.ReactNode;
  children: React.ReactNode;
  maxWidth?: number;
}) {
  return (
    <div data-par="1" style={{ maxWidth, willChange: "transform" }}>
      <div style={label}>{eyebrow}</div>
      <h2 style={{ margin: 0, fontSize: "clamp(32px, 4vw, 56px)", lineHeight: 1.05, fontWeight: 700, letterSpacing: 0, textWrap: "balance" }}>
        {title}
      </h2>
      <p style={{ margin: "20px 0 0", fontSize: 17, lineHeight: 1.6, color: "rgba(255,255,255,0.75)", maxWidth: 430, textWrap: "pretty" }}>
        {children}
      </p>
    </div>
  );
}

export function ScrollyLanding({ fontClassName = "" }: ScrollyLandingProps) {
  const containerRef = useRef<HTMLElement>(null);
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

  const scrollToStage = useCallback((index: number, event?: React.MouseEvent<HTMLAnchorElement>) => {
    event?.preventDefault();
    const container = containerRef.current;
    if (!container) return;
    const scrollable = container.offsetHeight - window.innerHeight;
    window.scrollTo({
      top: container.offsetTop + (index / Math.max(1, STAGE_SECTIONS.length - 1)) * scrollable,
      behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth",
    });
  }, []);

  useEffect(() => {
    const updateBackToTopVisibility = () => {
      setShowBackToTop(window.scrollY > Math.min(window.innerHeight * 0.75, 600));
    };

    updateBackToTopVisibility();
    window.addEventListener("scroll", updateBackToTopVisibility, { passive: true });
    return () => window.removeEventListener("scroll", updateBackToTopVisibility);
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

  useEffect(() => {
    const container = containerRef.current;
    const progressBar = progressBarRef.current;
    if (!container) return;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const sections = Array.from(container.querySelectorAll<HTMLElement>("[data-sec]"));
    let rafId = 0;

    const smooth = (a: number, b: number, x: number) => {
      const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
      return t * t * (3 - 2 * t);
    };

    const tick = () => {
      rafId = requestAnimationFrame(tick);

      const docH = document.documentElement.scrollHeight - window.innerHeight;
      if (progressBar) {
        progressBar.style.width = `${(docH > 0 ? (window.scrollY / docH) * 100 : 0).toFixed(2)}%`;
      }

      const rect = container.getBoundingClientRect();
      const scrollable = rect.height - window.innerHeight;
      const overall = scrollable > 0 ? Math.min(1, Math.max(0, -rect.top / scrollable)) : 0;
      const maxIndex = Math.max(1, sections.length - 1);

      sections.forEach((el, index) => {
        const d = overall * maxIndex - index;
        const ad = Math.abs(d);
        if (ad > 0.72) {
          el.style.opacity = "0";
          el.style.visibility = "hidden";
          return;
        }

        el.style.visibility = "visible";
        const vis = 1 - smooth(0.42, 0.66, ad);
        el.style.opacity = vis.toFixed(3);
        if (reduced) return;

        el.style.filter = vis > 0.9 ? "none" : `blur(${((1 - vis) * 5).toFixed(1)}px)`;
        const drift = -d * 42;
        const layers = el.querySelectorAll<HTMLElement>("[data-par]");
        layers.forEach((layer) => {
          const speed = parseFloat(layer.getAttribute("data-par") ?? "1") || 1;
          layer.style.transform = `translateY(${(drift * speed).toFixed(1)}px) scale(${(0.965 + 0.035 * vis).toFixed(4)})`;
        });
      });
    };

    rafId = requestAnimationFrame(tick);

    return () => {
      cancelAnimationFrame(rafId);
    };
  }, []);

  const mapFocusLocation = originAddress.selected ?? userLocation;
  const heroWeather = useHeroWeather(mapFocusLocation);

  return (
    <div className={`${styles.root} ${styles.variantB} ${fontClassName}`}>
      <div className={styles.ambient} aria-hidden="true">
        <div className={styles.ambientOne} />
        <div className={styles.ambientTwo} />
        <div className={styles.ambientShade} />
      </div>

      <nav className={styles.nav} aria-label="Navigation principale">
        <div className={styles.navBrand}>
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={LOGO} alt="Aule" />
          <span>Aule</span>
        </div>
        <div className={styles.navAudience}>
          <a href="#fonctionnalites" data-hover className={styles.navLink} onClick={(event) => scrollToStage(1, event)}>
            Voyageurs
          </a>
          <a href="/pro" data-hover className={styles.navLink}>
            Professionnels
          </a>
          <a href="#services" data-hover className={styles.navLink} onClick={(event) => scrollToStage(4, event)}>
            Partenaires
          </a>
        </div>
        <div className={styles.navActions}>
          <a href="/carte-immersive" data-hover className={styles.navGhost}>
            Découvrir
          </a>
          <a href="/login" data-hover className={styles.navGhost}>
            Connexion
          </a>
          <a href="#download" data-hover className={styles.navPrimary}>
            Télécharger
          </a>
        </div>
      </nav>

      <div className={styles.progressTrack} aria-hidden="true">
        <div ref={progressBarRef} />
      </div>

      <button
        type="button"
        className={`${styles.backToTop} ${showBackToTop ? styles.backToTopVisible : ""}`}
        onClick={() => scrollToStage(0)}
        aria-label="Revenir en haut de la page"
        title="Revenir en haut"
        aria-hidden={!showBackToTop}
        tabIndex={showBackToTop ? 0 : -1}
      >
        <ArrowUp size={21} strokeWidth={2.4} aria-hidden="true" />
      </button>

      <section ref={containerRef} className={styles.stage} data-screen-label="Stage immersif">
        <div className={styles.stickyStage}>
          <div
            data-sec
            data-screen-label="01 hero"
            className={styles.mapHero}
            data-period={heroWeather.period}
            data-weather={heroWeather.condition}
            style={{ opacity: 1, visibility: "visible" }}
          >
            <HeroInteractiveMap
              className={styles.mapHeroCanvas}
              focusLocation={mapFocusLocation}
              userLocation={userLocation}
              weather={heroWeather}
            />
            <div className={styles.weatherScene} aria-hidden="true">
              <span className={`${styles.weatherCloud} ${styles.weatherCloudOne}`} />
              <span className={`${styles.weatherCloud} ${styles.weatherCloudTwo}`} />
              <span className={styles.weatherRain} />
              <span className={styles.weatherSnow} />
              <span className={styles.weatherLightning} />
            </div>
            <div className={styles.mapHeroVeil} aria-hidden="true" />
            <div className={styles.weatherStatus} aria-label={`Météo actuelle : ${heroWeather.label}`}>
              <span aria-hidden="true" />
              <div>
                <strong>{heroWeather.temperature != null ? `${Math.round(heroWeather.temperature)}°` : "Nantes"}</strong>
                <small>{heroWeather.label}</small>
              </div>
            </div>
            <div className={styles.mapHeroContent}>
              <div className={styles.heroBadge}>
                <span className={styles.pulseDot} /> SAEIV — Système d&apos;aide à
                l&apos;exploitation et à l&apos;information voyageurs
              </div>
              <h1 className={styles.heroTitle}>
                L&apos;information voyageurs et les <span>outils métier</span>, réunis.
              </h1>
              <p className={styles.heroCopy}>
                Aule centralise et diffuse les informations utiles aux voyageurs en temps
                réel, tout en donnant aux professionnels du transport et aux partenaires les
                outils pour les produire, les enrichir et piloter le réseau.
              </p>
              <div className={styles.heroActions}>
                <a href="/carte-immersive" data-hover className={styles.btnGlass}>
                  Explorer la carte voyageurs
                </a>
                <a href="/pro" data-hover className={styles.btnPrimary}>
                  Découvrir Aule Pro
                </a>
              </div>
            </div>
            <form className={styles.itineraryCard} onSubmit={handleItinerarySubmit}>
              <div className={styles.itineraryHeader}>
                <div>
                  <span>Nouvel itinéraire</span>
                  <strong>Où allons-nous aujourd&apos;hui ?</strong>
                </div>
              </div>
              <div className={styles.itineraryFields}>
                <label className={styles.itineraryField}>
                  <span className={styles.routeDot} aria-hidden="true" />
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
                <label className={styles.itineraryField}>
                  <span className={styles.routeSquare} aria-hidden="true" />
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
              <AddressSuggestions
                autocomplete={originAddress}
                label="Suggestions d'adresses de départ"
              />
              <AddressSuggestions
                autocomplete={destinationAddress}
                label="Suggestions d'adresses de destination"
              />
              <div className={styles.itineraryFooter}>
                <span>Appuyez sur Entrée pour calculer</span>
                <button type="submit" data-hover>
                  Calculer l&apos;itinéraire
                  <span aria-hidden="true">→</span>
                </button>
              </div>
            </form>
            <div className={styles.scrollCue} aria-hidden="true">
              <span>Suivez le parcours</span>
              <svg width="17" height="25" viewBox="0 0 17 25" className={styles.scrollHint}>
                <rect x="1" y="1" width="15" height="23" rx="7.5" fill="none" stroke="rgba(255,255,255,0.45)" strokeWidth="1.5" />
                <circle cx="8.5" cy="8" r="2.2" fill="#33BFA3" />
              </svg>
            </div>
          </div>

          <StageContent index={1}>
            <TextBlock eyebrow="01 - Une seule carte" title="Une carte qui comprend votre environnement." maxWidth={460}>
              Vous n&apos;avez plus besoin d&apos;utiliser plusieurs applications. Toutes les informations essentielles sont réunies sur une seule carte.
            </TextBlock>
            <EnvironmentSectionMap />
          </StageContent>

          <StageContent index={2} reverse>
            <TextBlock eyebrow="02 - Temps réel" title="Suivez votre véhicule en direct.">
              Position en direct, trajet restant, arrêts desservis et prochains arrêts, temps estimé avant l&apos;arrivée. Anticipez votre déplacement et sachez précisément quand votre véhicule arrive.
            </TextBlock>
            <div data-par="1.6" className={styles.trackingCard} style={panel}>
              <div className={styles.lineHeader}><span>T3</span> Tram T3 · direction Gare</div>
              <div className={styles.arrivalRow}>
                <div>
                  <div className={styles.muted}>Arrivée à votre arrêt</div>
                  <div className={styles.bigEta}>4 min</div>
                </div>
                <div className={styles.platform}>Quai B<br /><strong>Hôtel de Ville</strong></div>
              </div>
              {[
                { name: "Hôtel de Ville", eta: "4 min", active: true },
                { name: "Place Carnot", eta: "7 min", active: false },
                { name: "Gare centrale", eta: "12 min", active: false },
              ].map(({ name, eta, active }) => (
                <div key={name} className={styles.stopRow}>
                  <span className={active ? styles.stopDotActive : styles.stopDot} />
                  {name}
                  <span>{eta}</span>
                </div>
              ))}
            </div>
          </StageContent>

          <StageContent index={3}>
            <TextBlock eyebrow="03 - Accompagnement" title="Ne manquez plus votre arrêt.">
              L&apos;application vous accompagne avant, pendant et jusqu&apos;à la fin de votre trajet.
            </TextBlock>
            <div data-par="1.6" className={styles.notificationStack}>
              <div className={styles.notificationCard} style={panel}>
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={LOGO} alt="" />
                <div>
                  <div className={styles.notificationMeta}><strong>Aule</strong><span>maintenant</span></div>
                  <div className={styles.notificationTitle}>Votre tram T3 arrive 🚋</div>
                  <div className={styles.notificationText}>À 2 minutes de l&apos;arrêt. Dirigez-vous vers le quai B.</div>
                </div>
              </div>
              <div className={styles.greenCallout}>🚪 Préparez votre descente · Gare centrale</div>
              <div className={styles.progressCard}>
                <div><span>Progression du trajet</span><strong>68%</strong></div>
                <span><i /></span>
              </div>
            </div>
          </StageContent>

          <StageContent index={4} reverse>
            <TextBlock eyebrow="04 - Commerces partenaires · Prochainement" title="Les services de proximité arrivent bientôt.">
              La commande auprès de commerces partenaires et la livraison sur le trajet sont en préparation. Elles ne sont pas encore disponibles dans Aule.
            </TextBlock>
            <div data-par="1.6" className={styles.orderStack}>
              <div className={styles.orderCard} style={panel}>
              <div className={styles.orderHeader}><strong>☕ Exemple de parcours</strong><span>Prochainement</span></div>
                <div><span>Cappuccino x1</span><span>3,80 €</span></div>
                <div><span>Croissant x2</span><span>2,40 €</span></div>
                <div className={styles.orderTotal}><strong>Total</strong><strong>6,20 €</strong></div>
              </div>
              <div className={styles.deliveryCard}>🛵 Livraison sur le trajet <strong>Prochainement</strong></div>
            </div>
          </StageContent>

          <StageContent index={5} centered>
            <div data-par="1" style={{ maxWidth: 640, willChange: "transform" }}>
              <div style={label}>05 - VTC & Taxi · Prochainement</div>
              <h2 className={styles.centerTitle}>Besoin d&apos;une autre solution ?</h2>
              <p className={styles.centerCopy}>La réservation de VTC et de taxis est une évolution envisagée. Aucun service de course n&apos;est encore réservable dans Aule.</p>
            </div>
            <div data-par="1.5" className={styles.modeCards}>
              <div><span>🚗</span><div><strong>VTC</strong><small>Bientôt disponible</small></div></div>
              <div><span>🚕</span><div><strong>Taxi</strong><small>Bientôt disponible</small></div></div>
            </div>
          </StageContent>

          <StageContent index={6} centered>
            <div data-par="1" style={{ maxWidth: 720, willChange: "transform" }}>
              <div style={label}>06 - La communauté · Déploiement progressif</div>
              <h2 className={styles.centerTitle}>Des contributions communautaires encadrées.</h2>
              <p className={styles.centerCopy}>Les signalements et informations partagées seront activés progressivement selon les réseaux. Leur disponibilité n&apos;est pas encore généralisée.</p>
            </div>
            <div data-par="1.5" className={styles.chips}>
              {["🚏 Véhicule chargé", "⚠ Perturbation", "🚧 Incident", "🚦 Circulation difficile", "👥 Affluence modérée"].map((item) => (
                <span key={item}>{item}</span>
              ))}
            </div>
          </StageContent>

          <StageContent index={7} centered>
            <div data-par="1" style={{ maxWidth: 820, willChange: "transform" }}>
              <div style={label}>07 - La vision</div>
              <h2 className={styles.visionTitle}>Une application qui évolue avec <span>votre ville</span>.</h2>
              <p className={styles.centerCopy}>Aule prévoit de connecter progressivement les acteurs de la mobilité. Les VTC, taxis et commerces présentés ci-dessous font partie de la feuille de route et ne sont pas encore disponibles.</p>
            </div>
            <div data-par="1.5" className={styles.squareChips}>
              {["🚶 Voyageurs", "Conducteurs", "Opérateurs", "🚗 VTC", "🚕 Taxis", "🛍️ Commerces"].map((item) => (
                <span key={item}>{item}</span>
              ))}
            </div>
          </StageContent>
        </div>
      </section>

      <section className={styles.benefits} data-screen-label="09 Bénéfices">
        <div>
          <div className={styles.sectionHead}>
            <div style={label}>08 - Les bénéfices</div>
            <h2>Pourquoi choisir Aule ?</h2>
          </div>
          <div className={styles.benefitGrid}>
            {[
              { Icon: Smartphone, title: "Une seule application", text: "Pour tous vos déplacements, sans jongler entre les apps." },
              { Icon: RadioTower, title: "Information enrichie", text: "Une information voyageur plus riche et plus fiable." },
              { Icon: Map, title: "Carte temps réel", text: "Une carte interactive qui réunit toutes vos mobilités." },
              { Icon: Bell, title: "Notifications intelligentes", text: "Averti au bon moment, avant l'arrivée et la descente." },
              { Icon: Users, title: "Communauté progressive", text: "Signalements communautaires disponibles selon les réseaux." },
              { Icon: ShoppingBag, title: "Commerces · prochainement", text: "Commande et livraison font partie de la feuille de route." },
              { Icon: CarFront, title: "VTC & taxis · prochainement", text: "La réservation de courses n'est pas encore disponible." },
              { Icon: CircleCheck, title: "Pensée pour simplifier", text: "Une expérience conçue pour simplifier chaque déplacement." },
            ].map(({ Icon, title, text }, index) => (
              <article key={title} className={index === 7 ? styles.highlightBenefit : undefined}>
                <span className={styles.benefitIcon} aria-hidden="true">
                  <Icon size={22} strokeWidth={2.1} />
                </span>
                <h3>{title}</h3>
                <p>{text}</p>
              </article>
            ))}
          </div>
        </div>
      </section>

      <section id="download" className={styles.download} data-screen-label="10 Télécharger">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={LOGO} alt="Aule" />
        <h2>Aule arrive bientôt<br />sur les stores.</h2>
        <p>L&apos;application iOS et Android est en préparation. Les liens officiels seront activés dès l&apos;ouverture des stores.</p>
        <div>
          <span className={`${styles.storeLight} ${styles.storeUnavailable}`} aria-disabled="true">
            <span className={styles.storeIcon} aria-hidden="true">
              <Apple size={26} strokeWidth={2.4} />
            </span>
            <span><small>App Store</small><strong>Bientôt disponible</strong></span>
          </span>
          <span className={`${styles.storeDark} ${styles.storeUnavailable}`} aria-disabled="true">
            <span className={styles.storeIcon} aria-hidden="true">
              <Play size={22} fill="currentColor" strokeWidth={2.4} />
            </span>
            <span><small>Google Play</small><strong>Bientôt disponible</strong></span>
          </span>
        </div>
      </section>

      <footer className={styles.footer} data-screen-label="Footer" role="contentinfo">
        <div className={styles.footerInner}>
          <div className={styles.footerMain}>
            <Link href="/" className={styles.footerBrand} data-hover aria-label="Retour à l'accueil Aule">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={LOGO} alt="" />
              <span>Aule</span>
            </Link>
            <p className={styles.footerText}>
              Le GPS intelligent qui réunit itinéraires, temps réel, alertes, services partenaires
              et mobilité professionnelle dans une seule expérience.
            </p>
            <div className={styles.footerBadges} aria-label="Informations clés">
              <span>Pilote Nantes</span>
              <span>Voyageurs & Pro</span>
              <span>Temps réel</span>
            </div>
            <div className={styles.footerStoreLinks} aria-label="Disponibilité d'Aule sur les stores">
              <span className={`${styles.footerStoreLink} ${styles.storeUnavailable}`} aria-disabled="true">
                <Apple size={18} strokeWidth={2.3} aria-hidden="true" />
                <span>App Store · bientôt</span>
              </span>
              <span className={`${styles.footerStoreLink} ${styles.storeUnavailable}`} aria-disabled="true">
                <Play size={16} fill="currentColor" strokeWidth={2.3} aria-hidden="true" />
                <span>Google Play · bientôt</span>
              </span>
            </div>
          </div>

          <nav className={styles.footerColumn} aria-label="Produit">
            <h2>Produit</h2>
            {FOOTER_PRODUCT_LINKS.map((link) => (
              <a
                key={link.label}
                href={link.href}
                data-hover
                onClick={
                  "stageIndex" in link
                    ? (event) => scrollToStage(link.stageIndex, event)
                    : undefined
                }
              >
                {link.label}
              </a>
            ))}
          </nav>

          <nav className={styles.footerColumn} aria-label="Aule Pro">
            <h2>Aule Pro</h2>
            {FOOTER_PRO_LINKS.map((link) => (
              <a key={link.label} href={link.href} data-hover>
                {link.label}
              </a>
            ))}
          </nav>

          <nav className={styles.footerColumn} aria-label="Support et légal">
            <h2>Support</h2>
            {FOOTER_SUPPORT_LINKS.map((link) => (
              <a key={link.label} href={link.href} data-hover>
                {link.label}
              </a>
            ))}
          </nav>
        </div>

        <div className={styles.footerBottom}>
          <span>© 2026 Aule. Tous droits réservés.</span>
          <span>
            Aule · Aule Pro · Mobilités connectées · Météo par{" "}
            <a href="https://open-meteo.com/" target="_blank" rel="noreferrer">Open-Meteo</a>
          </span>
        </div>
      </footer>

      {consentReady && geoConsent === "pending" ? (
        <div className={styles.consentBanner} role="dialog" aria-live="polite" aria-label="Consentement à la géolocalisation">
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
