"use client";

export type MsrWorkspaceTab = "plans" | "missions";

interface MsrWorkspaceTabsProps {
  active: MsrWorkspaceTab;
  onChange: (tab: MsrWorkspaceTab) => void;
}

export function MsrWorkspaceTabs({ active, onChange }: MsrWorkspaceTabsProps) {
  return (
    <div className="msr-workspace-tabs" role="tablist">
      <button
        type="button"
        role="tab"
        aria-selected={active === "plans"}
        className={`msr-workspace-tab${active === "plans" ? " msr-workspace-tab--active" : ""}`}
        onClick={() => onChange("plans")}
      >
        Plans de contrôle
      </button>
      <button
        type="button"
        role="tab"
        aria-selected={active === "missions"}
        className={`msr-workspace-tab${active === "missions" ? " msr-workspace-tab--active" : ""}`}
        onClick={() => onChange("missions")}
      >
        Missions
      </button>
    </div>
  );
}
