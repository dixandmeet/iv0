"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, Power } from "lucide-react";
import { useStopDetail } from "@/hooks/use-stop-detail";
import { useStopActions } from "@/hooks/use-stop-actions";
import type { StopFormPayload } from "@/lib/stops-types";
import { stopStatusColor, stopStatusLabel } from "@/lib/stops-types";
import { stopDisambiguationLine } from "@/lib/stops-utils";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { StopDetailMap } from "@/components/stops/stop-detail-map";
import { EMPTY_STOP_FORM, StopForm, stopToFormPayload } from "@/components/stops/stop-form";
import { Button } from "@/components/ui/button";
import { ListSkeleton } from "@/components/ui/empty-state";
import { useNetwork } from "@/components/network/network-provider";

interface StopEditPageContentProps {
  stationId: string;
  stopId: string;
}

export function StopEditPageContent({ stationId, stopId }: StopEditPageContentProps) {
  const router = useRouter();
  const { canManage } = useNetwork();
  const { stop, lines, nearby, loading, error, refresh } = useStopDetail(stopId);
  const { updateStop, disableStop, submitting, error: actionError } = useStopActions();
  const [form, setForm] = useState<StopFormPayload>(EMPTY_STOP_FORM);
  const [dirty, setDirty] = useState(false);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!stop) return;
    if (stop.station_id !== stationId) return;
    setForm(stopToFormPayload(stop));
    setDirty(false);
  }, [stop, stationId]);

  const handleChange = useCallback((next: StopFormPayload) => {
    setForm(next);
    setDirty(true);
    setSaveMessage(null);
  }, []);

  const handleMapMove = useCallback((coords: [number, number]) => {
    setForm((current) => ({ ...current, coordinates: coords }));
    setDirty(true);
    setSaveMessage(null);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.code.trim()) return;
    try {
      await updateStop(stopId, form);
      setDirty(false);
      setSaveMessage("Modifications enregistrées.");
      await refresh();
    } catch {
      // Le hook expose l'erreur dans la bannière ; éviter une erreur runtime non interceptée.
    }
  };

  const handleDisable = async () => {
    if (!confirm("Désactiver cet arrêt ?")) return;
    try {
      await disableStop(stopId);
      router.push(`/stations?station=${stationId}`);
    } catch {
      // Le hook expose l'erreur dans la bannière ; rester sur la page courante.
    }
  };

  const handleCancel = () => {
    if (dirty && !confirm("Quitter sans enregistrer les modifications ?")) return;
    router.push(`/stations?station=${stationId}`);
  };

  if (loading && !stop) {
    return (
      <main className="dashboard-panel stops-page stops-edit-page">
        <ListSkeleton rows={8} />
      </main>
    );
  }

  if (!stop || stop.station_id !== stationId) {
    return (
      <main className="dashboard-panel stops-page stops-edit-page">
        <div className="stops-edit-empty stops-glass-card">
          <h2>Arrêt introuvable</h2>
          <p>Cet arrêt n&apos;existe pas ou n&apos;appartient pas à cette station.</p>
          <Button asChild variant="outline">
            <Link href={`/stations?station=${stationId}`}>Retour à la station</Link>
          </Button>
        </div>
      </main>
    );
  }

  const displayName = stop.name ?? stop.station_name ?? stop.code;

  if (!canManage) {
    return (
      <main className="dashboard-panel stops-page stops-edit-page">
        <div className="stops-edit-empty stops-glass-card">
          <h2>Accès en lecture seule</h2>
          <p>
            Vous pouvez consulter {displayName}, mais vous devez être administrateur du réseau
            pour modifier cet arrêt.
          </p>
          <Button asChild variant="outline">
            <Link href={`/stations?station=${stationId}`}>Retour aux arrêts</Link>
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
          Retour à la station
        </Button>
        <div className="stops-edit-header-main">
          <p className="stops-edit-breadcrumb">
            <Link href="/stations">Stations</Link>
            <span> / </span>
            <Link href={`/stations?station=${stationId}`}>{stop.station_name}</Link>
            <span> / </span>
            <span>{displayName}</span>
          </p>
          <h1 className="stops-edit-title">{displayName}</h1>
          <p className="stops-edit-subtitle">{stopDisambiguationLine(stop)}</p>
          <div className="stops-edit-meta">
            <span className="font-mono text-sm">{stop.code}</span>
            <span
              className="stops-status-badge"
              style={{
                backgroundColor: `${stopStatusColor(stop.status)}22`,
                color: stopStatusColor(stop.status),
              }}
            >
              {stopStatusLabel(stop.status)}
            </span>
            {dirty && <span className="stops-edit-dirty">Modifications non enregistrées</span>}
            {saveMessage && <span className="stops-edit-saved">{saveMessage}</span>}
          </div>
        </div>
        <Button type="button" variant="outline" size="sm" onClick={handleDisable} disabled={submitting}>
          <Power className="h-4 w-4" />
          Désactiver
        </Button>
      </header>

      <div className="stops-edit-layout">
        <section className="stops-edit-form-panel stops-glass-card">
          <h2 className="stops-edit-section-title">Informations opérationnelles</h2>
          <p className="stops-edit-section-hint">
            Mettez à jour le statut, l&apos;adresse et les caractéristiques du quai.
            Déplacez le marqueur sur la carte pour ajuster la position GPS.
          </p>
          <StopForm
            mode="edit"
            form={form}
            onChange={handleChange}
            onSubmit={handleSubmit}
            submitting={submitting}
            onCancel={handleCancel}
            layout="page"
          />
        </section>

        <section className="stops-edit-map-panel stops-glass-card">
          <h2 className="stops-edit-section-title">Position sur la carte</h2>
          <StopDetailMap
            coordinates={form.coordinates}
            stopName={displayName}
            nearby={nearby}
            lines={lines}
            draggable
            onMove={handleMapMove}
          />
        </section>
      </div>
    </main>
  );
}
