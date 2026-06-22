"use client";

import Link from "next/link";
import { Pencil } from "lucide-react";
import type { StationListItem } from "@/lib/stations-types";
import { stationStatusColor, stationStatusLabel } from "@/lib/stations-types";
import { formatCompactCoords } from "@/lib/stops-utils";

interface StationListCardProps {
  station: StationListItem;
  selected: boolean;
  onSelect: () => void;
}

export function StationListCard({ station, selected, onSelect }: StationListCardProps) {
  const coords =
    station.latitude_center != null && station.longitude_center != null
      ? formatCompactCoords({
          type: "Point",
          coordinates: [station.longitude_center, station.latitude_center],
        })
      : null;

  return (
    <button
      type="button"
      onClick={onSelect}
      className={`stops-list-card stops-glass-card${selected ? " stops-list-card--selected" : ""}`}
    >
      <div className="stops-list-card-header">
        <div className="min-w-0 flex-1">
          <h3 className="stops-list-card-name">{station.name}</h3>
          <p className="stops-list-card-disambiguation">
            {station.stop_count} arrêt{station.stop_count !== 1 ? "s" : ""}
            {coords ? ` · ${coords}` : ""}
          </p>
        </div>
        <span
          className="stops-status-badge shrink-0"
          style={{
            backgroundColor: `${stationStatusColor(station.status)}22`,
            color: stationStatusColor(station.status),
            borderColor: `${stationStatusColor(station.status)}44`,
          }}
        >
          {stationStatusLabel(station.status)}
        </span>
      </div>
      <div className="stops-list-card-meta">
        <span className="stops-list-card-commune">{station.commune ?? "—"}</span>
      </div>
      <div className="stops-list-card-footer">
        <Link
          href={`/stations/${station.id}`}
          className="stops-list-card-edit"
          onClick={(e) => e.stopPropagation()}
        >
          <Pencil className="h-3 w-3" />
          Ouvrir
        </Link>
      </div>
    </button>
  );
}
