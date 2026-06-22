"use client";

import Link from "next/link";
import {
  AlertTriangle,
  Ban,
  Crosshair,
  MessageSquare,
  Wrench,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { DriverSession, LiveFleetPosition } from "@/lib/types";
import { reliabilityColor, sourceLabel } from "@/lib/types";

interface VehicleDetailPanelProps {
  vehicle: LiveFleetPosition;
  driver?: DriverSession | null;
  onCenter: () => void;
  onClose: () => void;
  showClose?: boolean;
  className?: string;
}

export function VehicleDetailPanel({
  vehicle,
  driver,
  onCenter,
  onClose,
  showClose = true,
  className,
}: VehicleDetailPanelProps) {
  const delay =
    vehicle.estimated_delay_seconds != null && vehicle.estimated_delay_seconds > 0
      ? `${Math.round(vehicle.estimated_delay_seconds / 60)} min`
      : null;
  const isEarly =
    vehicle.estimated_delay_seconds != null && vehicle.estimated_delay_seconds < -60;

  const operationalStatus =
    vehicle.speed != null && vehicle.speed <= 2
      ? "Immobilisé"
      : delay
        ? "En retard"
        : isEarly
          ? "En avance"
          : "En service";

  return (
    <Card className={`vehicle-detail-panel shadow-none${className ? ` ${className}` : ""}`}>
      <CardHeader className="vehicle-detail-panel-header space-y-0 p-4 pb-2">
        <div className="min-w-0 flex-1">
          <CardTitle className="text-base">Ligne {vehicle.route_id}</CardTitle>
          <p className="text-xs text-muted-foreground">
            {sourceLabel(vehicle.source)} · {vehicle.transport_type}
          </p>
        </div>
        <div className="vehicle-detail-panel-actions">
          <Badge
            className="shrink-0"
            style={{
              background: `${reliabilityColor(vehicle.reliability_score)}22`,
              color: reliabilityColor(vehicle.reliability_score),
            }}
          >
            {vehicle.reliability_score}%
          </Badge>
          {showClose && (
            <Button variant="ghost" size="sm" className="h-7 w-7 shrink-0 p-0 text-xs" onClick={onClose}>
              ✕
            </Button>
          )}
        </div>
      </CardHeader>
      <CardContent className="space-y-3 p-4 pt-0">
        <Badge variant="outline">{operationalStatus}</Badge>

        {driver && (
          <div className="rounded-lg border border-border bg-muted/30 px-3 py-2 text-sm">
            <p className="text-xs text-muted-foreground">Conducteur</p>
            <p className="font-medium">
              {driver.driver?.display_name ?? "Conducteur"}
            </p>
            {driver.headsign && (
              <p className="text-xs text-muted-foreground">{driver.headsign}</p>
            )}
          </div>
        )}

        <div className="grid grid-cols-2 gap-2 text-sm">
          <DetailItem label="Vitesse" value={vehicle.speed != null ? `${Math.round(vehicle.speed)} km/h` : "—"} />
          <DetailItem label="Cap" value={vehicle.heading != null ? `${Math.round(vehicle.heading)}°` : "—"} />
          <DetailItem
            label="Retard est."
            value={delay ?? (isEarly ? "En avance" : "À l'heure")}
            highlight={!!delay}
          />
          <DetailItem
            label="Cohérence"
            value={vehicle.coherence_score != null ? `${vehicle.coherence_score}%` : "—"}
          />
          {vehicle.active_user_count != null && vehicle.active_user_count > 0 && (
            <DetailItem label="Contributeurs" value={String(vehicle.active_user_count)} />
          )}
        </div>

        <p className="text-xs text-muted-foreground">
          Dernière position il y a {vehicle.freshness_seconds}s
        </p>

        <div className="grid grid-cols-2 gap-2">
          <Button variant="outline" size="sm" className="gap-2" onClick={onCenter}>
            <Crosshair className="h-4 w-4" />
            Centrer
          </Button>
          <Button variant="outline" size="sm" className="gap-2" asChild>
            <Link
              href={`/communication?route=${vehicle.route_id}&driver=${driver?.driver_id ?? ""}`}
            >
              <MessageSquare className="h-4 w-4" />
              Message
            </Link>
          </Button>
          <Button variant="outline" size="sm" className="gap-2" asChild>
            <Link href={`/incidents?route=${vehicle.route_id}&create=1`}>
              <AlertTriangle className="h-4 w-4" />
              Incident
            </Link>
          </Button>
          <Button variant="outline" size="sm" className="gap-2" asChild>
            <Link href={`/info-voyageur?route=${vehicle.route_id}&type=delay`}>
              <Ban className="h-4 w-4" />
              Perturbation
            </Link>
          </Button>
        </div>

        <Button variant="ghost" size="sm" className="w-full gap-2 text-xs text-muted-foreground" asChild>
          <Link href={`/conducteurs?session=${vehicle.driver_session_id ?? ""}`}>
            <Wrench className="h-3.5 w-3.5" />
            Voir conducteurs
          </Link>
        </Button>
      </CardContent>
    </Card>
  );
}

function DetailItem({
  label,
  value,
  highlight,
}: {
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <div className="rounded-lg border border-border bg-muted/30 px-3 py-2">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className={`font-medium ${highlight ? "text-orange-500" : ""}`}>{value}</p>
    </div>
  );
}
