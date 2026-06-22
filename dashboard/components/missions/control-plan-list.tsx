"use client";

import { Calendar, Target, Users } from "lucide-react";
import type { ControlPlanView } from "@/lib/control-plans/types";
import {
  controlPlanStatusColor,
  controlPlanStatusLabel,
  formatPlanPeriod,
} from "@/lib/control-plans/types";

interface ControlPlanListProps {
  plans: ControlPlanView[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}

export function ControlPlanList({
  plans,
  selectedId,
  onSelect,
}: ControlPlanListProps) {
  return (
    <div className="msr-mission-list-panel">
      <div className="msr-mission-list-header">
        <div className="flex items-center gap-2">
          <h2 className="msr-panel-title">Plans de contrôle</h2>
          <span className="msr-count-badge">{plans.length}</span>
        </div>
      </div>

      <div className="msr-mission-list-scroll">
        {plans.map((plan) => {
          const isSelected = plan.id === selectedId;
          const statusColor = controlPlanStatusColor(plan.status);

          return (
            <button
              key={plan.id}
              type="button"
              className={`msr-mission-card msr-plan-card${isSelected ? " msr-mission-card--selected" : ""}`}
              onClick={() => onSelect(plan.id)}
            >
              <div className="msr-mission-card-top">
                <span className="msr-mission-card-title">{plan.name}</span>
                <span
                  className="msr-status-badge"
                  style={{
                    background: `${statusColor}22`,
                    color: statusColor,
                    borderColor: `${statusColor}44`,
                  }}
                >
                  {controlPlanStatusLabel(plan.status)}
                </span>
              </div>

              <p className="msr-plan-objective">
                <Target className="h-3.5 w-3.5 shrink-0" />
                {plan.objective}
              </p>

              <div className="msr-mission-card-meta">
                <span className="msr-mission-meta-item">
                  <Users className="h-3.5 w-3.5" />
                  {plan.manager}
                </span>
                <span className="msr-mission-meta-item">
                  <Calendar className="h-3.5 w-3.5" />
                  {formatPlanPeriod(plan.start_date, plan.end_date)}
                </span>
              </div>

              <div className="msr-plan-stats">
                <span>{plan.missionCount} missions</span>
                <span>{plan.teamCount} équipes</span>
                <span>{plan.agentCount} agents</span>
                <span>{plan.zoneCount} zones</span>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}
