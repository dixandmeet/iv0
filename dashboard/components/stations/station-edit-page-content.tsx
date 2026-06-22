"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import {
  AlertTriangle,
  ArrowLeft,
  Bus,
  Check,
  ExternalLink,
  MapPin,
  Plus,
  Power,
} from "lucide-react";
import { useStationDetail } from "@/hooks/use-station-detail";
import { useStationActions } from "@/hooks/use-station-actions";
import {
  stationStatusColor,
  stationStatusLabel,
  STATION_STATUS_LABELS,
  TRANSPORT_MODE_LABELS,
  type StationDetail,
  type StationFormPayload,
  type StationStatus,
} from "@/lib/stations-types";
import type { NearbyStop, StopServingLine } from "@/lib/stops-types";
import { routeBadgeStyle, routeTypeLabel } from "@/lib/stops-utils";
import { StopDetailMap } from "@/components/stops/stop-detail-map";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label, Select } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { ListSkeleton } from "@/components/ui/empty-state";

type StationTab = "info" | "map" | "stops" | "lines" | "quality";

const STATION_TABS: { id: StationTab; label: string }[] = [
  { id: "info", label: "Informations" },
  { id: "map", label: "Localisation" },
  { id: "stops", label: "Arrêts" },
  { id: "lines", label: "Lignes" },
  { id: "quality", label: "Qualité" },
];

interface StationEditPageContentProps {
  stationId: string;
}

interface FormState {
  name: string;
  description: string;
  commune: string;
  status: StationStatus;
  latitude: string;
  longitude: string;
}

function formFromStation(station: StationDetail["station"]): FormState {
  return {
    name: station.name,
    description: station.description ?? "",
    commune: station.commune ?? "",
    status: station.status,
    latitude: station.latitude_center != null ? String(station.latitude_center) : "",
    longitude: station.longitude_center != null ? String(station.longitude_center) : "",
  };
}

function stationSubtitle(
  stopsCount: number,
  commune: string | null | undefined,
  coords: [number, number] | null,
  linesCount: number,
): string {
  const parts = [
    `${stopsCount} arrêt${stopsCount !== 1 ? "s" : ""}`,
    commune?.trim() || "Commune non renseignée",
  ];
  if (coords) parts.push(`${coords[1].toFixed(4)}°, ${coords[0].toFixed(4)}°`);
  if (linesCount > 0) {
    parts.push(`${linesCount} ligne${linesCount !== 1 ? "s" : ""}`);
  }
  return parts.join(" · ");
}

