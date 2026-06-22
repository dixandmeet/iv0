"use client";

import type { StopAuditEntry, StopDeparture, StopListItem, StopServingLine } from "@/lib/stops-types";
import type { NetworkIncident } from "@/lib/types";
import { StopInfoTab } from "@/components/stops/stop-info-tab";
import { StopLinesTab } from "@/components/stops/stop-lines-tab";
import { StopSchedulesTab } from "@/components/stops/stop-schedules-tab";
import { StopIncidentsTab } from "@/components/stops/stop-incidents-tab";
import { StopHistoryTab } from "@/components/stops/stop-history-tab";

export type StopDetailTab = "info" | "lines" | "schedules" | "incidents" | "history";

const TABS: { id: StopDetailTab; label: string }[] = [
  { id: "info", label: "Informations" },
  { id: "lines", label: "Lignes" },
  { id: "schedules", label: "Horaires" },
  { id: "incidents", label: "Incidents" },
  { id: "history", label: "Historique" },
];

interface StopDetailTabsProps {
  activeTab: StopDetailTab;
  onTabChange: (tab: StopDetailTab) => void;
  stop: StopListItem;
  lines: StopServingLine[];
  departures: StopDeparture[];
  incidents: NetworkIncident[];
  history: StopAuditEntry[];
  coordinates: [number, number] | null;
  onRefresh: () => void;
  loading?: boolean;
}

export function StopDetailTabs({
  activeTab,
  onTabChange,
  stop,
  lines,
  departures,
  incidents,
  history,
  coordinates,
  onRefresh,
  loading = false,
}: StopDetailTabsProps) {
  return (
    <div className="stops-detail-tabs">
      <nav className="stops-tab-nav">
        {TABS.map((tab) => (
          <button
            key={tab.id}
            type="button"
            className={`stops-tab-btn${activeTab === tab.id ? " stops-tab-btn--active" : ""}`}
            onClick={() => onTabChange(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </nav>
      <div className="stops-tab-content">
        {activeTab === "info" && <StopInfoTab stop={stop} />}
        {activeTab === "lines" && (
          <StopLinesTab lines={lines} platformCount={stop.platform ? 1 : 1} loading={loading} />
        )}
        {activeTab === "schedules" && (
          <StopSchedulesTab departures={departures} loading={loading} />
        )}
        {activeTab === "incidents" && (
          <StopIncidentsTab
            stopId={stop.code}
            stopUuid={stop.id}
            stopName={stop.name ?? stop.station_name ?? stop.code}
            incidents={incidents}
            coordinates={coordinates}
            onRefresh={onRefresh}
          />
        )}
        {activeTab === "history" && <StopHistoryTab history={history} />}
      </div>
    </div>
  );
}
