"use client";

import Link from "next/link";
import { useMemo } from "react";
import {
  AlertTriangle,
  Bus,
  MapPinOff,
  Radio,
  UserX,
  Users,
} from "lucide-react";
import { useOperationsData } from "@/hooks/use-operations-data";
import { useDriversData } from "@/hooks/use-drivers-data";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { EmptyState } from "@/components/ui/empty-state";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { computeOperationalAlerts } from "@/lib/alerts";
import type { OperationalAlert } from "@/lib/types";
import { severityColor } from "@/lib/types";

const ALERT_ICONS: Record<OperationalAlert["type"], typeof AlertTriangle> = {
  delay: Bus,
  gps_loss: Radio,
  immobilized: Bus,
  off_route: MapPinOff,
  driver_disconnect: UserX,
  crowding: Users,
  incident: AlertTriangle,
};

export function AlertsPageContent() {
  const { fleet, incidents, loading, error, refresh } = useOperationsData();
  const { drivers } = useDriversData();

  const alerts = useMemo(
    () => computeOperationalAlerts(fleet, incidents, drivers),
    [fleet, incidents, drivers],
  );

  const critical = alerts.filter((a) => a.severity === "critical");
  const warning = alerts.filter((a) => a.severity === "warning");
  const info = alerts.filter((a) => a.severity === "info");

  return (
    <main
      className="dashboard-panel overflow-auto"
      style={{ gridColumn: "2 / -1", padding: 24 }}
    >
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold">Centre d&apos;alertes</h1>
          <p className="text-sm text-muted-foreground">
            Alertes automatiques : retards, GPS, immobilisation, affluence, incidents.
          </p>
        </div>
        <Badge variant="realtime">{alerts.length} alerte(s)</Badge>
      </div>

      <div className="mb-6 grid grid-cols-3 gap-3">
        <Card className="shadow-none border-destructive/30">
          <CardContent className="p-3">
            <p className="text-xs text-muted-foreground">Critiques</p>
            <p className="text-2xl font-semibold text-destructive">{critical.length}</p>
          </CardContent>
        </Card>
        <Card className="shadow-none border-orange-500/30">
          <CardContent className="p-3">
            <p className="text-xs text-muted-foreground">Alertes</p>
            <p className="text-2xl font-semibold text-orange-500">{warning.length}</p>
          </CardContent>
        </Card>
        <Card className="shadow-none">
          <CardContent className="p-3">
            <p className="text-xs text-muted-foreground">Informations</p>
            <p className="text-2xl font-semibold">{info.length}</p>
          </CardContent>
        </Card>
      </div>

      {loading ? (
        <p className="text-sm text-muted-foreground">Chargement…</p>
      ) : alerts.length === 0 ? (
        <EmptyState
          icon={AlertTriangle}
          title="Réseau nominal"
          description="Aucune alerte automatique détectée sur le réseau."
        />
      ) : (
        <div className="space-y-2">
          {alerts.map((alert) => {
            const Icon = ALERT_ICONS[alert.type] ?? AlertTriangle;
            return (
              <Card key={alert.id} className="shadow-none">
                <CardContent className="flex items-start gap-4 p-4">
                  <div
                    className="rounded-lg p-2"
                    style={{ background: `${severityColor(alert.severity)}15` }}
                  >
                    <Icon
                      className="h-5 w-5"
                      style={{ color: severityColor(alert.severity) }}
                    />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <strong className="text-sm">{alert.title}</strong>
                      <Badge
                        style={{
                          background: `${severityColor(alert.severity)}22`,
                          color: severityColor(alert.severity),
                        }}
                      >
                        {alert.severity}
                      </Badge>
                      {alert.route_id && (
                        <Badge variant="outline">Ligne {alert.route_id}</Badge>
                      )}
                    </div>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {alert.description}
                    </p>
                  </div>
                  <div className="flex shrink-0 gap-2">
                    {alert.incident_id && (
                      <Button variant="outline" size="sm" className="h-8 text-xs" asChild>
                        <Link href={`/incidents`}>Incident</Link>
                      </Button>
                    )}
                    {alert.vehicle_id && (
                      <Button variant="outline" size="sm" className="h-8 text-xs" asChild>
                        <Link href="/dashboard">Carte</Link>
                      </Button>
                    )}
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
