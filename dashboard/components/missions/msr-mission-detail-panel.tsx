"use client";

import { Pencil, X } from "lucide-react";
import type { MsrMissionDemo } from "@/lib/msr-mock-data";
import {
  displayStatusColor,
  displayStatusLabel,
  priorityColor,
  priorityLabel,
} from "@/lib/msr-mock-data";
import {
  getAgentsForMissionFromList,
  getTeamByIdFromList,
  useMsrResources,
} from "@/hooks/use-msr-resources";

type DetailTab = "details" | "live" | "events";

interface MsrMissionDetailPanelProps {
  mission: MsrMissionDemo;
  activeTab: DetailTab;
  onTabChange: (tab: DetailTab) => void;
  onClose: () => void;
}

export function MsrMissionDetailPanel({
  mission,
  activeTab,
  onTabChange,
  onClose,
}: MsrMissionDetailPanelProps) {
  const { agents, teams } = useMsrResources();
  const team = getTeamByIdFromList(teams, mission.teamId);
  const missionAgents = getAgentsForMissionFromList(agents, mission.agentIds);
  const statusColor = displayStatusColor(mission.status);
  const prioColor = priorityColor(mission.priority);

  const tabs: { id: DetailTab; label: string }[] = [
    { id: "details", label: "Détails" },
    { id: "live", label: "Suivi en direct" },
    { id: "events", label: "Événements" },
  ];

  return (
    <div className="msr-detail-panel">
      <div className="msr-detail-header">
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="msr-detail-title">{mission.title}</h2>
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
        </div>
        <button
          type="button"
          className="msr-detail-close"
          onClick={onClose}
          aria-label="Fermer"
        >
          <X className="h-4 w-4" />
        </button>
      </div>

      <div className="msr-detail-tabs">
        {tabs.map((tab) => (
          <button
            key={tab.id}
            type="button"
            className={`msr-detail-tab${activeTab === tab.id ? " msr-detail-tab--active" : ""}`}
            onClick={() => onTabChange(tab.id)}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div className="msr-detail-scroll">
        {activeTab === "details" && (
          <>
            <section className="msr-detail-section">
              <h3 className="msr-detail-section-title">Informations générales</h3>
              <p className="msr-detail-text">{mission.description}</p>
              <div className="msr-detail-row">
                <span className="msr-detail-label">Priorité</span>
                <span
                  className="msr-priority-badge"
                  style={{ color: prioColor }}
                >
                  ● {priorityLabel(mission.priority)}
                </span>
              </div>
              <div className="msr-detail-row">
                <span className="msr-detail-label">Statut</span>
                <span style={{ color: statusColor }}>
                  {displayStatusLabel(mission.status)}
                </span>
              </div>
            </section>

            <section className="msr-detail-section">
              <h3 className="msr-detail-section-title">Équipe</h3>
              <p className="msr-detail-team-name">{team?.name}</p>
              <div className="msr-detail-manager">
                <div className="msr-agent-avatar msr-agent-avatar--lg">
                  {team?.manager.initials}
                </div>
                <div>
                  <p className="msr-detail-label">Responsable</p>
                  <p className="msr-detail-text">{team?.manager.name}</p>
                </div>
              </div>
              <div className="msr-agent-avatars">
                {missionAgents.map((agent) => (
                  <div
                    key={agent.id}
                    className="msr-agent-avatar"
                    title={agent.name}
                  >
                    {agent.initials}
                  </div>
                ))}
              </div>
            </section>

            <section className="msr-detail-section">
              <h3 className="msr-detail-section-title">Zone d&apos;intervention</h3>
              <div className="msr-mini-map" aria-hidden />
              <div className="msr-detail-row">
                <span className="msr-detail-label">Lignes concernées</span>
                <span>{mission.lines.join(", ")}</span>
              </div>
              <div className="msr-detail-row">
                <span className="msr-detail-label">Stations concernées</span>
                <span>{mission.stationCount}</span>
              </div>
              <button type="button" className="msr-link-btn">
                Voir la zone sur la carte
              </button>
            </section>

            <section className="msr-detail-section">
              <div className="msr-detail-section-header">
                <h3 className="msr-detail-section-title">Consignes</h3>
                <button type="button" className="msr-icon-btn" aria-label="Modifier">
                  <Pencil className="h-3.5 w-3.5" />
                </button>
              </div>
              <ul className="msr-instructions-list">
                {mission.instructions.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </section>

            <section className="msr-detail-section">
              <h3 className="msr-detail-section-title">Horaires</h3>
              <div className="msr-detail-row">
                <span className="msr-detail-label">Début</span>
                <span>{mission.startLabel}</span>
              </div>
              <div className="msr-detail-row">
                <span className="msr-detail-label">Fin</span>
                <span>{mission.endLabel}</span>
              </div>
              <div className="msr-detail-row">
                <span className="msr-detail-label">Durée</span>
                <span>{mission.duration}</span>
              </div>
            </section>
          </>
        )}

        {activeTab === "live" && (
          <section className="msr-detail-section">
            <h3 className="msr-detail-section-title">Suivi en direct</h3>
            <p className="msr-detail-text">
              Position des {mission.agentCount} agents en temps réel sur la zone{" "}
              {mission.zoneLabel}. Dernière mise à jour il y a quelques secondes.
            </p>
            <div className="msr-live-agents">
              {missionAgents.map((agent) => (
                <div key={agent.id} className="msr-live-agent-row">
                  <div className="msr-agent-avatar">{agent.initials}</div>
                  <div className="min-w-0 flex-1">
                    <p className="text-sm font-medium text-white">{agent.name}</p>
                    <p className="text-xs text-[#64748B]">
                      {agent.available ? "En patrouille" : "Hors ligne"}
                    </p>
                  </div>
                  <span
                    className={`msr-live-dot${agent.available ? " msr-live-dot--on" : ""}`}
                  />
                </div>
              ))}
            </div>
          </section>
        )}

        {activeTab === "events" && (
          <section className="msr-detail-section">
            <h3 className="msr-detail-section-title">Événements</h3>
            <div className="msr-events-list">
              <div className="msr-event-item">
                <span className="msr-event-time">07:02</span>
                <span className="msr-event-text">Mission démarrée — équipe positionnée</span>
              </div>
              <div className="msr-event-item">
                <span className="msr-event-time">08:15</span>
                <span className="msr-event-text">Incident signalé — affluence Commerce</span>
              </div>
              <div className="msr-event-item">
                <span className="msr-event-time">09:30</span>
                <span className="msr-event-text">Rapport intermédiaire transmis</span>
              </div>
            </div>
          </section>
        )}
      </div>
    </div>
  );
}
