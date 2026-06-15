"use client";

import { Crosshair, Gauge, Navigation } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import type { LiveFleetPosition } from "@/lib/types";
import { reliabilityColor, sourceLabel } from "@/lib/types";

interface VehicleDetailPanelProps {
  vehicle: LiveFleetPosition;
  onCenter: () => void;
  onClose: () => void;
}

export function VehicleDetailPanel({
  vehicle,
  onCenter,
  onClose,
}: VehicleDetailPanelProps) {
  const delay =
    vehicle.estimated_delay_seconds != null && vehicle.estimated_delay_seconds > 0
      ? `${Math.round(vehicle.estimated_delay_seconds / 60)} min`
      : null;

  return (
    <Card className="mt-3 shadow-none">
      <CardHeader className="flex flex-row items-start justify-between space-y-0 p-4 pb-2">
        <div>
          <CardTitle className="text-base">Ligne {vehicle.route_id}</CardTitle>
          <p className="text-xs text-muted-foreground">
            {sourceLabel(vehicle.source)} · {vehicle.transport_type}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge
            style={{
              background: `${reliabilityColor(vehicle.reliability_score)}22`,
              color: reliabilityColor(vehicle.reliability_score),
            }}
          >
            {vehicle.reliability_score}%
          </Badge>
          <Button variant="ghost" size="sm" className="h-7 px-2 text-xs" onClick={onClose}>
            ✕
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-3 p-4 pt-0">
        <div className="grid grid-cols-2 gap-2 text-sm">
          <DetailItem
            icon={Gauge}
            label="Vitesse"
            value={vehicle.speed != null ? `${Math.round(vehicle.speed)} km/h` : "—"}
          />
          <DetailItem
            icon={Navigation}
            label="Cap"
            value={vehicle.heading != null ? `${Math.round(vehicle.heading)}°` : "—"}
          />
          <DetailItem
            label="Retard est."
            value={delay ?? "À l'heure"}
            highlight={!!delay}
          />
          <DetailItem
            label="Cohérence"
            value={
              vehicle.coherence_score != null ? `${vehicle.coherence_score}%` : "—"
            }
          />
        </div>
        <p className="text-xs text-muted-foreground">
          Dernière position il y a {vehicle.freshness_seconds}s
        </p>
        <Button variant="outline" size="sm" className="w-full gap-2" onClick={onCenter}>
          <Crosshair className="h-4 w-4" />
          Centrer sur la carte
        </Button>
      </CardContent>
    </Card>
  );
}

function DetailItem({
  icon: Icon,
  label,
  value,
  highlight,
}: {
  icon?: React.ComponentType<{ className?: string }>;
  label: string;
  value: string;
  highlight?: boolean;
}) {
  return (
    <div className="rounded-lg border border-border bg-muted/30 px-3 py-2">
      <div className="flex items-center gap-1 text-xs text-muted-foreground">
        {Icon && <Icon className="h-3 w-3" />}
        {label}
      </div>
      <p className={`font-medium ${highlight ? "text-orange-500" : ""}`}>{value}</p>
    </div>
  );
}
