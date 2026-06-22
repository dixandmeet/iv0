"use client";

import { useCallback, useState } from "react";
import { MsrAddAgentModal } from "@/components/missions/msr-add-agent-modal";
import {
  DEFAULT_MSR_FILTERS,
  DEFAULT_PLAN_FILTERS,
  MsrActionBar,
  type MsrFilters,
  type PlanFilters,
} from "@/components/missions/msr-action-bar";
import { MsrCreateTeamModal } from "@/components/missions/msr-create-team-modal";
import { MsrMissionsView } from "@/components/missions/msr-missions-view";
import { MsrPlansView } from "@/components/missions/msr-plans-view";
import {
  MsrWorkspaceTabs,
  type MsrWorkspaceTab,
} from "@/components/missions/msr-workspace-tabs";
import { MsrResourcesProvider } from "@/hooks/use-msr-resources";
import { CONTROL_PLANS } from "@/lib/control-plans/mock-data";
import { MSR_MISSIONS } from "@/lib/msr-mock-data";

export function MissionsPageContent() {
  return (
    <MsrResourcesProvider>
      <MissionsPageInner />
    </MsrResourcesProvider>
  );
}

function MissionsPageInner() {
  const [activeTab, setActiveTab] = useState<MsrWorkspaceTab>("plans");
  const [search, setSearch] = useState("");
  const [missionFilters, setMissionFilters] = useState<MsrFilters>(DEFAULT_MSR_FILTERS);
  const [planFilters, setPlanFilters] = useState<PlanFilters>(DEFAULT_PLAN_FILTERS);
  const [showFilters, setShowFilters] = useState(false);
  const [showWizard, setShowWizard] = useState(false);
  const [showAddAgent, setShowAddAgent] = useState(false);
  const [showCreateTeam, setShowCreateTeam] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [lastUpdated, setLastUpdated] = useState(() => new Date());

  const activeCount =
    activeTab === "plans"
      ? CONTROL_PLANS.filter((p) => p.status === "active").length
      : MSR_MISSIONS.filter((m) => m.status === "in_progress").length;

  const handleRefresh = useCallback(() => {
    setLastUpdated(new Date());
  }, []);

  function showSuccess(message: string) {
    setToast(message);
    setLastUpdated(new Date());
    window.setTimeout(() => setToast(null), 4000);
  }

  return (
    <main className="msr-page" style={{ gridColumn: "2 / -1" }}>
      {toast && (
        <div className="msr-toast" role="status">
          {toast}
        </div>
      )}

      <header className="msr-header">
        <div>
          <h1 className="msr-title">Missions MSR</h1>
          <p className="msr-subtitle">
            Centre de pilotage des patrouilles et de la supervision du réseau.
          </p>
        </div>
        <div className="msr-header-meta">
          <span className="msr-active-badge">{activeCount} active(s)</span>
          <span className="msr-timestamp">
            MAJ {lastUpdated.toLocaleTimeString("fr-FR")}
          </span>
        </div>
      </header>

      <MsrWorkspaceTabs active={activeTab} onChange={setActiveTab} />

      <MsrActionBar
        mode={activeTab}
        search={search}
        onSearchChange={setSearch}
        missionFilters={missionFilters}
        onMissionFiltersChange={setMissionFilters}
        planFilters={planFilters}
        onPlanFiltersChange={setPlanFilters}
        showFilters={showFilters}
        onToggleFilters={() => setShowFilters((v) => !v)}
        onRefresh={handleRefresh}
        onPrimaryAction={() => setShowWizard(true)}
        onAddAgent={() => setShowAddAgent(true)}
        onCreateTeam={() => setShowCreateTeam(true)}
      />

      {activeTab === "plans" ? (
        <MsrPlansView
          search={search}
          filters={planFilters}
          showWizard={showWizard}
          onShowWizard={setShowWizard}
        />
      ) : (
        <MsrMissionsView
          search={search}
          filters={missionFilters}
          showFilters={showFilters}
          onRefresh={handleRefresh}
          showWizard={showWizard}
          onShowWizard={setShowWizard}
        />
      )}

      <MsrAddAgentModal
        open={showAddAgent}
        onClose={() => setShowAddAgent(false)}
        onSuccess={(name) => showSuccess(`Agent « ${name} » ajouté avec succès.`)}
      />

      <MsrCreateTeamModal
        open={showCreateTeam}
        onClose={() => setShowCreateTeam(false)}
        onSuccess={(name) => showSuccess(`Équipe « ${name} » créée avec succès.`)}
      />
    </main>
  );
}
