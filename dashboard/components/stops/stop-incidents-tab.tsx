"use client";

import { useState } from "react";
import Link from "next/link";
import { AlertTriangle, Plus } from "lucide-react";
import type { NetworkIncident } from "@/lib/types";
import { severityColor, severityLabel } from "@/lib/types";
import { STOP_INCIDENT_TYPES } from "@/lib/stops-types";
import { createClient } from "@/lib/supabase/client";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label, Select } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { EmptyState } from "@/components/ui/empty-state";

interface StopIncidentsTabProps {
  stopId: string;
  stopUuid?: string;
  stopName: string;
  incidents: NetworkIncident[];
  coordinates: [number, number] | null;
  onRefresh: () => void;
}

export function StopIncidentsTab({
  stopId,
  stopUuid,
  stopName,
  incidents,
  coordinates,
  onRefresh,
}: StopIncidentsTabProps) {
  const [showForm, setShowForm] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({
    incident_type: "stop_disruption",
    severity: "warning" as NetworkIncident["severity"],
    title: "",
    description: "",
  });

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.title.trim()) return;
    setSubmitting(true);
    const supabase = createClient();
    const { data: { user } } = await supabase.auth.getUser();
    await supabase.from("network_incidents").insert({
      incident_type: form.incident_type,
      severity: form.severity,
      title: form.title.trim(),
      description: form.description.trim() || null,
      geom: coordinates ? { type: "Point", coordinates } : null,
      source: "regulator",
      reported_by: user?.id,
      status: "open",
      metadata: {
        stop_code: stopId,
        stop_uuid: stopUuid ?? null,
        stop_id: stopId,
      },
    });
    setShowForm(false);
    setForm({ incident_type: "stop_disruption", severity: "warning", title: "", description: "" });
    setSubmitting(false);
    onRefresh();
  };

  return (
    <div className="stops-incidents-tab">
      <div className="stops-incidents-actions">
        <Button size="sm" onClick={() => setShowForm(!showForm)}>
          <Plus className="h-4 w-4" />
          Créer un incident
        </Button>
        <Button size="sm" variant="outline" asChild>
          <Link href={`/incidents?create=1&stop=${stopId}`}>Ouvrir dans Incidents</Link>
        </Button>
      </div>

      {showForm && (
        <form onSubmit={handleCreate} className="stops-incident-form stops-glass-card">
          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-1.5">
              <Label>Type</Label>
              <Select
                value={form.incident_type}
                onChange={(e) => setForm((f) => ({ ...f, incident_type: e.target.value }))}
              >
                {STOP_INCIDENT_TYPES.map((t) => (
                  <option key={t.value} value={t.value}>
                    {t.label}
                  </option>
                ))}
              </Select>
            </div>
            <div className="space-y-1.5">
              <Label>Sévérité</Label>
              <Select
                value={form.severity}
                onChange={(e) =>
                  setForm((f) => ({
                    ...f,
                    severity: e.target.value as NetworkIncident["severity"],
                  }))
                }
              >
                <option value="info">Info</option>
                <option value="warning">Alerte</option>
                <option value="critical">Critique</option>
              </Select>
            </div>
          </div>
          <div className="space-y-1.5">
            <Label>Titre</Label>
            <Input
              value={form.title}
              onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
              placeholder={`Incident — ${stopName}`}
            />
          </div>
          <div className="space-y-1.5">
            <Label>Description</Label>
            <Textarea
              value={form.description}
              onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
              rows={2}
            />
          </div>
          <Button type="submit" disabled={submitting}>
            {submitting ? "Création…" : "Créer"}
          </Button>
        </form>
      )}

      {incidents.length === 0 ? (
        <EmptyState icon={AlertTriangle} title="Aucun incident actif" description="Aucune perturbation signalée sur cet arrêt." />
      ) : (
        <ul className="stops-incident-list">
          {incidents.map((inc) => (
            <li key={inc.id} className="stops-incident-item stops-glass-card">
              <div className="flex items-start justify-between gap-2">
                <div>
                  <p className="font-medium">{inc.title}</p>
                  <p className="text-xs text-muted-foreground">{inc.description}</p>
                </div>
                <Badge style={{ color: severityColor(inc.severity) }}>
                  {severityLabel(inc.severity)}
                </Badge>
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
