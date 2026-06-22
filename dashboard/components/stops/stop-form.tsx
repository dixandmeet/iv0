"use client";

import type { StopFormPayload } from "@/lib/stops-types";
import type { StopListItem } from "@/lib/stops-types";
import { STOP_STATUS_LABELS } from "@/lib/stops-types";
import type { StopStatus } from "@/lib/stops-types";
import { STOP_SOURCE_LABELS, TRANSPORT_MODE_LABELS } from "@/lib/stations-types";
import type { StopSource, StopTransportMode } from "@/lib/stations-types";
import { pointCoordinates } from "@/lib/geo";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label, Select } from "@/components/ui/label";

const MODES: StopTransportMode[] = ["bus", "tram", "train", "ferry", "metro"];
const SOURCES: StopSource[] = ["manual", "gtfs", "temporary", "works", "community"];

export interface StopFormProps {
  mode: "create" | "edit";
  form: StopFormPayload;
  onChange: (form: StopFormPayload) => void;
  onSubmit: (e: React.FormEvent) => void;
  submitting: boolean;
  onCancel?: () => void;
  layout?: "modal" | "page";
}

export function StopForm({
  mode,
  form,
  onChange,
  onSubmit,
  submitting,
  onCancel,
  layout = "modal",
}: StopFormProps) {
  return (
    <form onSubmit={onSubmit} className={`stops-form stops-form--${layout}`}>
      <div className="grid gap-3 sm:grid-cols-2">
        <div className="space-y-1.5">
          <Label>Code arrêt</Label>
          <Input
            value={form.code}
            onChange={(e) => onChange({ ...form, code: e.target.value.toUpperCase() })}
            disabled={mode === "edit"}
            required
            maxLength={16}
          />
        </div>
        <div className="space-y-1.5">
          <Label>Nom (optionnel)</Label>
          <Input
            value={form.name ?? ""}
            onChange={(e) => onChange({ ...form, name: e.target.value || null })}
          />
        </div>
        <div className="space-y-1.5">
          <Label>Statut</Label>
          <Select
            value={form.status}
            onChange={(e) => onChange({ ...form, status: e.target.value as StopStatus })}
          >
            {(Object.keys(STOP_STATUS_LABELS) as StopStatus[]).map((s) => (
              <option key={s} value={s}>
                {STOP_STATUS_LABELS[s]}
              </option>
            ))}
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label>Provenance</Label>
          <Select
            value={form.source}
            onChange={(e) => onChange({ ...form, source: e.target.value as StopSource })}
            disabled={mode === "edit"}
          >
            {SOURCES.map((s) => (
              <option key={s} value={s}>
                {STOP_SOURCE_LABELS[s]}
              </option>
            ))}
          </Select>
        </div>
        <div className="space-y-1.5 sm:col-span-2">
          <Label>Adresse</Label>
          <Input
            value={form.address ?? ""}
            onChange={(e) => onChange({ ...form, address: e.target.value })}
          />
        </div>
        <div className="space-y-1.5">
          <Label>Quai / plateforme</Label>
          <Input
            value={form.platform ?? ""}
            onChange={(e) => onChange({ ...form, platform: e.target.value || null })}
          />
        </div>
        <div className="space-y-1.5">
          <Label>Mode de transport</Label>
          <Select
            value={form.transport_mode}
            onChange={(e) =>
              onChange({ ...form, transport_mode: e.target.value as StopTransportMode })
            }
          >
            {MODES.map((m) => (
              <option key={m} value={m}>
                {TRANSPORT_MODE_LABELS[m]}
              </option>
            ))}
          </Select>
        </div>
        <div className="space-y-1.5">
          <Label>Latitude</Label>
          <Input
            type="number"
            step="any"
            value={form.coordinates[1]}
            onChange={(e) =>
              onChange({
                ...form,
                coordinates: [form.coordinates[0], parseFloat(e.target.value) || 0],
              })
            }
          />
        </div>
        <div className="space-y-1.5">
          <Label>Longitude</Label>
          <Input
            type="number"
            step="any"
            value={form.coordinates[0]}
            onChange={(e) =>
              onChange({
                ...form,
                coordinates: [parseFloat(e.target.value) || 0, form.coordinates[1]],
              })
            }
          />
        </div>
        <div className="space-y-1.5">
          <Label>Zone tarifaire</Label>
          <Input
            value={form.tariff_zone ?? ""}
            onChange={(e) => onChange({ ...form, tariff_zone: e.target.value })}
          />
        </div>
        <div className="space-y-1.5">
          <Label>Accessibilité PMR</Label>
          <Select
            value={form.is_accessible ? "1" : "0"}
            onChange={(e) =>
              onChange({ ...form, is_accessible: e.target.value === "1" })
            }
          >
            <option value="0">Non accessible / inconnue</option>
            <option value="1">Accessible</option>
          </Select>
        </div>
      </div>
      <div className={layout === "page" ? "stops-edit-footer" : "stops-modal-footer"}>
        {onCancel && (
          <Button type="button" variant="outline" onClick={onCancel}>
            Annuler
          </Button>
        )}
        <Button type="submit" disabled={submitting}>
          {submitting ? "Enregistrement…" : mode === "create" ? "Créer" : "Enregistrer"}
        </Button>
      </div>
    </form>
  );
}

export function stopToFormPayload(stop: StopListItem): StopFormPayload {
  const coords = pointCoordinates(stop.geom) ?? [stop.longitude, stop.latitude];
  return {
    code: stop.code,
    name: stop.name,
    status: stop.status,
    address: stop.address ?? "",
    tariff_zone: stop.tariff_zone ?? "",
    platform: stop.platform,
    transport_mode: stop.transport_mode,
    source: stop.source,
    is_accessible: stop.is_accessible,
    coordinates: coords,
  };
}

export const EMPTY_STOP_FORM: StopFormPayload = {
  code: "",
  name: null,
  status: "active",
  address: "",
  tariff_zone: "",
  platform: null,
  transport_mode: "bus",
  source: "manual",
  is_accessible: false,
  coordinates: [-1.5536, 47.2184],
};
