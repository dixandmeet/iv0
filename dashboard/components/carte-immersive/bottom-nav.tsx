"use client";

import { Route } from "lucide-react";

type BottomNavProps = {
  visible: boolean;
  onRoute: () => void;
};

export function BottomNav({
  visible,
  onRoute,
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
        <span>Où allons-nous</span>
      </button>
    </nav>
  );
}
