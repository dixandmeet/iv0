"use client";

import { useCallback, useMemo, useState } from "react";
import type { MsrFilters } from "@/components/missions/msr-action-bar";
import { MsrCreateMissionWizard } from "@/components/missions/msr-create-mission-wizard";
import { MsrKpiCards } from "@/components/missions/msr-kpi-cards";
import { MsrMissionDetailPanel } from "@/components/missions/msr-mission-detail-panel";
import { MsrMissionList } from "@/components/missions/msr-mission-list";
import {
  MsrMissionsMap,
  type MsrMapLayerToggles,
} from "@/components/missions/msr-missions-map";
import {
  MSR_INCIDENTS,
  MSR_MISSIONS,
  MSR_STATIONS,
  MSR_ZONES,
} from "@/lib/msr-mock-data";
import { useMsrResources } from "@/hooks/use-msr-resources";

type DetailTab = "details" | "live" | "events";

interface MsrMissionsViewProps {
  search: string;
  filters: MsrFilters;
  showFilters: boolean;
  onRefresh: () => void;
  showWizard: boolean;
  onShowWizard: (show: boolean) => void;
}

export function MsrMissionsView({
  search,
  filters,
  showFilters,
  onRefresh,
  showWizard,
  onShowWizard,
}: MsrMissionsViewProps) {
  const { agents } = useMsrResources();
  const [selectedMissionId, setSelectedMissionId] = useState<string | null>("m1");
  const [detailTab, setDetailTab] = useState<DetailTab>("details");
  const [mapLayers, setMapLayers] = useState<MsrMapLayerToggles>({
    zones: true,
    agents: true,
    incidents: true,
    stations: true,
  });

  const filteredMissions = useMemo(() => {
    return MSR_MISSIONS.filter((m) => {
      if (search) {
        const q = search.toLowerCase();
        const match =
          m.title.toLowerCase().includes(q) ||
          m.zoneLabel.toLowerCase().includes(q);
        if (!match) return false;
      }
      if (filters.status !== "all" && m.status !== filters.status) return false;
      if (filters.teamId !== "all" && m.teamId !== filters.teamId) return false;
      if (filters.zoneId !== "all") {
        const zone = MSR_ZONES.find((z) => z.id === filters.zoneId);
        if (zone && zone.teamId !== m.teamId) return false;
      }
      return true;
    });
  }, [search, filters]);

  const selectedMission = useMemo(
    () => MSR_MISSIONS.find((m) => m.id === selectedMissionId) ?? null,
    [selectedMissionId],
  );

  const handleLayerToggle = useCallback((key: keyof MsrMapLayerToggles) => {
    setMapLayers((prev) => ({ ...prev, [key]: !prev[key] }));
  }, []);

  return (
    <>
      <MsrKpiCards />

      <div className="msr-main-grid">
        <MsrMissionList
          missions={filteredMissions}
          selectedId={selectedMissionId}
          onSelect={(id) => {
            setSelectedMissionId(id);
            setDetailTab("details");
          }}
        />

        <MsrMissionsMap
          zones={MSR_ZONES}
          agents={agents}
          incidents={MSR_INCIDENTS}
          stations={MSR_STATIONS}
          layers={mapLayers}
          onLayerToggle={handleLayerToggle}
          selectedMissionTeamId={selectedMission?.teamId}
        />

        {selectedMission ? (
          <MsrMissionDetailPanel
            mission={selectedMission}
            activeTab={detailTab}
            onTabChange={setDetailTab}
            onClose={() => setSelectedMissionId(null)}
          />
        ) : (
          <div className="msr-detail-panel msr-detail-panel--empty">
            <p className="text-sm text-[#64748B]">
              Sélectionnez une mission pour afficher les détails.
            </p>
          </div>
        )}
      </div>

      <MsrCreateMissionWizard
        open={showWizard}
        onClose={() => onShowWizard(false)}
      />
    </>
  );
}
