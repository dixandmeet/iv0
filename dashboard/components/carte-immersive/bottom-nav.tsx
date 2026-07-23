"use client";

import { Radar, Route, Search } from "lucide-react";

type BottomNavProps = {
  visible: boolean;
  onSearch: () => void;
  onRoute: () => void;
  onCorrespondances: () => void;
};

export function BottomNav({
  visible,
  onSearch,
  onRoute,
  onCorrespondances,
}: BottomNavProps) {
  if (!visible) return null;

  return (
    <nav
      className="immersive-map-bottom-nav immersive-map-panel-anim"
      aria-label="Actions rapides"
    >
      <button type="button" onClick={onSearch} className="immersive-map-bottom-nav-btn">
        <span className="immersive-map-bottom-nav-icon" aria-hidden="true">
          <Search size={20} strokeWidth={2.2} />
        </span>
        <span>Rechercher</span>
      </button>
      <button type="button" onClick={onRoute} className="immersive-map-bottom-nav-btn">
        <span className="immersive-map-bottom-nav-icon" aria-hidden="true">
          <Route size={20} strokeWidth={2.2} />
        </span>
        <span>Itinéraire</span>
      </button>
      <button
        type="button"
        onClick={onCorrespondances}
        className="immersive-map-bottom-nav-btn"
      >
        <span className="immersive-map-bottom-nav-icon" aria-hidden="true">
          <Radar size={20} strokeWidth={2.2} />
        </span>
        <span>Correspondances</span>
      </button>
    </nav>
  );
}