export function StationEditPageContent({ stationId }: StationEditPageContentProps) {
  const router = useRouter();
  const { detail, stopLines, stopDepartures, loading, error, refresh } = useStationDetail(stationId);
  const { updateStation, disableStation, submitting, error: actionError } = useStationActions();

  const [form, setForm] = useState<FormState | null>(null);
  const [dirty, setDirty] = useState(false);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);
  const [validationError, setValidationError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<StationTab>("info");

  const station = detail?.station ?? null;
  const stops = useMemo(() => detail?.stops ?? [], [detail]);

  useEffect(() => {
    if (!station) return;
    setForm(formFromStation(station));
    setDirty(false);
    setSaveMessage(null);
    setValidationError(null);
  }, [station]);

  const servedLines = useMemo(() => {
    const map = new Map<string, StopServingLine>();
    for (const list of stopLines.values()) {
      for (const line of list) {
        if (!map.has(line.route_id)) map.set(line.route_id, line);
      }
    }
    // Repli : badges lignes déjà chargés sur les arrêts
    for (const stop of stops) {
      for (const route of stop.served_routes ?? []) {
        if (map.has(route.route_id)) continue;
        map.set(route.route_id, {
          route_id: route.route_id,
          route_short_name: route.route_short_name,
          route_long_name: null,
          route_type: 3,
          route_color: route.route_color,
          direction_id: null,
          trip_id: "",
          stop_sequence: 0,
          prev_stop_id: null,
          prev_stop_name: null,
          next_stop_id: null,
          next_stop_name: null,
          arrival_time: "",
          time_from_terminus_seconds: null,
        });
      }
    }
    return [...map.values()].sort((a, b) =>
      (a.route_short_name ?? a.route_id).localeCompare(b.route_short_name ?? b.route_id, "fr", {
        numeric: true,
      }),
    );
  }, [stopLines, stops]);

  const savedCenter = useMemo<[number, number] | null>(() => {
    if (!station) return null;
    if (station.latitude_center != null && station.longitude_center != null) {
      return [station.longitude_center, station.latitude_center];
    }
    const first = stops[0];
    return first ? [first.longitude, first.latitude] : null;
  }, [station, stops]);

  const mapCoordinates = useMemo<[number, number] | null>(() => {
    if (!form) return savedCenter;
    const lat = form.latitude.trim() === "" ? null : Number(form.latitude);
    const lng = form.longitude.trim() === "" ? null : Number(form.longitude);
    if (lat != null && lng != null && Number.isFinite(lat) && Number.isFinite(lng)) {
      return [lng, lat];
    }
    return savedCenter;
  }, [form, savedCenter]);

  const stopMarkers = useMemo<NearbyStop[]>(
    () =>
      stops
        .filter((s) => Number.isFinite(s.latitude) && Number.isFinite(s.longitude))
        .map((s) => ({
          stop_id: s.id,
          stop_code: s.code,
          stop_name: s.name ?? s.code,
          station_id: station?.id ?? "",
          station_name: station?.name ?? "",
          status: (s.status as NearbyStop["status"]) ?? "active",
          distance_m: 0,
          geom: {
            type: "Point" as const,
            coordinates: [s.longitude, s.latitude] as [number, number],
          },
          serving_lines: stopLines.get(s.id) ?? [],
        })),
    [stops, station, stopLines],
  );

  const allServingLines = useMemo<StopServingLine[]>(
    () => [...stopLines.values()].flat(),
    [stopLines],
  );

  const checks = useMemo(() => {
    if (!station) return [];
    const activeStops = stops.filter((s) => s.status === "active");
    return [
      {
        label: "Coordonnées renseignées",
        ok: station.latitude_center != null && station.longitude_center != null,
      },
      { label: "Au moins un arrêt associé", ok: stops.length > 0 },
      { label: "Au moins un arrêt actif", ok: activeStops.length > 0 },
      { label: "Au moins une ligne desservie", ok: servedLines.length > 0 },
      { label: "Nom de station renseigné", ok: station.name.trim().length > 0 },
    ];
  }, [station, stops, servedLines]);

  const anomalies = checks.filter((c) => !c.ok).length;

  const patchForm = useCallback((patch: Partial<FormState>) => {
    setForm((current) => (current ? { ...current, ...patch } : current));
    setDirty(true);
    setSaveMessage(null);
    setValidationError(null);
  }, []);

  const handleMapMove = useCallback((coords: [number, number]) => {
    setForm((current) =>
      current
        ? { ...current, longitude: String(coords[0]), latitude: String(coords[1]) }
        : current,
    );
    setDirty(true);
    setSaveMessage(null);
    setValidationError(null);
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form || !station) return;
    setValidationError(null);
    const lat = form.latitude.trim() === "" ? null : Number(form.latitude);
    const lng = form.longitude.trim() === "" ? null : Number(form.longitude);
    if ((lat != null && !Number.isFinite(lat)) || (lng != null && !Number.isFinite(lng))) {
      setValidationError("Latitude / longitude invalides.");
      return;
    }
    if (form.name.trim().length === 0) {
      setValidationError("Le nom de la station est obligatoire.");
      return;
    }
    const payload: Partial<StationFormPayload> = {
      name: form.name,
      description: form.description.trim() === "" ? null : form.description,
      commune: form.commune.trim() === "" ? null : form.commune,
      status: form.status,
      latitude_center: lat,
      longitude_center: lng,
    };
    try {
      await updateStation(station.id, payload);
      setDirty(false);
      setSaveMessage("Modifications enregistrées.");
      await refresh();
    } catch {
      // actionError est mis à jour par le hook
    }
  };

  const handleCancel = () => {
    if (!station) return;
    if (dirty && !confirm("Annuler les modifications non enregistrées ?")) return;
    setForm(formFromStation(station));
    setDirty(false);
    setSaveMessage(null);
    setValidationError(null);
  };

  const handleBack = () => {
    if (dirty && !confirm("Quitter sans enregistrer les modifications ?")) return;
    router.push(`/stations?station=${stationId}`);
  };

  const handleToggleStatus = async () => {
    if (!station) return;
    if (station.status === "active") {
      if (!confirm("Désactiver cette station ? Elle sera masquée côté voyageur.")) return;
      await disableStation(station.id);
    } else {
      await updateStation(station.id, { status: "active" });
    }
    await refresh();
  };

  if (loading && !station) {
    return (
      <main className="dashboard-panel stops-page stops-edit-page">
        <ListSkeleton rows={8} />
      </main>
    );
  }

  if (error || !station || !form) {
    return (
      <main className="dashboard-panel stops-page stops-edit-page">
        <div className="stops-edit-empty stops-glass-card">
          <AlertTriangle className="mx-auto mb-3 h-8 w-8 text-amber-400" />
          <h2>Station introuvable</h2>
          <p>{error ?? "Cette station n'existe pas ou n'est plus accessible."}</p>
          <div className="mt-4 flex flex-wrap justify-center gap-3">
            <Button variant="outline" onClick={() => void refresh()}>
              Réessayer
            </Button>
            <Button asChild variant="outline">
              <Link href="/stations">Retour aux stations</Link>
            </Button>
          </div>
        </div>
      </main>
    );
  }

  const isActive = station.status === "active";
  const displayError = validationError ?? actionError;

  return (
    <main className="dashboard-panel stops-page stops-edit-page">
      <header className="stops-edit-header">
        <Button type="button" variant="outline" size="sm" onClick={handleBack}>
          <ArrowLeft className="h-4 w-4" />
          Retour aux stations
        </Button>
        <div className="stops-edit-header-main">
          <p className="stops-edit-breadcrumb">
            <Link href="/stations">Stations</Link>
            <span> / </span>
            <span>{form.name || station.name}</span>
          </p>
          <h1 className="stops-edit-title">{form.name || station.name}</h1>
          <p className="stops-edit-subtitle">
            {stationSubtitle(stops.length, form.commune || station.commune, mapCoordinates, servedLines.length)}
          </p>
          <div className="stops-edit-meta">
            <span
              className="stops-status-badge"
              style={{
                backgroundColor: `${stationStatusColor(station.status)}22`,
                color: stationStatusColor(station.status),
              }}
            >
              {stationStatusLabel(station.status)}
            </span>
            {dirty && <span className="stops-edit-dirty">Modifications non enregistrées</span>}
            {saveMessage && <span className="stops-edit-saved">{saveMessage}</span>}
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {dirty && (
            <>
              <Button
                type="button"
                variant="outline"
                size="sm"
                disabled={submitting}
                onClick={handleCancel}
              >
                Annuler
              </Button>
              <Button
                type="submit"
                form="station-edit-form"
                size="sm"
                disabled={submitting}
              >
                {submitting ? "Enregistrement…" : "Enregistrer"}
              </Button>
            </>
          )}
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => router.push(`/stations/${station.id}/arrets/nouveau`)}
          >
            <Plus className="h-4 w-4" />
            Ajouter un arrêt
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => void handleToggleStatus()}
            disabled={submitting}
          >
            <Power className="h-4 w-4" />
            {isActive ? "Désactiver" : "Réactiver"}
          </Button>
        </div>
      </header>

      {!isActive && (
        <div className="stops-glass-card flex items-center gap-2 p-3 text-amber-300">
          <AlertTriangle className="h-4 w-4 shrink-0" />
          <p className="text-sm">
            Station inactive — masquée côté voyageur. Les horaires historiques sont conservés.
          </p>
        </div>
      )}

      {anomalies > 0 && (
        <div className="stops-glass-card flex items-start gap-3 border-amber-500/20 bg-amber-500/5 p-3 text-amber-200">
          <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
          <div className="min-w-0 flex-1 text-sm">
            <p className="font-medium">
              {anomalies} point{anomalies > 1 ? "s" : ""} de qualité à corriger
            </p>
            <p className="mt-0.5 text-amber-200/75">
              {checks
                .filter((c) => !c.ok)
                .map((c) => c.label.toLowerCase())
                .join(" · ")}
            </p>
          </div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="shrink-0 border-amber-500/30 text-amber-100 hover:bg-amber-500/10"
            onClick={() => setActiveTab("quality")}
          >
            Voir
          </Button>
        </div>
      )}

      <div className="station-edit-tabs">
        <nav className="stops-tab-nav" aria-label="Sections de la fiche station">
          {STATION_TABS.map((tab) => {
            let badge: string | null = null;
            if (tab.id === "stops") badge = String(stops.length);
            if (tab.id === "lines") badge = String(servedLines.length);
            if (tab.id === "quality" && anomalies > 0) badge = String(anomalies);
            return (
              <button
                key={tab.id}
                type="button"
                className={`stops-tab-btn${activeTab === tab.id ? " stops-tab-btn--active" : ""}`}
                aria-current={activeTab === tab.id ? "page" : undefined}
                onClick={() => setActiveTab(tab.id)}
              >
                {tab.label}
                {badge != null && (
                  <span
                    className={`station-tab-badge${
                      tab.id === "quality" && anomalies > 0 ? " station-tab-badge--warn" : ""
                    }`}
                  >
                    {badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        <div className="station-edit-tab-content">
          {activeTab === "info" && (
            <section className="stops-edit-form-panel stops-glass-card">
              <h2 className="stops-edit-section-title">Informations station</h2>
              <p className="stops-edit-section-hint">
                Mettez à jour le nom, la commune et le statut de la station.
              </p>
              <form id="station-edit-form" className="space-y-4" onSubmit={(e) => void handleSave(e)}>
            <div className="space-y-2">
              <Label className="text-slate-300">
                Nom de la station <span className="text-red-400">*</span>
              </Label>
              <Input
                className="station-field"
                value={form.name}
                onChange={(e) => patchForm({ name: e.target.value })}
              />
            </div>
            <div className="space-y-2">
              <Label className="text-slate-300">Description</Label>
              <Textarea
                className="station-field min-h-[70px] resize-none"
                value={form.description}
                placeholder="Description de la station…"
                onChange={(e) => patchForm({ description: e.target.value })}
              />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label className="text-slate-300">Commune</Label>
                <Input
                  className="station-field"
                  value={form.commune}
                  onChange={(e) => patchForm({ commune: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label className="text-slate-300">
                  Statut <span className="text-red-400">*</span>
                </Label>
                <Select
                  className="station-field"
                  value={form.status}
                  onChange={(e) => patchForm({ status: e.target.value as StationStatus })}
                >
                  {(Object.keys(STATION_STATUS_LABELS) as StationStatus[]).map((s) => (
                    <option key={s} value={s}>
                      {STATION_STATUS_LABELS[s]}
                    </option>
                  ))}
                </Select>
              </div>
              <div className="space-y-2">
                <Label className="text-slate-300">Latitude</Label>
                <Input
                  className="station-field"
                  value={form.latitude}
                  inputMode="decimal"
                  placeholder="47.2184"
                  onChange={(e) => patchForm({ latitude: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label className="text-slate-300">Longitude</Label>
                <Input
                  className="station-field"
                  value={form.longitude}
                  inputMode="decimal"
                  placeholder="-1.5536"
                  onChange={(e) => patchForm({ longitude: e.target.value })}
                />
              </div>
            </div>
            {displayError && (
              <p className="flex items-center gap-2 text-sm text-red-400">
                <AlertTriangle className="h-4 w-4 shrink-0" />
                {displayError}
              </p>
            )}
            <div className="stops-edit-footer">
              <Button
                type="button"
                variant="outline"
                disabled={submitting || !dirty}
                onClick={handleCancel}
              >
                Annuler
              </Button>
              <Button type="submit" disabled={submitting || !dirty}>
                {submitting ? "Enregistrement…" : "Enregistrer"}
              </Button>
            </div>
          </form>
            </section>
          )}

          {activeTab === "map" && (
            <section className="stops-edit-map-panel stops-glass-card">
          <div className="mb-3 flex flex-wrap items-start justify-between gap-3">
            <div>
              <h2 className="stops-edit-section-title">Localisation</h2>
              <p className="stops-edit-section-hint mb-0">
                Centre de station et arrêts rattachés. Glissez le marqueur bleu pour repositionner.
                Survolez un point vert pour voir ses lignes · cliquez une pastille pour isoler un tracé.
              </p>
            </div>
            {mapCoordinates && (
              <Link
                href={`https://www.google.com/maps/search/?api=1&query=${mapCoordinates[1]},${mapCoordinates[0]}`}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 text-xs text-blue-300 hover:text-blue-200"
              >
                Ouvrir dans Maps
                <ExternalLink className="h-3.5 w-3.5" />
              </Link>
            )}
          </div>
          {mapCoordinates ? (
            <>
              <StopDetailMap
                coordinates={mapCoordinates}
                stopName={form.name || station.name}
                nearby={stopMarkers}
                lines={allServingLines}
                draggable
                onMove={handleMapMove}
              />
              <div className="mt-3 flex flex-wrap items-center gap-5 text-xs text-slate-400">
                <span className="flex items-center gap-2">
                  <span className="h-2.5 w-2.5 rounded-full border-2 border-blue-200 bg-blue-500" />
                  Centre station
                </span>
                <span className="flex items-center gap-2">
                  <span className="h-2.5 w-2.5 rounded-full border-2 border-emerald-200 bg-emerald-500" />
                  Arrêt rattaché
                </span>
              </div>
            </>
          ) : (
            <div className="flex min-h-[420px] flex-col items-center justify-center gap-3 rounded-xl border border-dashed border-white/10 bg-[#0a1629]/50 px-6 text-center">
              <MapPin className="h-8 w-8 text-slate-500" />
              <p className="text-sm text-slate-400">
                Aucune coordonnée — saisissez une latitude / longitude ou déplacez le marqueur après
                la première saisie.
              </p>
            </div>
          )}
            </section>
          )}

          {activeTab === "stops" && (
            <section className="stops-glass-card p-4">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <h2 className="stops-edit-section-title mb-0">
            Arrêts associés ({stops.length})
          </h2>
        </div>
        {stops.length === 0 ? (
          <div className="rounded-xl border border-dashed border-white/10 py-10 text-center">
            <p className="text-sm text-slate-400">Aucun arrêt rattaché à cette station.</p>
            <Button
              className="mt-4"
              size="sm"
              onClick={() => router.push(`/stations/${station.id}/arrets/nouveau`)}
            >
              <Plus className="h-4 w-4" />
              Ajouter le premier arrêt
            </Button>
          </div>
        ) : (
          <ul className="space-y-3">
            {stops.map((stop) => {
              const lines = stopLines.get(stop.id) ?? [];
              const deps = stopDepartures.get(stop.id) ?? [];
              return (
                <li key={stop.id}>
                  <button
                    type="button"
                    className="stops-homonym-item w-full rounded-lg border border-slate-700/50 p-3 text-left transition-colors hover:border-blue-500/30 hover:bg-blue-500/5"
                    onClick={() => router.push(`/stations/${station.id}/arrets/${stop.id}`)}
                  >
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="font-mono text-sm font-bold text-white">{stop.code}</span>
                      <span className="font-medium text-slate-100">{stop.name ?? stop.code}</span>
                      <span className="stops-mode-pill">
                        {TRANSPORT_MODE_LABELS[stop.transport_mode]}
                      </span>
                      {stop.platform && (
                        <span className="text-xs text-slate-400">Quai {stop.platform}</span>
                      )}
                      <span
                        className="stops-status-badge ml-auto"
                        style={{
                          backgroundColor: `${stationStatusColor(stop.status as StationStatus)}22`,
                          color: stationStatusColor(stop.status as StationStatus),
                        }}
                      >
                        {stationStatusLabel(stop.status as StationStatus)}
                      </span>
                    </div>
                    {(stop.served_routes ?? []).length > 0 && (
                      <div className="stops-route-badges mt-2">
                        {(stop.served_routes ?? []).map((r) => (
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
                    {stop.is_accessible && (
                      <p className="mt-1 text-xs text-emerald-300/80">Accessible PMR</p>
                    )}
                  </button>
                </li>
              );
            })}
          </ul>
        )}
            </section>
          )}

          {activeTab === "lines" && (
            <section className="stops-glass-card p-4">
              <h2 className="stops-edit-section-title">
                Lignes desservies ({servedLines.length})
              </h2>
              {servedLines.length === 0 ? (
                <p className="mt-3 text-sm text-slate-400">Aucune ligne desservant cette station.</p>
              ) : (
                <div className="mt-3 flex flex-wrap gap-2">
                  {servedLines.map((line) => (
                    <div
                      key={line.route_id}
                      className="flex items-center gap-2 rounded-lg border border-white/[0.08] bg-[#0a1629]/60 px-3 py-2"
                      title={line.route_long_name ?? undefined}
                    >
                      <span className="stops-route-badge" style={routeBadgeStyle(line.route_color)}>
                        {line.route_short_name ?? line.route_id}
                      </span>
                      <span className="inline-flex items-center gap-1 text-xs text-slate-400">
                        <Bus className="h-3 w-3" />
                        {routeTypeLabel(line.route_type)}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </section>
          )}

          {activeTab === "quality" && (
            <section className="stops-glass-card p-4">
              <div className="mb-3 flex items-center justify-between gap-3">
                <h2 className="stops-edit-section-title mb-0">Qualité des données</h2>
                <span
                  className="stops-status-badge"
                  style={
                    anomalies === 0
                      ? { backgroundColor: "#22c55e22", color: "#22c55e" }
                      : { backgroundColor: "#f59e0b22", color: "#f59e0b" }
                  }
                >
                  {anomalies === 0 ? "Complet" : `${anomalies} à corriger`}
                </span>
              </div>
              <ul className="divide-y divide-white/[0.08]">
                {checks.map((check) => (
                  <li key={check.label} className="flex items-center gap-3 py-3 text-sm">
                    <span
                      className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full ${
                        check.ok ? "bg-emerald-500/20 text-emerald-300" : "bg-amber-500/20 text-amber-300"
                      }`}
                    >
                      {check.ok ? (
                        <Check className="h-3.5 w-3.5" />
                      ) : (
                        <AlertTriangle className="h-3.5 w-3.5" />
                      )}
                    </span>
                    <span className="flex-1 text-slate-200">{check.label}</span>
                    <span className={check.ok ? "text-emerald-300" : "text-amber-300"}>
                      {check.ok ? "OK" : "À corriger"}
                    </span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </div>
      </div>
    </main>
  );
}
