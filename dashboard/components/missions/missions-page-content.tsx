"use client";

import { ClipboardList, MapPin } from "lucide-react";
import { useMissionsData } from "@/hooks/use-missions-data";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent } from "@/components/ui/card";
import {
  formatRelativeTime,
  missionStatusColor,
  statusLabel,
} from "@/lib/types";

const ZONE_LABELS: Record<string, string> = {
  sector: "Secteur",
  line_buffer: "Buffer ligne",
  custom_polygon: "Zone personnalisée",
};

export function MissionsPageContent() {
  const { missions, loading, error, lastUpdated, refresh } = useMissionsData();

  const activeCount = missions.filter(
    (m) => m.status === "in_progress" || m.status === "assigned",
  ).length;

  return (
    <main
      className="dashboard-panel overflow-auto"
      style={{ gridColumn: "2 / -1", padding: 24 }}
    >
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold">Missions MSR</h1>
          <p className="text-sm text-muted-foreground">
            Suivi des patrouilles agents MSR sur le réseau.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="realtime">{activeCount} active(s)</Badge>
          {lastUpdated && (
            <span className="text-xs text-muted-foreground">
              MAJ {lastUpdated.toLocaleTimeString("fr-FR")}
            </span>
          )}
        </div>
      </div>

      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        {(["in_progress", "assigned", "draft", "completed"] as const).map(
          (status) => {
            const count = missions.filter((m) => m.status === status).length;
            return (
              <Card key={status} className="shadow-none">
                <CardContent className="p-3">
                  <p className="text-xs text-muted-foreground">
                    {statusLabel(status)}
                  </p>
                  <p className="text-2xl font-semibold">{count}</p>
                </CardContent>
              </Card>
            );
          },
        )}
      </div>

      {loading ? (
        <ListSkeleton rows={4} />
      ) : missions.length === 0 ? (
        <EmptyState
          icon={ClipboardList}
          title="Aucune mission MSR"
          description="Les missions apparaîtront ici une fois planifiées ou assignées."
        />
      ) : (
        <div className="space-y-3">
          {missions.map((mission) => {
            const zoneLabel =
              (mission.zone_config?.label as string) ??
              (mission.zone_config?.sector_id as string) ??
              (mission.zone_config?.route_id
                ? `Ligne ${mission.zone_config.route_id}`
                : null) ??
              mission.zone_type;

            return (
              <Card key={mission.id} className="shadow-none">
                <CardContent className="flex items-start gap-4 p-4">
                  <div className="rounded-lg bg-muted p-2">
                    <MapPin className="h-5 w-5 text-muted-foreground" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <strong className="text-sm">{zoneLabel}</strong>
                      <Badge
                        style={{
                          background: `${missionStatusColor(mission.status)}22`,
                          color: missionStatusColor(mission.status),
                        }}
                      >
                        {statusLabel(mission.status)}
                      </Badge>
                      <Badge variant="outline">
                        {ZONE_LABELS[mission.zone_type] ?? mission.zone_type}
                      </Badge>
                    </div>
                    <p className="mt-1 text-xs text-muted-foreground">
                      Créée {formatRelativeTime(mission.created_at)}
                      {mission.started_at &&
                        ` · Démarrée ${formatRelativeTime(mission.started_at)}`}
                    </p>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </main>
  );
}
