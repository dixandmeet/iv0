"use client";

import { useState } from "react";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label, Select } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useIncidentActions } from "@/hooks/use-incident-actions";
import type { GtfsRoute, NetworkIncident } from "@/lib/types";

const INCIDENT_TYPES = [
  { value: "delay", label: "Retard" },
  { value: "disruption", label: "Perturbation" },
  { value: "crowding", label: "Affluence" },
  { value: "breakdown", label: "Panne" },
  { value: "accident", label: "Accident" },
  { value: "safety", label: "Sécurité" },
  { value: "other", label: "Autre" },
];

interface IncidentCreateFormProps {
  routes: GtfsRoute[];
  onCreated?: (incident: NetworkIncident) => void;
  defaultRouteId?: string;
}

export function IncidentCreateForm({
  routes,
  onCreated,
  defaultRouteId,
}: IncidentCreateFormProps) {
  const [open, setOpen] = useState(false);
  const { createIncident, submitting, error } = useIncidentActions();
  const [form, setForm] = useState({
    incident_type: "disruption",
    severity: "warning" as NetworkIncident["severity"],
    title: "",
    description: "",
    route_id: defaultRouteId ?? "",
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.title.trim()) return;

    const incident = await createIncident({
      incident_type: form.incident_type,
      severity: form.severity,
      title: form.title.trim(),
      description: form.description.trim() || undefined,
      route_id: form.route_id || null,
    });

    setForm({
      incident_type: "disruption",
      severity: "warning",
      title: "",
      description: "",
      route_id: defaultRouteId ?? "",
    });
    setOpen(false);
    onCreated?.(incident);
  };

  if (!open) {
    return (
      <Button size="sm" className="gap-2" onClick={() => setOpen(true)}>
        <Plus className="h-4 w-4" />
        Créer un incident
      </Button>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="rounded-xl border border-border bg-card p-4 space-y-3"
    >
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold">Nouvel incident</h3>
        <Button variant="ghost" size="sm" className="h-7 text-xs" onClick={() => setOpen(false)}>
          Annuler
        </Button>
      </div>

      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label>Type</Label>
          <Select
            value={form.incident_type}
            onChange={(e) => setForm((f) => ({ ...f, incident_type: e.target.value }))}
          >
            {INCIDENT_TYPES.map((t) => (
              <option key={t.value} value={t.value}>{t.label}</option>
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
          placeholder="Ex. Retard important — Ligne C4"
          required
        />
      </div>

      <div className="space-y-1.5">
        <Label>Description</Label>
        <Textarea
          value={form.description}
          onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
          placeholder="Détails opérationnels…"
          rows={3}
        />
      </div>

      <div className="space-y-1.5">
        <Label>Ligne impactée</Label>
        <Select
          value={form.route_id}
          onChange={(e) => setForm((f) => ({ ...f, route_id: e.target.value }))}
        >
          <option value="">Réseau entier</option>
          {routes.map((r) => (
            <option key={r.route_id} value={r.route_id}>
              {r.route_short_name ?? r.route_id} — {r.route_long_name ?? ""}
            </option>
          ))}
        </Select>
      </div>

      {error && <p className="text-xs text-destructive">{error}</p>}

      <Button type="submit" disabled={submitting || !form.title.trim()} className="w-full">
        {submitting ? "Création…" : "Créer l'incident"}
      </Button>
    </form>
  );
}
