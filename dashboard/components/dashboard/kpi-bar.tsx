"use client";

import {
  AlertTriangle,
  Bus,
  Clock,
  Radio,
  ShieldAlert,
  Users,
  UserCheck,
} from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/empty-state";
import type { LiveFleetPosition, NetworkIncident } from "@/lib/types";
import {
  computePunctualityRate,
  countActiveLines,
  sumActiveUsers,
} from "@/lib/alerts";

interface KpiBarProps {
  fleet: LiveFleetPosition[];
  incidents: NetworkIncident[];
  connectedDrivers?: number;
  alertCount?: number;
  loading?: boolean;
  lastUpdated?: Date | null;
}

export function KpiBar({
  fleet,
  incidents,
  connectedDrivers = 0,
  alertCount = 0,
  loading,
  lastUpdated,
}: KpiBarProps) {
  const criticalCount = incidents.filter((i) => i.severity === "critical").length;
  const punctuality = computePunctualityRate(fleet);
  const activeLines = countActiveLines(fleet);
  const activeUsers = sumActiveUsers(fleet);

  const items = [
    {
      label: "Véhicules actifs",
      value: fleet.length.toString(),
      icon: Bus,
      accent: "text-primary",
    },
    {
      label: "Lignes actives",
      value: activeLines.toString(),
      icon: Radio,
      accent: "text-primary",
    },
    {
      label: "Conducteurs",
      value: connectedDrivers.toString(),
      icon: UserCheck,
      accent: connectedDrivers > 0 ? "text-green-600" : "text-muted-foreground",
    },
    {
      label: "Ponctualité",
      value: fleet.length > 0 ? `${punctuality}%` : "—",
      icon: Clock,
      accent:
        punctuality >= 80
          ? "text-green-600"
          : punctuality >= 60
            ? "text-orange-500"
            : "text-destructive",
    },
    {
      label: "Incidents",
      value: incidents.length.toString(),
      icon: AlertTriangle,
      accent: incidents.length > 0 ? "text-orange-500" : "text-muted-foreground",
    },
    {
      label: "Alertes auto",
      value: alertCount.toString(),
      icon: ShieldAlert,
      accent: alertCount > 0 ? "text-destructive" : "text-muted-foreground",
    },
    {
      label: "Contributeurs",
      value: activeUsers > 0 ? activeUsers.toString() : "—",
      icon: Users,
      accent: activeUsers > 0 ? "text-primary" : "text-muted-foreground",
    },
    {
      label: "Critiques",
      value: criticalCount.toString(),
      icon: ShieldAlert,
      accent: criticalCount > 0 ? "text-destructive" : "text-muted-foreground",
    },
  ];

  if (loading) {
    return (
      <div className="grid grid-cols-2 gap-2 p-3 lg:grid-cols-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton key={i} className="h-[72px]" />
        ))}
      </div>
    );
  }

  return (
    <div className="border-b border-border bg-card/50 p-3">
      <div className="mb-2 flex items-center justify-between">
        <Badge variant="realtime" className="gap-1.5">
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-realtime opacity-75" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-realtime" />
          </span>
          Live
        </Badge>
        {lastUpdated && (
          <span className="text-xs text-muted-foreground">
            MAJ{" "}
            {lastUpdated.toLocaleTimeString("fr-FR", {
              hour: "2-digit",
              minute: "2-digit",
              second: "2-digit",
            })}
          </span>
        )}
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-4 xl:grid-cols-8">
        {items.map((item) => (
          <Card key={item.label} className="shadow-none">
            <CardContent className="flex items-center gap-2 p-2.5">
              <item.icon className={`h-4 w-4 shrink-0 ${item.accent}`} />
              <div className="min-w-0">
                <p className="truncate text-[10px] text-muted-foreground">{item.label}</p>
                <p className="text-base font-semibold leading-tight">{item.value}</p>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
