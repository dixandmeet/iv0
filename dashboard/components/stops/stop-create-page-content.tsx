"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { useStationDetail } from "@/hooks/use-station-detail";
import { useStopActions } from "@/hooks/use-stop-actions";
import type { StopFormPayload } from "@/lib/stops-types";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { EMPTY_STOP_FORM, StopForm } from "@/components/stops/stop-form";
import { StopDetailMap } from "@/components/stops/stop-detail-map";
import { Button } from "@/components/ui/button";
import { ListSkeleton } from "@/components/ui/empty-state";

interface StopCreatePageContentProps {
  stationId: string;
}

export function StopCreatePageContent({ stationId }: StopCreatePageContentProps) {
  const router = useRouter();
  const { detail, loading, error, refresh } = useStationDetail(stationId);
  const { createStop, submitting, error: actionError } = useStopActions();
  const [form, setForm] = useState<StopFormPayload>(EMPTY_STOP_FORM);

  const station = detail?.station;

  useEffect(() => {
    if (station?.latitude_center == null || station.longitude_center == null) return;
    setForm((f) => ({
      ...f,
      coordinates: [station.longitude_center!, station.latitude_center!],
    }));
  }, [station?.id, station?.latitude_center, station?.longitude_center]);

  const handleMapMove = useCallback((coords: [number, number]) => {
    setForm((current) => ({ ...current, coordinates: coords }));
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.code.trim()) return;
    const id = await createStop(stationId, form);
    router.push(`/stations/${stationId}/arrets/${id}`);
  };

  const handleCancel = () => {
    router.push(`/stations?station=${stationId}`);
  };

  if (loading && !detail) {
    return (
      <main className="dashboard-panel stops-page stops-edit-page">
        <ListSkeleton rows={8} />
      </main>
    );
  }

  if (!detail) {
    return (
      <main className="dashboard-panel stops-page stops-edit-page">
        <div className="stops-edit-empty stops-glass-card">
          <h2>Station introuvable</h2>
          <Button asChild variant="outline">
            <Link href="/stations">Retour</Link>
          </Button>
        </div>
      </main>
    );
  }

  return (
    <main className="dashboard-panel stops-page stops-edit-page">
      {(error || actionError) && (
        <ErrorBanner message={error ?? actionError ?? ""} onRetry={refresh} />
      )}

      <header className="stops-edit-header">
        <Button type="button" variant="outline" size="sm" onClick={handleCancel}>
          <ArrowLeft className="h-4 w-4" />
          Retour
        </Button>
        <div className="stops-edit-header-main">
          <p className="stops-edit-breadcrumb">
            <Link href="/stations">Stations</Link>
            <span> / </span>
            <span>{detail.station.name}</span>
            <span> / Nouvel arrêt</span>
          </p>
          <h1 className="stops-edit-title">Ajouter un arrêt — {detail.station.name}</h1>
        </div>
      </header>

      <div className="stops-edit-layout">
        <section className="stops-edit-form-panel stops-glass-card">
          <StopForm
            mode="create"
            form={form}
            onChange={setForm}
            onSubmit={handleSubmit}
            submitting={submitting}
            onCancel={handleCancel}
            layout="page"
          />
        </section>
        <section className="stops-edit-map-panel stops-glass-card">
          <StopDetailMap
            coordinates={form.coordinates}
            stopName={form.name ?? form.code}
            nearby={[]}
            lines={[]}
            draggable
            onMove={handleMapMove}
          />
        </section>
      </div>
    </main>
  );
}
