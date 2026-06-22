"use client";

import type { StopDeparture } from "@/lib/stops-types";
import { formatDelayMinutes } from "@/lib/stops-types";
import { routeBadgeStyle } from "@/lib/stops-utils";
import { Clock } from "lucide-react";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";

interface StopSchedulesTabProps {
  departures: StopDeparture[];
  loading?: boolean;
}

export function StopSchedulesTab({ departures, loading = false }: StopSchedulesTabProps) {
  if (loading && !departures.length) {
    return <ListSkeleton rows={4} />;
  }
  if (!departures.length) {
    return (
      <EmptyState
        icon={Clock}
        title="Aucun passage"
        description="Aucun horaire théorique disponible pour cet arrêt."
      />
    );
  }

  return (
    <div className="stops-table-wrap">
      <table className="stops-table">
        <thead>
          <tr>
            <th>Ligne</th>
            <th>Direction</th>
            <th>Théorique</th>
            <th>Temps réel</th>
            <th>Écart</th>
            <th>Véhicule</th>
          </tr>
        </thead>
        <tbody>
          {departures.map((d, i) => (
            <tr key={`${d.trip_id}-${i}`}>
              <td>
                <span className="stops-route-badge" style={routeBadgeStyle(d.route_color)}>
                  {d.route_short_name ?? d.route_id}
                </span>
              </td>
              <td>{d.direction_id === 1 ? "Retour" : "Aller"}</td>
              <td className="font-mono">{d.theoretical_time}</td>
              <td className="font-mono">{d.realtime_time ?? "—"}</td>
              <td>
                <span
                  className={`stops-delay-badge${
                    (d.delay_minutes ?? 0) > 0
                      ? " stops-delay-badge--late"
                      : (d.delay_minutes ?? 0) < 0
                        ? " stops-delay-badge--early"
                        : ""
                  }`}
                >
                  {formatDelayMinutes(d.delay_minutes)}
                </span>
              </td>
              <td className="text-xs text-muted-foreground">
                {d.vehicle_id ? d.vehicle_id.slice(0, 8) : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
