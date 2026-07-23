"use client";

import Image from "next/image";
import Link from "next/link";
import { LogIn, Search, X } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

export type ImmersiveViewer = {
  displayName: string;
  avatarUrl: string | null;
};

export type GlobalSearchSuggestion = {
  id: string;
  category: "stop" | "line" | "driver" | "merchant";
  mode: "stop" | "bus" | "tram" | "navibus" | "vtc" | "taxi" | "shop";
  title: string;
  subtitle: string;
  keywords?: string;
  color?: string;
  distanceMeters?: number;
};

type TopBarProps = {
  viewer?: ImmersiveViewer | null;
  globalSearchQuery: string;
  globalSearchSuggestions: GlobalSearchSuggestion[];
  onGlobalSearchChange: (value: string) => void;
  onGlobalSearchSelect: (suggestion: GlobalSearchSuggestion) => void;
  /** Sur mobile la recherche vit dans la barre du bas : le header ne l'affiche
   *  que si elle a été ouverte depuis là. */
  mobileSearchOpen: boolean;
  onMobileSearchOpenChange: (open: boolean) => void;
  showInputs: boolean;
  searchQuery: string;
  onSearchChange: (value: string) => void;
  onSearchKeyDown: (e: React.KeyboardEvent<HTMLInputElement>) => void;
  onSearchFocus: () => void;
  onSearchBlur: () => void;
  onSearchSubmit: () => void;
  onCloseInputs: () => void;
  originAddress: string;
  originIsCurrent: boolean;
  onOriginChange: (value: string) => void;
  onOriginFocus: () => void;
  onOriginBlur: () => void;
  onOriginClear: () => void;
  onUseCurrentPosition: () => void;
  originAddressLoading: boolean;
  destinationLoading: boolean;
  searchError: string | null;
  showAddressSuggestions: boolean;
  addressSuggestionsLoading: boolean;
  addressSuggestions: Array<{
    id: string;
    label: string;
    kind?: "address" | "stop";
    onPick: () => void;
  }>;
  showOriginSuggestions: boolean;
  originSuggestionsLoading: boolean;
  originSuggestions: Array<{
    id: string;
    label: string;
    kind?: "address" | "stop";
    onPick: () => void;
  }>;
};

function getInitials(displayName: string): string {
  const parts = displayName.trim().split(/\s+/).filter(Boolean);
  if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase();
  return (parts[0] ?? "U").slice(0, 2).toUpperCase();
}

const SEARCH_GROUP_LABELS: Record<GlobalSearchSuggestion["category"], string> = {
  stop: "Arrêts et stations",
  line: "Lignes",
  driver: "Chauffeurs",
  merchant: "Commerçants",
};

const SEARCH_MODE_ICONS: Record<GlobalSearchSuggestion["mode"], string> = {
  stop: "🚏",
  bus: "🚌",
  tram: "🚋",
  navibus: "⛴️",
  vtc: "🚖",
  taxi: "🚕",
  shop: "🏪",
};

function normalizeSearch(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .trim();
}

