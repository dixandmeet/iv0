"use client";

import {
  Accessibility,
  ArrowRightLeft,
  Flag,
  GitBranchPlus,
  Loader2,
  MapPin,
  Route,
  Signpost,
  SlidersHorizontal,
  Trash2,
} from "lucide-react";
import {
  POINT_TYPE_COLORS,
  POINT_TYPE_LABELS,
  type LineBranch,
  type LineOriginLeg,
  type PointType,
  type PassageDetails,
  type RoutePoint,
  type StopDirection,
} from "@/lib/line-editor-types";
import { branchesFromHub, hubsOnTrunk, originLegsFromHub } from "@/lib/line-editor-branches";
import {
  isStopType,
  pointRouteLabel,
  pointsAfterInRoute,
} from "@/lib/line-editor-utils";
import type { RegisteredStop } from "@/lib/registered-stops";
import { useRegisteredStopsCatalog } from "@/hooks/use-registered-stops-catalog";
import { PointCoordinatesField } from "./point-coordinates-field";
import { StopNameAutocomplete } from "./stop-name-autocomplete";

interface LineEditorSidebarProps {
  selectedPoint: RoutePoint | null;
  allPoints: RoutePoint[];
  trunkStops: RoutePoint[];
  branches: LineBranch[];
  originLegs: LineOriginLeg[];
  activeBranchId: string | null;
  activeOriginLegId: string | null;
  stopPosition: number | null;
  totalStops: number;
  onUpdateType: (type: PointType) => void;
  onUpdateStop: (patch: Partial<NonNullable<RoutePoint["stop"]>>) => void;
  onUpdatePassage: (patch: Partial<PassageDetails>) => void;
  onDelete: () => void;
  onTransformToStop: () => void;
  onSetTerminus: (which: "start" | "end") => void;
  onAddBranch: (hubPointId: string) => void;
  onAddOriginLeg: (hubPointId: string) => void;
  onAttachAsOriginLeg: (pointId: string, hubPointId: string) => void;
  onDeleteBranch: (branchId: string) => void;
  onDeleteOriginLeg: (legId: string) => void;
  onSelectBranch: (branchId: string | null) => void;
  onSelectOriginLeg: (legId: string | null) => void;
  onUpdateBranchMeta: (branchId: string, patch: Partial<Pick<LineBranch, "label" | "terminusName">>) => void;
  onUpdateOriginLegMeta: (legId: string, patch: Partial<Pick<LineOriginLeg, "label">>) => void;
  onCommitCoordinates: (coordinates: [number, number]) => void;
  onSelectRegisteredStop: (stop: RegisteredStop) => void;
  tracePickerActive?: boolean;
  tracing?: boolean;
  onStartTracePicker?: () => void;
  onCancelTracePicker?: () => void;
  onTraceSegmentTo?: (targetPointId: string) => void;
}

const POINT_TYPES: PointType[] = [
  "passage",
  "stop",
  "terminus_start",
  "terminus_end",
  "hub",
];

