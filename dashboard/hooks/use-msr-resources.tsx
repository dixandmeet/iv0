"use client";

import {
  createContext,
  useCallback,
  useContext,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import {
  MSR_AGENTS,
  MSR_TEAMS,
  MSR_ZONES,
  type MsrAgent,
  type MsrTeam,
} from "@/lib/msr-mock-data";
import { NANTES_CENTER } from "@/lib/landing-map-style";

function initialsFromName(name: string): string {
  const parts = name.trim().split(/\s+/);
  if (parts.length >= 2) {
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }
  return name.slice(0, 2).toUpperCase();
}

function slugId(prefix: string, name: string): string {
  const base = name
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
  return `${prefix}-${base || Date.now()}`;
}

function defaultPositionForTeam(teamId: string): [number, number] {
  const zone = MSR_ZONES.find((z) => z.teamId === teamId);
  if (zone) {
    const lngs = zone.coordinates.map(([lng]) => lng);
    const lats = zone.coordinates.map(([, lat]) => lat);
    return [(Math.min(...lngs) + Math.max(...lngs)) / 2, (Math.min(...lats) + Math.max(...lats)) / 2];
  }
  return NANTES_CENTER;
}

export interface AddAgentInput {
  name: string;
  teamId: string;
  available?: boolean;
}

export interface AddTeamInput {
  name: string;
  managerName: string;
  color: string;
  zoneId?: string;
}

interface MsrResourcesContextValue {
  agents: MsrAgent[];
  teams: MsrTeam[];
  addAgent: (input: AddAgentInput) => MsrAgent;
  addTeam: (input: AddTeamInput) => MsrTeam;
}

const MsrResourcesContext = createContext<MsrResourcesContextValue | null>(null);

export function MsrResourcesProvider({ children }: { children: ReactNode }) {
  const [agents, setAgents] = useState<MsrAgent[]>(() => [...MSR_AGENTS]);
  const [teams, setTeams] = useState<MsrTeam[]>(() => [...MSR_TEAMS]);

  const addAgent = useCallback((input: AddAgentInput): MsrAgent => {
    const agent: MsrAgent = {
      id: slugId("a", input.name),
      name: input.name.trim(),
      initials: initialsFromName(input.name),
      available: input.available ?? true,
      teamId: input.teamId,
      position: defaultPositionForTeam(input.teamId),
    };
    setAgents((prev) => [...prev, agent]);
    return agent;
  }, []);

  const addTeam = useCallback((input: AddTeamInput): MsrTeam => {
    const id = slugId("team", input.name);
    const team: MsrTeam = {
      id,
      name: input.name.trim(),
      manager: {
        name: input.managerName.trim(),
        initials: initialsFromName(input.managerName),
      },
      color: input.color,
      zoneId: input.zoneId ?? MSR_ZONES[0]?.id ?? "zone-nord",
    };
    setTeams((prev) => [...prev, team]);
    return team;
  }, []);

  const value = useMemo(
    () => ({ agents, teams, addAgent, addTeam }),
    [agents, teams, addAgent, addTeam],
  );

  return (
    <MsrResourcesContext.Provider value={value}>
      {children}
    </MsrResourcesContext.Provider>
  );
}

export function useMsrResources(): MsrResourcesContextValue {
  const ctx = useContext(MsrResourcesContext);
  if (!ctx) {
    throw new Error("useMsrResources must be used within MsrResourcesProvider");
  }
  return ctx;
}

export function getTeamByIdFromList(
  teams: MsrTeam[],
  id: string,
): MsrTeam | undefined {
  return teams.find((t) => t.id === id);
}

export function getAgentsForMissionFromList(
  agents: MsrAgent[],
  agentIds: string[],
): MsrAgent[] {
  return agents.filter((a) => agentIds.includes(a.id));
}
