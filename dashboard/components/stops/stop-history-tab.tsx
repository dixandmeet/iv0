"use client";

import type { StopAuditEntry } from "@/lib/stops-types";
import { formatRelativeTime } from "@/lib/types";
import { History } from "lucide-react";
import { EmptyState } from "@/components/ui/empty-state";

const ACTION_LABELS: Record<string, string> = {
  created: "Création",
  updated: "Modification",
  disabled: "Désactivation",
  relocated: "Déplacement",
  imported: "Import",
};

interface StopHistoryTabProps {
  history: StopAuditEntry[];
}

export function StopHistoryTab({ history }: StopHistoryTabProps) {
  if (!history.length) {
    return (
      <EmptyState
        icon={History}
        title="Aucun historique"
        description="Les modifications de cet arrêt apparaîtront ici."
      />
    );
  }

  return (
    <ul className="stops-history-list">
      {history.map((entry) => (
        <li key={entry.id} className="stops-history-item">
          <div className="stops-history-dot" />
          <div className="stops-history-content stops-glass-card">
            <div className="stops-history-header">
              <span className="font-medium">{ACTION_LABELS[entry.action] ?? entry.action}</span>
              <span className="text-xs text-muted-foreground">
                {formatRelativeTime(entry.created_at)}
              </span>
            </div>
            {entry.performer_name && (
              <p className="text-xs text-muted-foreground">par {entry.performer_name}</p>
            )}
            {Object.keys(entry.changes).length > 0 && (
              <pre className="stops-history-changes">
                {JSON.stringify(entry.changes, null, 2)}
              </pre>
            )}
          </div>
        </li>
      ))}
    </ul>
  );
}
