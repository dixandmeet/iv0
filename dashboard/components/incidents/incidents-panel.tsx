"use client";

import Link from "next/link";
import { AlertTriangle, ArrowRight } from "lucide-react";
import type { NetworkIncident } from "@/lib/types";
import {
  formatRelativeTime,
  severityColor,
  severityLabel,
  statusLabel,
} from "@/lib/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";
import { cn } from "@/lib/utils";

interface IncidentsPanelProps {
  incidents: NetworkIncident[];
  selectedId?: string | null;
  onSelect?: (id: string | null) => void;
  loading?: boolean;
  showViewAll?: boolean;
}

export function IncidentsPanel({
  incidents,
  selectedId,
  onSelect,
  loading,
  showViewAll = true,
}: IncidentsPanelProps) {
  return (
    <section className="mt-6">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-base font-semibold">Incidents ouverts</h2>
        {showViewAll && (
          <Button variant="ghost" size="sm" className="h-7 gap-1 text-xs" asChild>
            <Link href="/incidents">
              Voir tout
              <ArrowRight className="h-3 w-3" />
            </Link>
          </Button>
        )}
      </div>

      {loading ? (
        <ListSkeleton rows={3} />
      ) : incidents.length === 0 ? (
        <EmptyState
          icon={AlertTriangle}
          title="Réseau nominal"
          description="Aucun incident signalé en cours sur le réseau."
        />
      ) : (
        <div className="space-y-2">
          {incidents.map((inc) => {
            const isSelected = inc.id === selectedId;
            const clickable = !!onSelect;

            return (
              <div
                key={inc.id}
                role={clickable ? "button" : undefined}
                tabIndex={clickable ? 0 : undefined}
                onClick={
                  clickable
                    ? () => onSelect!(inc.id === selectedId ? null : inc.id)
                    : undefined
                }
                onKeyDown={
                  clickable
                    ? (e) => {
                        if (e.key === "Enter" || e.key === " ") {
                          onSelect!(inc.id === selectedId ? null : inc.id);
                        }
                      }
                    : undefined
                }
                className={cn(
                  "rounded-xl border p-3 transition-colors",
                  clickable && "cursor-pointer hover:bg-muted/50",
                  isSelected
                    ? "border-primary bg-primary/5"
                    : "border-border bg-card/50",
                )}
              >
                <div className="flex items-start justify-between gap-2">
                  <strong className="text-sm leading-snug">{inc.title}</strong>
                  <Badge
                    style={{
                      background: `${severityColor(inc.severity)}22`,
                      color: severityColor(inc.severity),
                    }}
                  >
                    {severityLabel(inc.severity)}
                  </Badge>
                </div>
                <p className="mt-1 text-xs text-muted-foreground">
                  {inc.incident_type}
                  {inc.route_id ? ` · Ligne ${inc.route_id}` : ""}
                  {" · "}
                  {statusLabel(inc.status)}
                </p>
                {inc.description && (
                  <p className="mt-1 line-clamp-2 text-xs text-muted-foreground">
                    {inc.description}
                  </p>
                )}
                <p className="mt-1 text-xs text-muted-foreground/70">
                  {formatRelativeTime(inc.created_at)}
                </p>
              </div>
            );
          })}
        </div>
      )}
    </section>
  );
}
