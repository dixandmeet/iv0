"use client";

import type { StopListItem } from "@/lib/stops-types";
import {
  stopStatusColor,
  stopStatusLabel,
  wheelchairLabel,
  TRANSPORT_MODE_LABELS,
} from "@/lib/stops-types";
import { STOP_SOURCE_LABELS } from "@/lib/stations-types";
import { pointCoordinates } from "@/lib/geo";
import { stopDisambiguationLine } from "@/lib/stops-utils";

interface StopInfoTabProps {
  stop: StopListItem;
}

export function StopInfoTab({ stop }: StopInfoTabProps) {
  const coords = pointCoordinates(stop.geom);

  return (
    <div className="stops-info-tab">
      <div className="stops-info-grid">
        <InfoRow label="Station" value={stop.station_name ?? "—"} />
        <InfoRow label="Code arrêt" value={stop.code} mono />
        <InfoRow label="Nom" value={stop.name ?? "—"} />
        <InfoRow label="Identifiant" value={stopDisambiguationLine(stop)} />
        <InfoRow
          label="Statut"
          value={
            <span
              className="stops-status-badge"
              style={{
                backgroundColor: `${stopStatusColor(stop.status)}22`,
                color: stopStatusColor(stop.status),
              }}
            >
              {stopStatusLabel(stop.status)}
            </span>
          }
        />
        <InfoRow label="Mode" value={TRANSPORT_MODE_LABELS[stop.transport_mode]} />
        <InfoRow label="Provenance" value={STOP_SOURCE_LABELS[stop.source]} />
        <InfoRow label="Quai" value={stop.platform ?? "—"} />
        <InfoRow label="Adresse" value={stop.address ?? "—"} />
        <InfoRow label="Latitude" value={coords ? coords[1].toFixed(6) : "—"} mono />
        <InfoRow label="Longitude" value={coords ? coords[0].toFixed(6) : "—"} mono />
        <InfoRow label="Accessibilité PMR" value={wheelchairLabel(stop.is_accessible)} />
        <InfoRow label="Zone tarifaire" value={stop.tariff_zone ?? "—"} />
      </div>
    </div>
  );
}

function InfoRow({
  label,
  value,
  mono,
}: {
  label: string;
  value: React.ReactNode;
  mono?: boolean;
}) {
  return (
    <div className="stops-info-row">
      <span className="stops-info-label">{label}</span>
      <span className={`stops-info-value${mono ? " font-mono text-sm" : ""}`}>{value}</span>
    </div>
  );
}
