"use client";

import { CarTaxiFront, Route, ShoppingBag, SlidersHorizontal } from "lucide-react";

type BottomNavProps = {
  visible: boolean;
  onRoute: () => void;
  onRide: () => void;
  onShop: () => void;
  filtersOpen: boolean;
  onToggleFilters: () => void;
};

export function BottomNav({
  visible,
  onRoute,
  onRide,
  onShop,
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
      <button type="button" onClick={onRide} className="immersive-map-bottom-nav-btn">
        <span className="immersive-map-bottom-nav-icon" aria-hidden="true">
          <CarTaxiFront size={20} strokeWidth={2.2} />
        </span>
        <span>Course</span>
      </button>
      <button type="button" onClick={onShop} className="immersive-map-bottom-nav-btn">
        <span className="immersive-map-bottom-nav-icon" aria-hidden="true">
          <ShoppingBag size={20} strokeWidth={2.2} />
        </span>
        <span>Commerces</span>
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
