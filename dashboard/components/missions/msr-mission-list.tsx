"use client";

import { ChevronDown, Clock, MapPin, Users } from "lucide-react";
import type { MsrMissionDemo } from "@/lib/msr-mock-data";
import {
  displayStatusColor,
  displayStatusLabel,
  getTeamById,
  priorityColor,
  priorityLabel,
} from "@/lib/msr-mock-data";

interface MsrMissionListProps {
  missions: MsrMissionDemo[];
  selectedId: string | null;
  onSelect: (id: string) => void;
}

export function MsrMissionList({
  missions,
  selectedId,
  onSelect,
}: MsrMissionListProps) {
  return (
    <div className="msr-mission-list-panel">
      <div className="msr-mission-list-header">
        <div className="flex items-center gap-2">
          <h2 className="msr-panel-title">Missions</h2>
          <span className="msr-count-badge">{missions.length}</span>
        </div>
        <button type="button" className="msr-sort-btn">
          Trier par: Plus récentes
          <ChevronDown className="h-3.5 w-3.5" />
        </button>
      </div>

      <div className="msr-mission-list-scroll">
        {missions.map((mission) => {
          const team = getTeamById(mission.teamId);
          const isSelected = mission.id === selectedId;
          const statusColor = displayStatusColor(mission.status);
          const prioColor = priorityColor(mission.priority);

          return (
            <button
              key={mission.id}
              type="button"
              className={`msr-mission-card${isSelected ? " msr-mission-card--selected" : ""}`}
              onClick={() => onSelect(mission.id)}
            >
              <div className="msr-mission-card-top">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="msr-mission-card-title">{mission.title}</span>
                  <span
                    className="msr-status-badge"
                    style={{
                      background: `${statusColor}22`,
                      color: statusColor,
                      borderColor: `${statusColor}44`,
                    }}
                  >
                    {displayStatusLabel(mission.status)}
                  </span>
                </div>
                {mission.remainingTime && (
                  <span className="msr-mission-remaining">{mission.remainingTime}</span>
                )}
              </div>

              <div className="msr-mission-card-meta">
                <span className="msr-mission-meta-item">
                  <Users className="h-3.5 w-3.5" />
                  {team?.name}
                </span>
                <span className="msr-mission-meta-item">
                  <MapPin className="h-3.5 w-3.5" />
                  {mission.zoneLabel}
                </span>
                <span className="msr-mission-meta-item">
                  <Clock className="h-3.5 w-3.5" />
                  {mission.startTime} – {mission.endTime}
                </span>
                <span className="msr-mission-meta-item">
                  <Users className="h-3.5 w-3.5" />
                  {mission.agentCount} agents
                </span>
              </div>

              <div className="msr-mission-card-footer">
                <span
                  className="msr-priority-badge"
                  style={{ color: prioColor }}
                >
                  ● {priorityLabel(mission.priority)}
                </span>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}
