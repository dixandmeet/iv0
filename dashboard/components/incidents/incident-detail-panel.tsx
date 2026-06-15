"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import {
  CheckCircle2,
  Clock,
  MapPin,
  MessageSquare,
  PlayCircle,
  XCircle,
} from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useIncidentActions } from "@/hooks/use-incident-actions";
import type { IncidentActionLog, NetworkIncident } from "@/lib/types";
import {
  formatRelativeTime,
  severityColor,
  severityLabel,
  statusLabel,
} from "@/lib/types";

interface IncidentDetailPanelProps {
  incident: NetworkIncident;
  onClose: () => void;
  onUpdated?: () => void;
  onCenter?: () => void;
}

export function IncidentDetailPanel({
  incident,
  onClose,
  onUpdated,
  onCenter,
}: IncidentDetailPanelProps) {
  const { updateIncidentStatus, fetchActionLog, submitting } = useIncidentActions();
  const [actions, setActions] = useState<IncidentActionLog[]>([]);

  useEffect(() => {
    fetchActionLog(incident.id).then(setActions);
  }, [incident.id, fetchActionLog]);

  const handleStatus = async (status: string) => {
    await updateIncidentStatus(incident.id, status);
    const log = await fetchActionLog(incident.id);
    setActions(log);
    onUpdated?.();
  };

  const canAcknowledge = incident.status === "open";
  const canStart = incident.status === "open" || incident.status === "acknowledged";
  const canResolve =
    incident.status === "in_progress" ||
    incident.status === "acknowledged" ||
    incident.status === "open";
  const canClose = incident.status === "resolved";

  return (
    <Card className="mt-3 shadow-none">
      <CardHeader className="flex flex-row items-start justify-between space-y-0 p-4 pb-2">
        <div className="min-w-0">
          <CardTitle className="text-base leading-snug">{incident.title}</CardTitle>
          <p className="mt-1 text-xs text-muted-foreground">
            {incident.incident_type}
            {incident.route_id ? ` · Ligne ${incident.route_id}` : ""}
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge
            style={{
              background: `${severityColor(incident.severity)}22`,
              color: severityColor(incident.severity),
            }}
          >
            {severityLabel(incident.severity)}
          </Badge>
          <Button variant="ghost" size="sm" className="h-7 px-2 text-xs" onClick={onClose}>
            ✕
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-3 p-4 pt-0">
        <div className="flex flex-wrap gap-2">
          <Badge variant="outline">{statusLabel(incident.status)}</Badge>
          <Badge variant="secondary">{incident.source}</Badge>
          <span className="text-xs text-muted-foreground">
            {formatRelativeTime(incident.created_at)}
          </span>
        </div>

        {incident.description && (
          <p className="text-sm text-muted-foreground">{incident.description}</p>
        )}

        <div className="flex flex-wrap gap-2">
          {canAcknowledge && (
            <Button
              size="sm"
              variant="outline"
              className="h-8 gap-1 text-xs"
              disabled={submitting}
              onClick={() => handleStatus("acknowledged")}
            >
              <CheckCircle2 className="h-3.5 w-3.5" />
              Acquitter
            </Button>
          )}
          {canStart && (
            <Button
              size="sm"
              variant="outline"
              className="h-8 gap-1 text-xs"
              disabled={submitting}
              onClick={() => handleStatus("in_progress")}
            >
              <PlayCircle className="h-3.5 w-3.5" />
              Prendre en charge
            </Button>
          )}
          {canResolve && (
            <Button
              size="sm"
              variant="outline"
              className="h-8 gap-1 text-xs"
              disabled={submitting}
              onClick={() => handleStatus("resolved")}
            >
              <CheckCircle2 className="h-3.5 w-3.5" />
              Résoudre
            </Button>
          )}
          {canClose && (
            <Button
              size="sm"
              variant="outline"
              className="h-8 gap-1 text-xs"
              disabled={submitting}
              onClick={() => handleStatus("closed")}
            >
              <XCircle className="h-3.5 w-3.5" />
              Clôturer
            </Button>
          )}
          {onCenter && (
            <Button size="sm" variant="outline" className="h-8 gap-1 text-xs" onClick={onCenter}>
              <MapPin className="h-3.5 w-3.5" />
              Carte
            </Button>
          )}
          <Button size="sm" variant="outline" className="h-8 gap-1 text-xs" asChild>
            <Link
              href={`/info-voyageur?incident=${incident.id}&route=${incident.route_id ?? ""}`}
            >
              <MessageSquare className="h-3.5 w-3.5" />
              Info voyageur
            </Link>
          </Button>
        </div>

        {actions.length > 0 && (
          <div className="rounded-lg border border-border bg-muted/30 p-3">
            <p className="mb-2 text-xs font-medium text-muted-foreground">Historique</p>
            <ul className="space-y-1.5">
              {actions.slice(0, 5).map((a) => (
                <li key={a.id} className="flex items-start gap-2 text-xs">
                  <Clock className="mt-0.5 h-3 w-3 shrink-0 text-muted-foreground" />
                  <span>
                    <strong>{a.action_type}</strong>
                    <span className="text-muted-foreground">
                      {" "}
                      · {formatRelativeTime(a.executed_at)}
                    </span>
                  </span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
