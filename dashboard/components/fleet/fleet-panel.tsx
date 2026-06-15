"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { Bus } from "lucide-react";
import type { FleetSource, LiveFleetPosition } from "@/lib/types";
import { reliabilityColor, sourceLabel } from "@/lib/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";
import { cn } from "@/lib/utils";

type SourceFilter = FleetSource | "all";
type SortKey = "reliability" | "freshness" | "route";

interface FleetPanelProps {
  fleet: LiveFleetPosition[];
  selectedId: string | null;
  onSelect: (id: string | null) => void;
  loading?: boolean;
}

export function FleetPanel({
  fleet,
  selectedId,
  onSelect,
  loading,
}: FleetPanelProps) {
  const [sourceFilter, setSourceFilter] = useState<SourceFilter>("all");
  const [sortKey, setSortKey] = useState<SortKey>("reliability");

  const filtered = useMemo(() => {
    let items = [...fleet];
    if (sourceFilter !== "all") {
      items = items.filter((v) => v.source === sourceFilter);
    }
    items.sort((a, b) => {
      switch (sortKey) {
        case "freshness":
          return a.freshness_seconds - b.freshness_seconds;
        case "route":
          return a.route_id.localeCompare(b.route_id);
        default:
          return b.reliability_score - a.reliability_score;
      }
    });
    return items;
  }, [fleet, sourceFilter, sortKey]);

  const sources: SourceFilter[] = ["all", "driver", "community", "operator"];

  return (
    <section>
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-base font-semibold">Flotte live</h2>
        <Badge variant="secondary">{fleet.length}</Badge>
      </div>

      <div className="mb-3 flex flex-wrap gap-1">
        {sources.map((s) => (
          <Button
            key={s}
            variant={sourceFilter === s ? "default" : "outline"}
            size="sm"
            className="h-7 px-2 text-xs"
            onClick={() => setSourceFilter(s)}
          >
            {s === "all" ? "Tous" : sourceLabel(s as FleetSource)}
          </Button>
        ))}
      </div>

      <div className="mb-3 flex gap-1">
        {(
          [
            ["reliability", "Fiabilité"],
            ["freshness", "Fraîcheur"],
            ["route", "Ligne"],
          ] as const
        ).map(([key, label]) => (
          <Button
            key={key}
            variant={sortKey === key ? "secondary" : "ghost"}
            size="sm"
            className="h-7 px-2 text-xs"
            onClick={() => setSortKey(key)}
          >
            {label}
          </Button>
        ))}
      </div>

      {loading ? (
        <ListSkeleton rows={4} />
      ) : filtered.length === 0 ? (
        <EmptyState
          icon={Bus}
          title="Aucun véhicule en circulation"
          description={
            fleet.length === 0
              ? "Les positions apparaîtront dès qu'un conducteur ou un contributeur sera actif sur le réseau."
              : "Aucun véhicule ne correspond à ce filtre."
          }
        />
      ) : (
        <div className="space-y-2">
          {filtered.map((v) => {
            const hasDelay =
              v.estimated_delay_seconds != null && v.estimated_delay_seconds > 0;
            const isSelected = v.id === selectedId;

            return (
              <button
                key={v.id}
                type="button"
                onClick={() => onSelect(v.id === selectedId ? null : v.id)}
                className={cn(
                  "w-full rounded-xl border p-3 text-left transition-colors",
                  isSelected
                    ? "border-primary bg-primary/5"
                    : "border-border bg-card/50 hover:bg-muted/50",
                )}
              >
                <div className="flex items-center justify-between gap-2">
                  <strong className="text-sm">Ligne {v.route_id}</strong>
                  <div className="flex items-center gap-1">
                    {hasDelay && (
                      <Badge variant="outline" className="text-orange-500">
                        +{Math.round(v.estimated_delay_seconds! / 60)} min
                      </Badge>
                    )}
                    <Badge
                      style={{
                        background: `${reliabilityColor(v.reliability_score)}22`,
                        color: reliabilityColor(v.reliability_score),
                      }}
                    >
                      {v.reliability_score}%
                    </Badge>
                  </div>
                </div>
                <p className="mt-1 text-xs text-muted-foreground">
                  {sourceLabel(v.source)} · {v.transport_type} · il y a{" "}
                  {v.freshness_seconds}s
                </p>
              </button>
            );
          })}
        </div>
      )}
    </section>
  );
}
