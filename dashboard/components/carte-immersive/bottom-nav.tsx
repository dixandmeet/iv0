"use client";

import { Navigation, Route, SlidersHorizontal } from "lucide-react";

type BottomNavProps = {
  visible: boolean;
  onRoute: () => void;
  onGuide: () => void;
  filtersOpen: boolean;
  onToggleFilters: () => void;
};

export function BottomNav({
  visible,
  onRoute,
  onGuide,
  filtersOpen,
  onToggleFilters,
}: BottomNavProps) {
  if (!visible) return null;

  return (
    <nav
      className="immersive-map-bottom-nav immersive-map-panel-anim"
      aria-label="Actions rapides"
    >
      <button type="button" onClick={onRoute} className="immersive-map-bottom-nav-btn">
        <span className="immersive-map-bottom-nav-icon" aria-hidden="true">
          <Route size={20} strokeWidth={2.2} />
        </span>
        <span>Itinéraire</span>
      </button>
      <button type="button" onClick={onGuide} className="immersive-map-bottom-nav-btn">
        <span className="immersive-map-bottom-nav-icon" aria-hidden="true">
          <Navigation size={20} strokeWidth={2.2} />
        </span>
        <span>Guidage</span>
      </button>
      <button
        type="button"
        onClick={onToggleFilters}
        className={`immersive-map-bottom-nav-btn${
          filtersOpen ? " immersive-map-bottom-nav-btn--active" : ""
        }`}
        aria-pressed={filtersOpen}
      >
        <span className="immersive-map-bottom-nav-icon" aria-hidden="true">
          <SlidersHorizontal size={20} strokeWidth={2.2} />
        </span>
        <span>Afficher</span>
      </button>
    </nav>
  );
}