export function LineEditorSidebar({
  selectedPoint,
  allPoints,
  trunkStops,
  branches,
  originLegs,
  activeBranchId,
  activeOriginLegId,
  stopPosition,
  totalStops,
  onUpdateType,
  onUpdateStop,
  onUpdatePassage,
  onDelete,
  onTransformToStop,
  onSetTerminus,
  onAddBranch,
  onAddOriginLeg,
  onAttachAsOriginLeg,
  onDeleteBranch,
  onDeleteOriginLeg,
  onSelectBranch,
  onSelectOriginLeg,
  onUpdateBranchMeta,
  onUpdateOriginLegMeta,
  onCommitCoordinates,
  onSelectRegisteredStop,
  tracePickerActive = false,
  tracing = false,
  onStartTracePicker,
  onCancelTracePicker,
  onTraceSegmentTo,
}: LineEditorSidebarProps) {
  const isHub = selectedPoint?.type === "hub";
  const hubBranches = selectedPoint
    ? branchesFromHub(branches, selectedPoint.id)
    : [];
  const hubOriginLegs = selectedPoint
    ? originLegsFromHub(originLegs, selectedPoint.id)
    : [];
  const activeBranch = activeBranchId
    ? branches.find((b) => b.id === activeBranchId) ?? null
    : null;
  const activeOriginLeg = activeOriginLegId
    ? originLegs.find((l) => l.id === activeOriginLegId) ?? null
    : null;
  const trunkHubs = hubsOnTrunk(trunkStops);
  const isOnTrunk =
    selectedPoint != null &&
    !activeBranchId &&
    !activeOriginLegId &&
    trunkStops.some((s) => s.id === selectedPoint.id);
  const isStop = selectedPoint ? isStopType(selectedPoint.type) : false;
  const isPassage = selectedPoint?.type === "passage";
  const downstreamPoints = selectedPoint
    ? pointsAfterInRoute(allPoints, selectedPoint.id)
    : [];
  const { catalog, loading: catalogLoading } = useRegisteredStopsCatalog(allPoints);

  return (
    <aside className="line-editor-sidebar">
      <div className="line-editor-inspector-kicker">
        <SlidersHorizontal className="h-3.5 w-3.5" />
        Inspecteur
      </div>

      {!selectedPoint ? (
        <div className="line-editor-sidebar-empty">
          <div className="line-editor-sidebar-empty-icon">
            <MapPin className="h-5 w-5" />
          </div>
          <h3>Aucune sélection</h3>
          <p>Sélectionnez un élément sur la carte ou dans le parcours.</p>
        </div>
      ) : (
        <>
          <div className="line-editor-sidebar-header">
            <div
              className="line-editor-point-indicator"
              style={{ background: POINT_TYPE_COLORS[selectedPoint.type] }}
            />
            <div>
              <h3 className="line-editor-sidebar-title">
                {POINT_TYPE_LABELS[selectedPoint.type]}
              </h3>
            </div>
          </div>

          {isPassage && (
            <div className="line-editor-card">
              <h4 className="line-editor-card-title">
                <MapPin className="h-4 w-4" />
                Propriétés GPS
              </h4>
              <div className="line-editor-form-grid">
                <Field label="Nom" className="col-span-2">
                  <input
                    className="line-editor-input"
                    value={selectedPoint.gps?.name ?? ""}
                    onChange={(e) => onUpdatePassage({ name: e.target.value })}
                    placeholder="Ex. Virage quai de la Fosse"
                  />
                </Field>
                <Field label="Rayon GPS (m)">
                  <input
                    className="line-editor-input"
                    type="number"
                    min={1}
                    value={selectedPoint.gps?.radiusMeters ?? 15}
                    onChange={(e) =>
                      onUpdatePassage({ radiusMeters: Number(e.target.value) || 1 })
                    }
                  />
                </Field>
                <Field label="Temps estimé (min)">
                  <input
                    className="line-editor-input"
                    type="number"
                    min={0}
                    value={selectedPoint.gps?.estimatedMinutes ?? 1}
                    onChange={(e) =>
                      onUpdatePassage({ estimatedMinutes: Number(e.target.value) || 0 })
                    }
                  />
                </Field>
                <Field label="Commentaires" className="col-span-2">
                  <textarea
                    className="line-editor-textarea"
                    rows={3}
                    value={selectedPoint.gps?.notes ?? ""}
                    onChange={(e) => onUpdatePassage({ notes: e.target.value })}
                    placeholder="Précisions d’exploitation…"
                  />
                </Field>
              </div>
            </div>
          )}

          <div className="line-editor-card">
            <label className="line-editor-field-label">Type de point</label>
            <div className="line-editor-type-grid">
              {POINT_TYPES.map((type) => (
                <button
                  key={type}
                  type="button"
                  className={`line-editor-type-chip${selectedPoint.type === type ? " active" : ""}`}
                  style={
                    selectedPoint.type === type
                      ? {
                          borderColor: POINT_TYPE_COLORS[type],
                          background: `${POINT_TYPE_COLORS[type]}20`,
                          color: POINT_TYPE_COLORS[type],
                        }
                      : undefined
                  }
                  onClick={() => onUpdateType(type)}
                >
                  <span
                    className="line-editor-type-dot"
                    style={{ background: POINT_TYPE_COLORS[type] }}
                  />
                  {POINT_TYPE_LABELS[type]}
                </button>
              ))}
            </div>
            {selectedPoint.type === "passage" && (
              <p className="line-editor-passage-hint">
                Ce point façonne le tracé mais n&apos;apparaît pas dans le plan
                de ligne. Transformez-le en arrêt pour l&apos;y inclure.
              </p>
            )}
          </div>

          {isPassage && onStartTracePicker && onTraceSegmentTo && (
            <div className="line-editor-card">
              <h4 className="line-editor-card-title">
                <Route className="h-4 w-4" />
                Proposer un tracé
              </h4>
              <p className="line-editor-segment-trace-hint">
                Trace un parcours sur les voies depuis ce point jusqu&apos;à un
                autre point de la ligne (arrêt, terminus, passage…).
              </p>
              {tracePickerActive ? (
                <div className="line-editor-segment-trace-active">
                  <p>Cliquez sur la destination sur la carte ou choisissez-la ci-dessous.</p>
                  <button
                    type="button"
                    className="line-editor-btn-secondary line-editor-btn-full"
                    onClick={onCancelTracePicker}
                    disabled={tracing}
                  >
                    Annuler
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  className="line-editor-action-btn line-editor-btn-full"
                  onClick={onStartTracePicker}
                  disabled={tracing || downstreamPoints.length === 0}
                >
                  {tracing ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Route className="h-4 w-4" />
                  )}
                  Choisir la destination sur la carte
                </button>
              )}
              {downstreamPoints.length > 0 && (
                <label className="line-editor-field">
                  <span className="line-editor-field-label">Destination rapide</span>
                  <select
                    className="line-editor-input"
                    defaultValue=""
                    disabled={tracing}
                    onChange={(e) => {
                      const targetId = e.target.value;
                      if (!targetId) return;
                      onTraceSegmentTo(targetId);
                      e.target.value = "";
                    }}
                  >
                    <option value="">— Choisir un point —</option>
                    {downstreamPoints.map((point) => (
                      <option key={point.id} value={point.id}>
                        {pointRouteLabel(point, allPoints)} ({POINT_TYPE_LABELS[point.type]})
                      </option>
                    ))}
                  </select>
                </label>
              )}
            </div>
          )}

          {isStop && selectedPoint.stop && (
            <div className="line-editor-card">
              <h4 className="line-editor-card-title">
                <MapPin className="h-4 w-4" />
                Informations arrêt
              </h4>
              <div className="line-editor-form-grid">
                <Field label="Nom de l'arrêt">
                  <StopNameAutocomplete
                    value={selectedPoint.stop.name}
                    catalog={catalog}
                    catalogLoading={catalogLoading}
                    onChange={(name) => onUpdateStop({ name })}
                    onSelectStop={onSelectRegisteredStop}
                    onCreateStop={(name) => onUpdateStop({ name })}
                  />
                </Field>
                <Field label="Code arrêt">
                  <input
                    className="line-editor-input"
                    value={selectedPoint.stop.code}
                    onChange={(e) => onUpdateStop({ code: e.target.value })}
                    placeholder="Ex. COM01"
                  />
                </Field>
                <Field label="Sens concerné">
                  <select
                    className="line-editor-input"
                    value={selectedPoint.stop.direction}
                    onChange={(e) =>
                      onUpdateStop({
                        direction: e.target.value as StopDirection,
                      })
                    }
                  >
                    <option value="aller">Aller</option>
                    <option value="retour">Retour</option>
                    <option value="both">Les deux</option>
                  </select>
                </Field>
                <Field label="Position dans la ligne">
                  <input
                    className="line-editor-input line-editor-input--readonly"
                    readOnly
                    value={
                      stopPosition != null
                        ? `${stopPosition + 1} / ${totalStops}`
                        : "—"
                    }
                  />
                </Field>
                <Field label="Temps depuis l'arrêt précédent (min)">
                  <input
                    className="line-editor-input"
                    type="number"
                    min={0}
                    value={selectedPoint.stop.travelTimeMinutes}
                    onChange={(e) =>
                      onUpdateStop({
                        travelTimeMinutes: Number(e.target.value) || 0,
                      })
                    }
                  />
                </Field>
                <label className="line-editor-checkbox">
                  <input
                    type="checkbox"
                    checked={selectedPoint.stop.wheelchairAccessible}
                    onChange={(e) =>
                      onUpdateStop({ wheelchairAccessible: e.target.checked })
                    }
                  />
                  <Accessibility className="h-4 w-4" />
                  Accessibilité PMR
                </label>
                <Field label="Correspondances" className="col-span-2">
                  <input
                    className="line-editor-input"
                    value={selectedPoint.stop.connections}
                    onChange={(e) =>
                      onUpdateStop({ connections: e.target.value })
                    }
                    placeholder="Lignes en correspondance"
                  />
                </Field>
                <Field label="Notes internes" className="col-span-2">
                  <textarea
                    className="line-editor-textarea"
                    rows={3}
                    value={selectedPoint.stop.notes}
                    onChange={(e) => onUpdateStop({ notes: e.target.value })}
                    placeholder="Notes pour les régulateurs…"
                  />
                </Field>
              </div>
            </div>
          )}

          <div className="line-editor-card">
            <PointCoordinatesField
              coordinates={selectedPoint.coordinates}
              onCommit={onCommitCoordinates}
            />
          </div>

          {activeOriginLeg && (
            <div className="line-editor-card">
              <h4 className="line-editor-card-title">
                <Signpost className="h-4 w-4" />
                Point de départ actif
              </h4>
              <div className="line-editor-form-grid">
                <Field label="Libellé du départ">
                  <input
                    className="line-editor-input"
                    value={activeOriginLeg.label}
                    onChange={(e) =>
                      onUpdateOriginLegMeta(activeOriginLeg.id, { label: e.target.value })
                    }
                    placeholder="Ex. Beaujoire"
                  />
                </Field>
              </div>
              <button
                type="button"
                className="line-editor-btn-danger line-editor-btn-full mt-2"
                onClick={() => onDeleteOriginLeg(activeOriginLeg.id)}
              >
                <Trash2 className="h-4 w-4" />
                Supprimer ce point de départ
              </button>
            </div>
          )}

          {activeBranch && (
            <div className="line-editor-card">
              <h4 className="line-editor-card-title">
                <GitBranchPlus className="h-4 w-4" />
                Branche active
              </h4>
              <div className="line-editor-form-grid">
                <Field label="Libellé de la branche">
                  <input
                    className="line-editor-input"
                    value={activeBranch.label}
                    onChange={(e) =>
                      onUpdateBranchMeta(activeBranch.id, { label: e.target.value })
                    }
                    placeholder="Ex. Vers École Centrale"
                  />
                </Field>
                <Field label="Terminus de la branche">
                  <input
                    className="line-editor-input"
                    value={activeBranch.terminusName}
                    onChange={(e) =>
                      onUpdateBranchMeta(activeBranch.id, {
                        terminusName: e.target.value,
                      })
                    }
                    placeholder="Nom du terminus"
                  />
                </Field>
              </div>
              <button
                type="button"
                className="line-editor-btn-danger line-editor-btn-full mt-2"
                onClick={() => onDeleteBranch(activeBranch.id)}
              >
                <Trash2 className="h-4 w-4" />
                Supprimer la branche
              </button>
            </div>
          )}

          {isHub && (
            <div className="line-editor-card">
              <h4 className="line-editor-card-title">
                <Signpost className="h-4 w-4" />
                Points de départ
              </h4>
              <p className="line-editor-segment-trace-hint">
                Variantes de départ indépendantes qui convergent sur cette
                correspondance (ex. plusieurs terminus de départ).
              </p>
              {hubOriginLegs.length > 0 && (
                <ul className="line-editor-branch-list">
                  {hubOriginLegs.map((leg) => (
                    <li key={leg.id}>
                      <button
                        type="button"
                        className={`line-editor-branch-list-item${activeOriginLegId === leg.id ? " active" : ""}`}
                        onClick={() => {
                          onSelectOriginLeg(leg.id);
                          onSelectBranch(null);
                        }}
                      >
                        {leg.label || "Départ"}
                      </button>
                    </li>
                  ))}
                </ul>
              )}
              <button
                type="button"
                className="line-editor-action-btn line-editor-btn-full"
                onClick={() => onAddOriginLeg(selectedPoint.id)}
              >
                <Signpost className="h-4 w-4" />
                Ajouter un point de départ
              </button>
            </div>
          )}

          {isHub && (
            <div className="line-editor-card">
              <h4 className="line-editor-card-title">
                <GitBranchPlus className="h-4 w-4" />
                Branches depuis cette correspondance
              </h4>
              <p className="line-editor-segment-trace-hint">
                Ajoutez une variante rattachée à un autre terminus (service
                partiel ou débranchement).
              </p>
              {hubBranches.length > 0 && (
                <ul className="line-editor-branch-list">
                  {hubBranches.map((branch) => (
                    <li key={branch.id}>
                      <button
                        type="button"
                        className={`line-editor-branch-list-item${activeBranchId === branch.id ? " active" : ""}`}
                        onClick={() => onSelectBranch(branch.id)}
                      >
                        {branch.label || branch.terminusName || "Branche"}
                      </button>
                    </li>
                  ))}
                </ul>
              )}
              <button
                type="button"
                className="line-editor-action-btn line-editor-btn-full"
                onClick={() => onAddBranch(selectedPoint.id)}
              >
                <GitBranchPlus className="h-4 w-4" />
                Ajouter une branche vers un terminus
              </button>
            </div>
          )}

          <div className="line-editor-card line-editor-quick-actions">
            <h4 className="line-editor-card-title">Actions rapides</h4>
            <div className="line-editor-action-list">
              {selectedPoint.type === "passage" && (
                <button
                  type="button"
                  className="line-editor-action-btn"
                  onClick={onTransformToStop}
                >
                  <GitBranchPlus className="h-4 w-4" />
                  Transformer en arrêt
                </button>
              )}
              <button
                type="button"
                className="line-editor-action-btn"
                onClick={() => onSetTerminus("start")}
              >
                <Flag className="h-4 w-4" />
                Ajouter comme terminus départ
              </button>
              {selectedPoint.type === "terminus_start" &&
                isOnTrunk &&
                trunkHubs.length > 0 && (
                  <>
                    {trunkHubs.map((hub) => (
                      <button
                        key={hub.id}
                        type="button"
                        className="line-editor-action-btn"
                        onClick={() =>
                          onAttachAsOriginLeg(selectedPoint.id, hub.id)
                        }
                      >
                        <Signpost className="h-4 w-4" />
                        Rattacher vers {hub.stop?.name || "hub"}
                      </button>
                    ))}
                  </>
                )}
              <button
                type="button"
                className="line-editor-action-btn"
                onClick={() => onSetTerminus("end")}
              >
                <ArrowRightLeft className="h-4 w-4" />
                Ajouter comme terminus arrivée
              </button>
            </div>
          </div>

          <div className="line-editor-sidebar-footer">
            <button
              type="button"
              className="line-editor-btn-danger line-editor-btn-full"
              onClick={onDelete}
            >
              <Trash2 className="h-4 w-4" />
              Supprimer le point
            </button>
          </div>
        </>
      )}
    </aside>
  );
}

function Field({
  label,
  children,
  className,
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <label className={`line-editor-field${className ? ` ${className}` : ""}`}>
      <span className="line-editor-field-label">{label}</span>
      {children}
    </label>
  );
}
