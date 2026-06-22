"use client";

import { useCallback, useMemo, useState } from "react";
import { ControlPlanCalendar } from "@/components/missions/control-plan-calendar";
import { ControlPlanCreateWizard } from "@/components/missions/control-plan-create-wizard";
import { ControlPlanDetailPanel } from "@/components/missions/control-plan-detail-panel";
import { ControlPlanKpiCards } from "@/components/missions/control-plan-kpi-cards";
import { ControlPlanList } from "@/components/missions/control-plan-list";
import {
  MsrMissionsMap,
  type MsrMapLayerToggles,
} from "@/components/missions/msr-missions-map";
import { CONTROL_PLANS } from "@/lib/control-plans/mock-data";
import type { PlanFilters } from "@/components/missions/msr-action-bar";
import { useMsrResources } from "@/hooks/use-msr-resources";
import { MSR_INCIDENTS, MSR_STATIONS, MSR_ZONES } from "@/lib/msr-mock-data";

interface MsrPlansViewProps {
  search: string;
  filters: PlanFilters;
  showWizard: boolean;
  onShowWizard: (show: boolean) => void;
}

export function MsrPlansView({
  search,
  filters,
  showWizard,
  onShowWizard,
}: MsrPlansViewProps) {
  const { agents } = useMsrResources();
  const [plans, setPlans] = useState(CONTROL_PLANS);
  const [selectedPlanId, setSelectedPlanId] = useState<string | null>("cp1");
  const [calendarWeek, setCalendarWeek] = useState(() => new Date("2025-09-15"));
  const [mapLayers, setMapLayers] = useState<MsrMapLayerToggles>({
    zones: true,
    agents: true,
    incidents: true,
    stations: true,
  });

  const filteredPlans = useMemo(() => {
    return plans.filter((p) => {
      if (search) {
        const q = search.toLowerCase();
        const match =
          p.name.toLowerCase().includes(q) ||
          p.objective.toLowerCase().includes(q) ||
          p.manager.toLowerCase().includes(q);
        if (!match) return false;
      }
      if (filters.status !== "all" && p.status !== filters.status) return false;
      if (filters.date) {
        const d = filters.date;
        if (d < p.start_date || d > p.end_date) return false;
      }
      return true;
    });
  }, [plans, search, filters]);

  const selectedPlan = useMemo(
    () => plans.find((p) => p.id === selectedPlanId) ?? null,
    [plans, selectedPlanId],
  );

  const handleLayerToggle = useCallback((key: keyof MsrMapLayerToggles) => {
    setMapLayers((prev) => ({ ...prev, [key]: !prev[key] }));
  }, []);

  function handleInstructionsChange(planId: string, instructions: string[]) {
    setPlans((prev) =>
      prev.map((p) => (p.id === planId ? { ...p, instructions } : p)),
    );
  }

  return (
    <>
      <ControlPlanKpiCards />

      <div className="msr-plans-grid">
        <ControlPlanList
          plans={filteredPlans}
          selectedId={selectedPlanId}
          onSelect={setSelectedPlanId}
        />

        <div className="msr-plans-center">
          <ControlPlanCalendar
            missions={selectedPlan?.missions ?? []}
            weekStart={calendarWeek}
            onWeekChange={setCalendarWeek}
          />
          <MsrMissionsMap
            zones={MSR_ZONES}
            agents={agents}
            incidents={MSR_INCIDENTS}
            stations={MSR_STATIONS}
            layers={mapLayers}
            onLayerToggle={handleLayerToggle}
            selectedMissionTeamId={null}
          />
        </div>

        {selectedPlan ? (
          <ControlPlanDetailPanel
            plan={selectedPlan}
            onClose={() => setSelectedPlanId(null)}
            onInstructionsChange={(instructions) =>
              handleInstructionsChange(selectedPlan.id, instructions)
            }
          />
        ) : (
          <div className="msr-detail-panel msr-detail-panel--empty">
            <p className="text-sm text-[#64748B]">
              Sélectionnez un plan de contrôle pour afficher les détails.
            </p>
          </div>
        )}
      </div>

      <ControlPlanCreateWizard
        open={showWizard}
        onClose={() => onShowWizard(false)}
      />
    </>
  );
}
