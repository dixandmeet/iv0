"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { AlertTriangle, Bus, MapPin, Pencil, Plus, Power } from "lucide-react";
import type { StationDetail } from "@/lib/stations-types";
import { stationStatusColor, stationStatusLabel, TRANSPORT_MODE_LABELS } from "@/lib/stations-types";
import type { StopDeparture, StopServingLine } from "@/lib/stops-types";
import { formatDistanceMeters, routeBadgeStyle } from "@/lib/stops-utils";
import { StopDetailMap } from "@/components/stops/stop-detail-map";
import { Button } from "@/components/ui/button";

interface StationDetailPanelProps {
  detail: StationDetail | null;
  stopLines: Map<string, StopServingLine[]>;
  stopDepartures: Map<string, StopDeparture[]>;
  loading: boolean;
  onEditStation: () => void;
  onDisableStation: () => void;
  onAddStop: () => void;
  canManage: boolean;
}

export function StationDetailPanel({
  detail,
  stopLines,
  stopDepartures,
  loading,
  onEditStation,
  onDisableStation,
  onAddStop,
  canManage,
}: StationDetailPanelProps) {
  const router = useRouter();

  if (!detail) {
    return (
      <div className="stops-detail-empty stops-glass-card">
        <div className="stops-detail-empty-icon">
          <MapPin className="h-10 w-10" />
        </div>
        <h2>Sélectionnez une station</h2>
        <p>Choisissez une station dans la liste pour voir ses arrêts.</p>
      </div>
    );
  }

  const { station, stops } = detail;
  const center: [number, number] | null =
    station.latitude_center != null && station.longitude_center != null
      ? [station.longitude_center, station.latitude_center]
      : stops[0]
        ? [stops[0].longitude, stops[0].latitude]
        : null;

  return (
    <div className="stops-detail-panel">
      <div className="stops-detail-header stops-glass-card">
        <div>
          <h2 className="stops-detail-name">{station.name}</h2>
          <p className="stops-detail-disambiguation">
            {stops.length} arrêt{stops.length !== 1 ? "s" : ""} · {station.commune ?? "—"}
          </p>
          <div className="stops-detail-meta">
            <span
              className="stops-status-badge"
              style={{
                backgroundColor: `${stationStatusColor(station.status)}22`,
                color: stationStatusColor(station.status),
              }}
            >
              {stationStatusLabel(station.status)}
            </span>
          </div>
        </div>
        <div className="stops-detail-actions">
          <Button size="sm" variant="outline" onClick={onEditStation} disabled={!canManage}>
            <Pencil className="h-3.5 w-3.5" />
            Modifier
          </Button>
          <Button size="sm" variant="outline" onClick={onAddStop} disabled={!canManage}>
            <Plus className="h-3.5 w-3.5" />
            Ajouter un arrêt
          </Button>
          <Button size="sm" variant="outline" onClick={onDisableStation} disabled={!canManage}>
            <Power className="h-3.5 w-3.5" />
            Désactiver
          </Button>
          <Button size="sm" variant="outline" asChild>
            <Link href={`/stations/${station.id}`}>
              <Bus className="h-3.5 w-3.5" />
              Fiche complète
            </Link>
          </Button>
        </div>
      </div>

      {center && (
        <StopDetailMap
          coordinates={center}
          stopName={station.name}
          nearby={[]}
          lines={[]}
        />
      )}

      <section className="stops-glass-card p-4">
        <h3 className="mb-3 text-sm font-semibold text-slate-200">Arrêts de la station</h3>
        {loading && stops.length === 0 ? (
          <p className="text-sm text-muted-foreground">Chargement…</p>
        ) : stops.length === 0 ? (
          <p className="text-sm text-muted-foreground">Aucun arrêt rattaché.</p>
        ) : (
          <ul className="space-y-3">
            {stops.map((stop) => {
              const lines = stopLines.get(stop.id) ?? [];
              const deps = stopDepartures.get(stop.id) ?? [];
              return (
                <li key={stop.id} className="stops-homonym-item rounded-lg border border-slate-700/50 p-3">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-mono text-sm font-bold">{stop.code}</span>
                    <span className="stops-mode-pill">{TRANSPORT_MODE_LABELS[stop.transport_mode]}</span>
                    {stop.distance_m != null && (
                      <span className="text-xs text-slate-400">
                        à {formatDistanceMeters(stop.distance_m)}
                      </span>
                    )}
                    <Button
                      size="sm"
                      variant="outline"
                      className="ml-auto"
                      onClick={() => router.push(`/stations/${station.id}/arrets/${stop.id}`)}
                      disabled={!canManage}
                    >
                      <Pencil className="h-3 w-3" />
                      Modifier
                    </Button>
                  </div>
                  {stop.served_routes && stop.served_routes.length > 0 && (
                    <div className="stops-route-badges mt-2">
                      {stop.served_routes.map((r) => (
                        <span
                          key={r.route_id}
                          className="stops-route-badge"
                          style={routeBadgeStyle(r.route_color)}
                        >
                          {r.route_short_name ?? r.route_id}
                        </span>
                      ))}
                    </div>
                  )}
                  {deps.length > 0 && (
                    <p className="mt-2 text-xs text-slate-400">
                      Prochains passages :{" "}
                      {deps
                        .slice(0, 3)
                        .map((d) => `${d.route_short_name ?? d.route_id} ${d.theoretical_time}`)
                        .join(" · ")}
                    </p>
                  )}
                  {lines.length > 0 && deps.length === 0 && (
                    <p className="mt-2 text-xs text-slate-500">
                      {lines.length} ligne{lines.length > 1 ? "s" : ""} desservant cet arrêt
                    </p>
                  )}
                </li>
              );
            })}
          </ul>
        )}
      </section>

      {station.status === "inactive" && (
        <div className="stops-glass-card flex items-center gap-2 p-3 text-amber-300">
          <AlertTriangle className="h-4 w-4 shrink-0" />
          <p className="text-sm">
            Station inactive — masquée côté voyageur. Les horaires historiques sont conservés.
          </p>
        </div>
      )}
    </div>
  );
}
