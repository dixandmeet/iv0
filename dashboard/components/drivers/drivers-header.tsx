"use client";

import { Plus, RefreshCw } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

interface DriversHeaderProps {
  activeTab: string;
  pendingCount: number;
  activeSessionCount: number;
  rosterCount: number;
  lastUpdated: Date | null;
  onAdd: () => void;
  onRefresh: () => void;
  refreshing?: boolean;
}

export function DriversHeader({
  pendingCount,
  activeSessionCount,
  rosterCount,
  lastUpdated,
  onAdd,
  onRefresh,
  refreshing,
}: DriversHeaderProps) {
  return (
    <header className="stops-header">
      <div className="stops-header-top">
        <div>
          <h1 className="stops-title">Conducteurs</h1>
          <p className="stops-subtitle">
            Gérez l&apos;annuaire conducteurs, validez les demandes d&apos;inscription et suivez les sessions actives.
          </p>
        </div>
        <div className="stops-header-actions">
          <Button onClick={onAdd} className="stops-btn-primary">
            <Plus className="h-4 w-4" />
            Ajouter un conducteur
          </Button>
          <Button
            variant="outline"
            onClick={onRefresh}
            disabled={refreshing}
            className="stops-btn-secondary"
          >
            <RefreshCw className={`h-4 w-4${refreshing ? " animate-spin" : ""}`} />
            Actualiser
          </Button>
        </div>
      </div>
      <div className="mt-4 flex flex-wrap items-center gap-2">
        <Badge variant="realtime">{activeSessionCount} en service</Badge>
        <Badge variant="secondary">{rosterCount} conducteurs</Badge>
        {pendingCount > 0 && (
          <Badge variant="outline" className="border-amber-500/50 bg-amber-500/10 text-amber-700 dark:text-amber-400">
            {pendingCount} demande{pendingCount > 1 ? "s" : ""} en attente
          </Badge>
        )}
        {lastUpdated && (
          <span className="text-xs text-muted-foreground">
            MAJ {lastUpdated.toLocaleTimeString("fr-FR")}
          </span>
        )}
      </div>
    </header>
  );
}
