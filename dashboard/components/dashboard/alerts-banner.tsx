"use client";

import { AlertTriangle, ChevronRight, X } from "lucide-react";
import type { OperationalAlert } from "@/lib/types";
import { severityColor } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

interface AlertsBannerProps {
  alerts: OperationalAlert[];
  onSelectAlert?: (alert: OperationalAlert) => void;
  onDismiss?: () => void;
  className?: string;
}

export function AlertsBanner({
  alerts,
  onSelectAlert,
  onDismiss,
  className,
}: AlertsBannerProps) {
  const critical = alerts.filter((a) => a.severity === "critical");
  const top = critical.length > 0 ? critical[0] : alerts[0];

  if (!top) return null;

  return (
    <div
      className={cn(
        "flex items-center gap-3 border-b px-3 py-2",
        top.severity === "critical"
          ? "border-destructive/30 bg-destructive/10"
          : top.severity === "warning"
            ? "border-orange-500/30 bg-orange-500/10"
            : "border-border bg-muted/50",
        className,
      )}
    >
      <AlertTriangle
        className="h-4 w-4 shrink-0"
        style={{ color: severityColor(top.severity) }}
      />
      <button
        type="button"
        className="min-w-0 flex-1 text-left"
        onClick={() => onSelectAlert?.(top)}
      >
        <p className="truncate text-sm font-medium">{top.title}</p>
        <p className="truncate text-xs text-muted-foreground">
          {alerts.length > 1
            ? `${top.description} · +${alerts.length - 1} alerte(s)`
            : top.description}
        </p>
      </button>
      <BadgeCount count={alerts.length} severity={top.severity} />
      {onDismiss && (
        <Button variant="ghost" size="icon" className="h-7 w-7 shrink-0" onClick={onDismiss}>
          <X className="h-4 w-4" />
        </Button>
      )}
      {onSelectAlert && (
        <Button
          variant="ghost"
          size="sm"
          className="h-7 shrink-0 gap-1 text-xs"
          onClick={() => onSelectAlert(top)}
        >
          Voir
          <ChevronRight className="h-3 w-3" />
        </Button>
      )}
    </div>
  );
}

function BadgeCount({
  count,
  severity,
}: {
  count: number;
  severity: OperationalAlert["severity"];
}) {
  return (
    <span
      className="rounded-full px-2 py-0.5 text-xs font-bold"
      style={{
        background: `${severityColor(severity)}22`,
        color: severityColor(severity),
      }}
    >
      {count}
    </span>
  );
}
