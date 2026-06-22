"use client";

import type { DriversPageTab } from "@/lib/drivers-types";

interface DriversTabsProps {
  activeTab: DriversPageTab;
  onTabChange: (tab: DriversPageTab) => void;
  pendingCount: number;
  sessionCount: number;
  rosterCount: number;
}

const TABS: { id: DriversPageTab; label: string }[] = [
  { id: "sessions", label: "Sessions actives" },
  { id: "roster", label: "Annuaire" },
  { id: "requests", label: "Demandes" },
];

export function DriversTabs({
  activeTab,
  onTabChange,
  pendingCount,
  sessionCount,
  rosterCount,
}: DriversTabsProps) {
  const counts: Record<DriversPageTab, number> = {
    sessions: sessionCount,
    roster: rosterCount,
    requests: pendingCount,
  };

  return (
    <nav className="stops-tab-nav mb-6">
      {TABS.map((tab) => (
        <button
          key={tab.id}
          type="button"
          className={`stops-tab-btn${activeTab === tab.id ? " stops-tab-btn--active" : ""}`}
          onClick={() => onTabChange(tab.id)}
        >
          {tab.label}
          <span
            className={`station-tab-badge${tab.id === "requests" && pendingCount > 0 ? " station-tab-badge--warn" : ""}`}
          >
            {counts[tab.id]}
          </span>
        </button>
      ))}
    </nav>
  );
}
