"use client";

import type { StopServingLine } from "@/lib/stops-types";
import { formatTimeFromTerminus } from "@/lib/stops-types";
import { routeBadgeStyle } from "@/lib/stops-utils";
import { Bus } from "lucide-react";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";

interface StopLinesTabProps {
  lines: StopServingLine[];
  platformCount: number;
  loading?: boolean;
}

export function StopLinesTab({ lines, platformCount, loading = false }: StopLinesTabProps) {
  if (loading && !lines.length) {
    return <ListSkeleton rows={4} />;
  }
  if (!lines.length) {
    return <EmptyState icon={Bus} title="Aucune ligne" description="Cet arrêt n'est desservi par aucune ligne connue." />;
  }

  const unique = dedupeLines(lines);

  return (
    <div className="stops-table-wrap">
      <table className="stops-table">
        <thead>
          <tr>
            <th>Ligne</th>
            <th>Direction</th>
            <th>Quai</th>
            <th>Ordre</th>
            <th>Arrêt précédent</th>
            <th>Arrêt suivant</th>
            <th>Depuis terminus</th>
          </tr>
        </thead>
        <tbody>
          {unique.map((line) => (
            <tr key={`${line.route_id}-${line.direction_id}-${line.trip_id}`}>
              <td>
                <span
                  className="stops-route-badge"
                  style={routeBadgeStyle(line.route_color)}
                >
                  {line.route_short_name ?? line.route_id}
                </span>
              </td>
              <td>{line.direction_id === 1 ? "Retour" : "Aller"}</td>
              <td>{platformCount > 1 ? `Quai ${line.stop_sequence % platformCount || 1}` : "Unique"}</td>
              <td>{line.stop_sequence}</td>
              <td>{line.prev_stop_name ?? "—"}</td>
              <td>{line.next_stop_name ?? "—"}</td>
              <td>{formatTimeFromTerminus(line.time_from_terminus_seconds)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function dedupeLines(lines: StopServingLine[]): StopServingLine[] {
  const seen = new Set<string>();
  const result: StopServingLine[] = [];
  for (const line of lines) {
    const key = `${line.route_id}-${line.direction_id ?? 0}`;
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(line);
  }
  return result.sort((a, b) =>
    (a.route_short_name ?? "").localeCompare(b.route_short_name ?? "", "fr", {
      numeric: true,
    }),
  );
}
