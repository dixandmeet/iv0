"use client";

import { AlertTriangle, Bus, Radio, ShieldAlert } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/empty-state";
import type { LiveFleetPosition, NetworkIncident } from "@/lib/types";

interface KpiBarProps {
  fleet: LiveFleetPosition[];
  incidents: NetworkIncident[];
  loading?: boolean;
  lastUpdated?: Date | null;
}

function avgReliability(fleet: LiveFleetPosition[]): number {
  if (fleet.length === 0) return 0;
  const sum = fleet.reduce((acc, v) => acc + v.reliability_score, 0);
  return Math.round(sum / fleet.length);
}

export function KpiBar({ fleet, incidents, loading, lastUpdated }: KpiBarProps) {
  const criticalCount = incidents.filter((i) => i.severity === "critical").length;
  const avgScore = avgReliability(fleet);

  const items = [
    {
      label: "Véhicules actifs",
      value: fleet.length.toString(),
      icon: Bus,
      accent: "text-primary",
    },
    {
      label: "Fiabilité moy.",
      value: fleet.length > 0 ? `${avgScore}%` : "—",
      icon: Radio,
      accent: avgScore >= 80 ? "text-green-600" : avgScore >= 50 ? "text-orange-500" : "text-destructive",
    },
    {
      label: "Incidents ouverts",
      value: incidents.length.toString(),
      icon: AlertTriangle,
      accent: incidents.length > 0 ? "text-orange-500" : "text-muted-foreground",
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
        {Array.from({ length: 4 }).map((_, i) => (
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
            MAJ {lastUpdated.toLocaleTimeString("fr-FR", { hour: "2-digit", minute: "2-digit", second: "2-digit" })}
          </span>
        )}
      </div>
      <div className="grid grid-cols-2 gap-2 lg:grid-cols-4">
        {items.map((item) => (
          <Card key={item.label} className="shadow-none">
            <CardContent className="flex items-center gap-3 p-3">
              <item.icon className={`h-5 w-5 shrink-0 ${item.accent}`} />
              <div className="min-w-0">
                <p className="truncate text-xs text-muted-foreground">{item.label}</p>
                <p className="text-lg font-semibold leading-tight">{item.value}</p>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