export function TopBar({
  viewer = null,
  globalSearchQuery,
  globalSearchSuggestions,
  onGlobalSearchChange,
  onGlobalSearchSelect,
  mobileSearchOpen,
  onMobileSearchOpenChange,
  showInputs,
  searchQuery,
  onSearchChange,
  onSearchKeyDown,
  onSearchFocus,
  onSearchBlur,
  onSearchSubmit,
  onCloseInputs,
  originAddress,
  originIsCurrent,
  onOriginChange,
  onOriginFocus,
  onOriginBlur,
  onOriginClear,
  onUseCurrentPosition,
  originAddressLoading,
  destinationLoading,
  searchError,
  showAddressSuggestions,
  addressSuggestionsLoading,
  addressSuggestions,
  showOriginSuggestions,
  originSuggestionsLoading,
  originSuggestions,
}: TopBarProps) {
  const canSubmit = searchQuery.trim().length >= 3 && !destinationLoading;
  const searchRootRef = useRef<HTMLDivElement>(null);
  const searchInputRef = useRef<HTMLInputElement>(null);
  const [searchPanelOpen, setSearchPanelOpen] = useState(false);
  // La surcouche mobile implique l'ouverture du panneau de résultats.
  const searchOpen = searchPanelOpen || mobileSearchOpen;
  const [activeSuggestionIndex, setActiveSuggestionIndex] = useState(0);

  const filteredSuggestions = useMemo(() => {
    const query = normalizeSearch(globalSearchQuery);
    const matching = query
      ? globalSearchSuggestions.filter((suggestion) =>
          normalizeSearch(
            `${suggestion.title} ${suggestion.subtitle} ${suggestion.mode} ${suggestion.keywords ?? ""}`,
          ).includes(query),
        )
      : globalSearchSuggestions;

    const seen = new Set<string>();
    const perCategory = new Map<GlobalSearchSuggestion["category"], number>();
    return matching
      .filter((suggestion) => {
        // Deux lignes peuvent partager le même numéro public (ex. une C1 GTFS
        // et une C1 créée manuellement) tout en restant deux résultats distincts.
        const uniqueKey = suggestion.id;
        if (seen.has(uniqueKey)) return false;
        seen.add(uniqueKey);
        const count = perCategory.get(suggestion.category) ?? 0;
        if (count >= 4) return false;
        perCategory.set(suggestion.category, count + 1);
        return true;
      })
      .slice(0, 10);
  }, [globalSearchQuery, globalSearchSuggestions]);

  const resultCounts = useMemo(() => {
    const counts = new Map<GlobalSearchSuggestion["category"], number>();
    filteredSuggestions.forEach((suggestion) => {
      counts.set(suggestion.category, (counts.get(suggestion.category) ?? 0) + 1);
    });
    return counts;
  }, [filteredSuggestions]);

  useEffect(() => {
    const closeOnOutsideClick = (event: PointerEvent) => {
      if (!searchRootRef.current?.contains(event.target as Node)) {
        setSearchPanelOpen(false);
        onMobileSearchOpenChange(false);
      }
    };
    document.addEventListener("pointerdown", closeOnOutsideClick);
    return () => document.removeEventListener("pointerdown", closeOnOutsideClick);
  }, [onMobileSearchOpenChange]);

  // Ouverture depuis la barre du bas (mobile) : on donne le focus au champ.
  useEffect(() => {
    if (!mobileSearchOpen) return;
    searchInputRef.current?.focus();
  }, [mobileSearchOpen]);

  useEffect(() => {
    const focusGlobalSearch = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        setSearchPanelOpen(true);
        searchInputRef.current?.focus();
      }
    };
    window.addEventListener("keydown", focusGlobalSearch);
    return () => window.removeEventListener("keydown", focusGlobalSearch);
  }, []);

  function selectGlobalSuggestion(suggestion: GlobalSearchSuggestion) {
    onGlobalSearchSelect(suggestion);
    setSearchPanelOpen(false);
    onMobileSearchOpenChange(false);
    searchInputRef.current?.blur();
  }

  function handleGlobalSearchKeyDown(event: React.KeyboardEvent<HTMLInputElement>) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      setSearchPanelOpen(true);
      setActiveSuggestionIndex((index) =>
        filteredSuggestions.length ? (index + 1) % filteredSuggestions.length : 0,
      );
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setSearchPanelOpen(true);
      setActiveSuggestionIndex((index) =>
        filteredSuggestions.length
          ? (index - 1 + filteredSuggestions.length) % filteredSuggestions.length
          : 0,
      );
    } else if (event.key === "Enter" && searchOpen && filteredSuggestions.length) {
      event.preventDefault();
      selectGlobalSuggestion(
        filteredSuggestions[activeSuggestionIndex] ?? filteredSuggestions[0],
      );
    } else if (event.key === "Escape") {
      setSearchPanelOpen(false);
      onMobileSearchOpenChange(false);
      searchInputRef.current?.blur();
    }
  }

  return (
    <>
      <header
        className="absolute left-4 right-4 top-4 z-[401] flex h-14 items-center gap-2 rounded-2xl border border-white/15 bg-[#070c0ab8] px-2.5 shadow-[0_12px_32px_rgba(0,0,0,0.22)] backdrop-blur-xl sm:gap-3 sm:px-3.5"
        style={{ WebkitBackdropFilter: "blur(20px) saturate(1.25)" }}
      >
        <div className="flex min-w-0 flex-none items-center gap-2.5">
          <Link
            href="/"
            className="immersive-map-round-btn h-10 w-10 flex-none text-lg no-underline"
            aria-label="Retour à l'accueil"
          >
            ←
          </Link>
          <span className="h-6 w-px flex-none bg-white/15" aria-hidden="true" />
          <Link
            href="/"
            className="flex min-w-0 items-center gap-2.5 rounded-xl text-white no-underline"
            aria-label="Aule — Accueil"
          >
            <Image
              src="/aule-logo.png"
              alt=""
              width={36}
              height={36}
              priority
              className="h-9 w-9 flex-none rounded-xl object-cover"
            />
            <span className="min-w-0 leading-none">
              <span className="block text-sm font-bold tracking-tight">Aule</span>
              <span className="mt-1 hidden text-[10px] font-medium uppercase tracking-[0.12em] text-white/50 sm:block">
                Carte immersive
              </span>
            </span>
          </Link>
        </div>

        <div
          ref={searchRootRef}
          className={`immersive-map-search-slot${
            mobileSearchOpen ? " immersive-map-search-slot--open" : ""
          } relative mx-auto min-w-0 flex-1 sm:max-w-[560px]`}
        >
          <div
            className={`immersive-map-global-search${searchOpen ? " immersive-map-global-search--open" : ""}`}
          >
            <Search className="h-[18px] w-[18px] flex-none text-white/55" strokeWidth={1.8} />
            <input
              ref={searchInputRef}
              value={globalSearchQuery}
              onChange={(event) => {
                onGlobalSearchChange(event.target.value);
                setActiveSuggestionIndex(0);
                setSearchPanelOpen(true);
              }}
              onFocus={() => setSearchPanelOpen(true)}
              onKeyDown={handleGlobalSearchKeyDown}
              className="immersive-map-global-search-input"
              id="immersive-line-search"
              placeholder="Rechercher un arrêt ou une ligne…"
              aria-label="Rechercher un arrêt ou une ligne"
              role="combobox"
              aria-autocomplete="list"
              aria-expanded={searchOpen}
              aria-controls="immersive-global-search-results"
              aria-activedescendant={
                searchOpen && filteredSuggestions[activeSuggestionIndex]
                  ? `immersive-search-${filteredSuggestions[activeSuggestionIndex].id}`
                  : undefined
              }
              autoComplete="off"
              spellCheck={false}
            />
            {globalSearchQuery && (
              <button
                type="button"
                onClick={() => {
                  onGlobalSearchChange("");
                  setActiveSuggestionIndex(0);
                  setSearchPanelOpen(true);
                  searchInputRef.current?.focus();
                }}
                className="immersive-map-global-search-clear"
                aria-label="Effacer la recherche"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            )}
            {mobileSearchOpen && !globalSearchQuery && (
              <button
                type="button"
                onClick={() => {
                  setSearchPanelOpen(false);
                  onMobileSearchOpenChange(false);
                }}
                className="immersive-map-global-search-clear"
                aria-label="Fermer la recherche"
              >
                <X className="h-3.5 w-3.5" />
              </button>
            )}
            <span className="immersive-map-global-search-shortcut" aria-hidden="true">
              ⌘ K
            </span>
          </div>

          {searchOpen && (
            <div
              id="immersive-global-search-results"
              className="immersive-map-global-results"
              role="listbox"
            >
              {filteredSuggestions.length > 0 ? (
                filteredSuggestions.map((suggestion, index) => {
                  const showGroup =
                    index === 0 ||
                    filteredSuggestions[index - 1].category !== suggestion.category;
                  return (
                    <div key={suggestion.id}>
                      {showGroup && (
                        <div className="immersive-map-global-results-group">
                          <span>
                            {SEARCH_GROUP_LABELS[suggestion.category]}
                            {suggestion.distanceMeters != null &&
                            (suggestion.category === "stop" || suggestion.category === "line")
                              ? " à proximité"
                              : ""}
                          </span>
                          <span className="immersive-map-global-results-count">
                            {resultCounts.get(suggestion.category) ?? 0}
                          </span>
                        </div>
                      )}
                      <button
                        id={`immersive-search-${suggestion.id}`}
                        type="button"
                        role="option"
                        aria-selected={index === activeSuggestionIndex}
                        className={`immersive-map-global-result${
                          index === activeSuggestionIndex
                            ? " immersive-map-global-result--active"
                            : ""
                        }`}
                        onMouseEnter={() => setActiveSuggestionIndex(index)}
                        onClick={() => selectGlobalSuggestion(suggestion)}
                      >
                        <span
                          className={`immersive-map-global-result-icon immersive-map-global-result-icon--${suggestion.mode}`}
                          style={
                            suggestion.category === "line" && suggestion.color
                              ? {
                                  borderColor: `${suggestion.color}A6`,
                                  background: `${suggestion.color}2E`,
                                  boxShadow: `inset 0 0 0 1px ${suggestion.color}33`,
                                }
                              : undefined
                          }
                        >
                          {SEARCH_MODE_ICONS[suggestion.mode]}
                        </span>
                        <span className="min-w-0 flex-1 text-left">
                          <span className="flex items-center gap-1.5 truncate text-[13px] font-semibold text-white">
                            {suggestion.category === "line" && suggestion.color && (
                              <span
                                className="h-2 w-2 flex-none rounded-full ring-1 ring-white/25"
                                style={{ backgroundColor: suggestion.color }}
                                aria-hidden="true"
                              />
                            )}
                            <span className="truncate">{suggestion.title}</span>
                          </span>
                          <span className="mt-0.5 block truncate text-[11px] text-white/48">
                            {suggestion.subtitle}
                          </span>
                        </span>
                        <span className="text-sm text-white/28" aria-hidden="true">
                          →
                        </span>
                      </button>
                    </div>
                  );
                })
              ) : (
                <div className="px-4 py-7 text-center">
                  <div className="text-sm font-semibold text-white/75">Aucun résultat</div>
                  <div className="mt-1 text-xs text-white/40">
                    Essayez un numéro de ligne, un nom ou une catégorie.
                  </div>
                </div>
              )}
            </div>
          )}
        </div>

        {viewer ? (
          <div
            className="ml-auto inline-flex h-9 flex-none items-center gap-2 rounded-full border border-white/15 bg-white/[0.07] py-0 pl-0.5 pr-0.5 shadow-[0_8px_22px_rgba(0,0,0,0.18)] sm:h-[42px] sm:pl-1 sm:pr-3"
            aria-label={`Connecté en tant que ${viewer.displayName}`}
            title={viewer.displayName}
          >
            <span className="relative flex h-8 w-8 flex-none items-center justify-center overflow-hidden rounded-full border border-[#5fe0c4]/45 bg-[#33bfa3]/20 text-[11px] font-extrabold text-[#8cf0da] sm:h-[34px] sm:w-[34px]">
              <span aria-hidden="true">{getInitials(viewer.displayName)}</span>
              {viewer.avatarUrl && (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={viewer.avatarUrl}
                  alt=""
                  referrerPolicy="no-referrer"
                  onError={(event) => {
                    event.currentTarget.style.display = "none";
                  }}
                />
              )}
            </span>
            <span className="hidden max-w-36 truncate text-sm font-semibold text-white lg:block">
              {viewer.displayName}
            </span>
            <span
              className="hidden h-2 w-2 flex-none rounded-full bg-[#33bfa3] sm:block"
              aria-hidden="true"
            />
          </div>
        ) : (
          <Link
            href="/login"
            aria-label="Se connecter"
            title="Se connecter"
            className="ml-auto inline-flex h-9 w-9 flex-none items-center justify-center rounded-full border border-[#5fe0c4]/40 bg-[#33bfa3]/18 text-[#8cf0da] no-underline transition hover:bg-[#33bfa3]/30 sm:h-10 sm:w-auto sm:border-0 sm:bg-[#33bfa3] sm:px-[18px] sm:text-[13px] sm:font-bold sm:text-[#04211c] sm:hover:-translate-y-px sm:hover:bg-[#5fe0c4]"
          >
            <LogIn className="h-[17px] w-[17px] sm:hidden" strokeWidth={2.1} aria-hidden="true" />
            <span className="hidden sm:inline">Se connecter</span>
          </Link>
        )}
      </header>

      {showInputs && (
        <section
          className="absolute left-1/2 top-20 z-[402] w-[min(560px,calc(100vw-32px))] -translate-x-1/2 rounded-[24px] border border-white/15 bg-[#080e0ce6] p-4 shadow-[0_24px_64px_rgba(0,0,0,0.42)] backdrop-blur-2xl sm:p-5"
          style={{ WebkitBackdropFilter: "blur(24px) saturate(1.25)" }}
          aria-labelledby="route-planner-title"
        >
          <div className="mb-4 flex items-start justify-between gap-4">
            <div>
              <div className="mb-1 text-[10px] font-semibold uppercase tracking-[0.16em] text-[#5fe0c4]">
                Nouvel itinéraire
              </div>
              <h2
                id="route-planner-title"
                className="m-0 text-lg font-semibold tracking-[-0.01em] text-white"
              >
                Où allons-nous aujourd&apos;hui&nbsp;?
              </h2>
            </div>
            <button
              type="button"
              onClick={onCloseInputs}
              className="immersive-map-route-close"
              aria-label="Fermer la recherche d'itinéraire"
            >
              ✕
            </button>
          </div>

          <div className="immersive-map-route-fields">
            <label className="immersive-map-route-field">
              <span
                className="immersive-map-route-point immersive-map-route-point--origin"
                aria-hidden="true"
              >
                ●
              </span>
              <span className="min-w-0 flex-1">
                <span className="block text-[10px] font-semibold uppercase tracking-[0.12em] text-[#77807d]">
                  Départ{originIsCurrent ? " · Position actuelle" : ""}
                </span>
                <input
                  value={originAddressLoading ? "Recherche de votre adresse…" : originAddress}
                  onChange={(event) => onOriginChange(event.target.value)}
                  onFocus={onOriginFocus}
                  onBlur={onOriginBlur}
                  placeholder="Saisissez une adresse ou un arrêt"
                  className="immersive-map-route-input"
                  disabled={originAddressLoading}
                  autoComplete="off"
                  autoCorrect="off"
                  spellCheck={false}
                  role="combobox"
                  aria-autocomplete="list"
                  aria-expanded={showOriginSuggestions}
                  aria-controls="origin-address-suggestions"
                />
              </span>
              {originAddress && !originAddressLoading && (
                <button
                  type="button"
                  className="immersive-map-location-confirmed"
                  onClick={(event) => {
                    event.preventDefault();
                    onOriginClear();
                  }}
                  aria-label="Effacer le point de départ"
                  title="Effacer le point de départ"
                >
                  ✕
                </button>
              )}
              {!originAddress && !originAddressLoading && (
                <button
                  type="button"
                  className="immersive-map-location-confirmed"
                  onClick={(event) => {
                    event.preventDefault();
                    onUseCurrentPosition();
                  }}
                  aria-label="Utiliser ma position actuelle"
                  title="Utiliser ma position actuelle"
                >
                  ◎
                </button>
              )}
            </label>

            <label className="immersive-map-route-field immersive-map-route-field--destination">
              <span
                className="immersive-map-route-point immersive-map-route-point--destination"
                aria-hidden="true"
              />
              <span className="min-w-0 flex-1">
                <span className="block text-[10px] font-semibold uppercase tracking-[0.12em] text-[#77807d]">
                  Destination
                </span>
                <input
                  value={searchQuery}
                  onChange={(e) => onSearchChange(e.target.value)}
                  onKeyDown={onSearchKeyDown}
                  onFocus={onSearchFocus}
                  onBlur={onSearchBlur}
                  placeholder="Saisissez une adresse ou un lieu"
                  className="immersive-map-route-input"
                  autoComplete="off"
                  autoCorrect="off"
                  spellCheck={false}
                  role="combobox"
                  aria-autocomplete="list"
                  aria-expanded={showAddressSuggestions}
                  aria-controls="destination-address-suggestions"
                  autoFocus
                />
              </span>
            </label>
          </div>

          {showOriginSuggestions && (
            <div
              id="origin-address-suggestions"
              className="mt-2 max-h-56 overflow-y-auto rounded-2xl border border-black/10 bg-[#f7faf9] p-1.5 shadow-[0_16px_36px_rgba(0,0,0,0.28)]"
              role="listbox"
              aria-label="Points de départ suggérés"
            >
              {originSuggestionsLoading && originSuggestions.length === 0 ? (
                <div className="flex items-center gap-2.5 px-3 py-3 text-sm text-[#727b78]">
                  <span className="h-2 w-2 animate-pulse rounded-full bg-[#17a08a]" />
                  Recherche des adresses et arrêts…
                </div>
              ) : (
                originSuggestions.map((suggestion) => {
                  const [title, ...details] = suggestion.label.split(",");
                  return (
                    <button
                      key={suggestion.id}
                      type="button"
                      role="option"
                      aria-selected={false}
                      className="flex w-full items-start gap-3 rounded-xl border-0 bg-transparent px-3 py-2.5 text-left transition hover:bg-[#e8f3ef] focus:bg-[#e8f3ef] focus:outline-none"
                      onMouseDown={(event) => {
                        event.preventDefault();
                        suggestion.onPick();
                      }}
                    >
                      <span className="mt-0.5 flex h-7 w-7 flex-none items-center justify-center rounded-lg bg-[#dff2ec] text-sm text-[#168f7c]">
                        {suggestion.kind === "stop" ? "🚏" : "📍"}
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate text-sm font-semibold text-[#17201e]">{title}</span>
                        <span className="mt-0.5 block text-xs leading-snug text-[#77807d]">{details.join(",").trim()}</span>
                      </span>
                    </button>
                  );
                })
              )}
            </div>
          )}

          {showAddressSuggestions && (
            <div
              id="destination-address-suggestions"
              className="mt-2 max-h-56 overflow-y-auto rounded-2xl border border-black/10 bg-[#f7faf9] p-1.5 shadow-[0_16px_36px_rgba(0,0,0,0.28)]"
              role="listbox"
              aria-label="Adresses suggérées"
            >
              {addressSuggestionsLoading && addressSuggestions.length === 0 ? (
                <div className="flex items-center gap-2.5 px-3 py-3 text-sm text-[#727b78]">
                  <span className="h-2 w-2 animate-pulse rounded-full bg-[#17a08a]" />
                  Recherche des adresses…
                </div>
              ) : (
                addressSuggestions.map((suggestion) => {
                  const [title, ...details] = suggestion.label.split(",");
                  return (
                    <button
                      key={suggestion.id}
                      type="button"
                      role="option"
                      aria-selected={false}
                      className="flex w-full items-start gap-3 rounded-xl border-0 bg-transparent px-3 py-2.5 text-left transition hover:bg-[#e8f3ef] focus:bg-[#e8f3ef] focus:outline-none"
                      onMouseDown={(event) => {
                        event.preventDefault();
                        suggestion.onPick();
                      }}
                    >
                      <span className="mt-0.5 flex h-7 w-7 flex-none items-center justify-center rounded-lg bg-[#dff2ec] text-sm text-[#168f7c]">
                        {suggestion.kind === "stop" ? "🚏" : "📍"}
                      </span>
                      <span className="min-w-0">
                        <span className="block truncate text-sm font-semibold text-[#17201e]">
                          {title}
                        </span>
                        <span className="mt-0.5 block text-xs leading-snug text-[#77807d]">
                          {details.join(",").trim()}
                        </span>
                      </span>
                    </button>
                  );
                })
              )}
            </div>
          )}

          {searchError && (
            <p className="mb-0 mt-2.5 text-xs font-medium text-[#ffb6a8]" role="alert">
              {searchError}
            </p>
          )}

          <div className="mt-4 flex items-center justify-between gap-3">
            <p className="m-0 hidden text-xs text-white/45 sm:block">
              Appuyez sur Entrée pour calculer
            </p>
            <button
              type="button"
              onClick={onSearchSubmit}
              disabled={!canSubmit}
              className="immersive-map-route-submit ml-auto"
            >
              {destinationLoading ? "Recherche…" : "Calculer l’itinéraire"}
              {!destinationLoading && <span aria-hidden="true">→</span>}
            </button>
          </div>
        </section>
      )}
    </>
  );
}
