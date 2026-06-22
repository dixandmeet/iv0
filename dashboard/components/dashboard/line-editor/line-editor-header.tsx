"use client";

import {
  ArrowLeft,
  BookOpen,
  Bus,
  Check,
  Clock,
  MapPin,
  Redo2,
  Route,
  Send,
  Ship,
  TrainFront,
  Undo2,
} from "lucide-react";
import {
  LINE_STATUS_COLORS,
  LINE_STATUS_LABELS,
  LINE_VOICE_LABELS,
  TRANSPORT_MODE_LABELS,
  type EditorLineStatus,
  type EditorTransportMode,
  type LineEditorState,
  type LineVoice,
} from "@/lib/line-editor-types";
import { formatDistance } from "@/lib/line-editor-utils";
import { collectTerminiLabels, getVoiceBranches } from "@/lib/line-editor-branches";

interface LineEditorHeaderProps {
  state: LineEditorState;
  stats: { distanceKm: number; stopCount: number; travelMinutes: number };
  termini: { starts: string[]; ends: string[] };
  canUndo: boolean;
  canRedo: boolean;
  lastSavedAt: number | null;
  onUndo: () => void;
  onRedo: () => void;
  onPublish: () => void;
  onBack: () => void;
  onVoiceChange: (voice: LineVoice) => void;
  onOpenGuide?: () => void;
  onMetaChange: (
    patch: Partial<
      Pick<
        LineEditorState,
        | "name"
        | "shortName"
        | "color"
        | "transportMode"
        | "directionAller"
        | "directionRetour"
        | "status"
      >
    >,
  ) => void;
}

const TRANSPORT_ICONS: Record<EditorTransportMode, typeof Bus> = {
  bus: Bus,
  tram: TrainFront,
  boat: Ship,
  shuttle: Bus,
};

export function LineEditorHeader({
  state,
  stats,
  termini,
  canUndo,
  canRedo,
  lastSavedAt,
  onUndo,
  onRedo,
  onPublish,
  onBack,
  onVoiceChange,
  onOpenGuide,
  onMetaChange,
}: LineEditorHeaderProps) {
  const TransportIcon = TRANSPORT_ICONS[state.transportMode];

  return (
    <header className="line-editor-header">
      <div className="line-editor-header-left">
        <button type="button" className="line-editor-back-btn" onClick={onBack}>
          <ArrowLeft className="h-4 w-4" />
          Retour
        </button>

        <div className="line-editor-line-badge" style={{ background: state.color }}>
          <input
            className="line-editor-shortname-input"
            value={state.shortName}
            onChange={(e) => onMetaChange({ shortName: e.target.value })}
            aria-label="Numéro de ligne"
          />
        </div>

        <div className="line-editor-header-fields">
          <input
            className="line-editor-name-input"
            value={state.name}
            onChange={(e) => onMetaChange({ name: e.target.value })}
            placeholder="Nom de la ligne"
          />
          <div className="line-editor-header-meta">
            <label className="line-editor-color-field">
              <span className="sr-only">Couleur</span>
              <input
                type="color"
                value={state.color}
                onChange={(e) => onMetaChange({ color: e.target.value })}
              />
            </label>
            <select
              className="line-editor-select"
              value={state.transportMode}
              onChange={(e) =>
                onMetaChange({
                  transportMode: e.target.value as EditorTransportMode,
                })
              }
            >
              {(Object.keys(TRANSPORT_MODE_LABELS) as EditorTransportMode[]).map(
                (mode) => (
                  <option key={mode} value={mode}>
                    {TRANSPORT_MODE_LABELS[mode]}
                  </option>
                ),
              )}
            </select>
            <select
              className="line-editor-select"
              value={state.status}
              onChange={(e) =>
                onMetaChange({ status: e.target.value as EditorLineStatus })
              }
            >
              {(Object.keys(LINE_STATUS_LABELS) as EditorLineStatus[]).map(
                (status) => (
                  <option key={status} value={status}>
                    {LINE_STATUS_LABELS[status]}
                  </option>
                ),
              )}
            </select>
            <span
              className="line-editor-status-pill"
              style={{
                color: LINE_STATUS_COLORS[state.status],
                borderColor: `${LINE_STATUS_COLORS[state.status]}50`,
                background: `${LINE_STATUS_COLORS[state.status]}18`,
              }}
            >
              {LINE_STATUS_LABELS[state.status]}
            </span>
          </div>
        </div>
      </div>

      <div className="line-editor-header-directions">
        <div className="line-editor-voice-tabs" role="tablist" aria-label="Voix de tracé">
          {(Object.keys(LINE_VOICE_LABELS) as LineVoice[]).map((voice) => (
            <button
              key={voice}
              type="button"
              role="tab"
              aria-selected={state.activeVoice === voice}
              className={`line-editor-voice-tab${state.activeVoice === voice ? " active" : ""}`}
              onClick={() => onVoiceChange(voice)}
            >
              {LINE_VOICE_LABELS[voice]}
            </button>
          ))}
        </div>
        <div className="line-editor-direction-fields">
          <div className="line-editor-direction-field">
            <Route className="h-3.5 w-3.5 text-[#64748B]" />
            <input
              placeholder="Direction aller"
              value={state.directionAller}
              onChange={(e) => onMetaChange({ directionAller: e.target.value })}
            />
          </div>
          <div className="line-editor-direction-field">
            <Route className="h-3.5 w-3.5 text-[#64748B] rotate-180" />
            <input
              placeholder="Direction retour"
              value={state.directionRetour}
              onChange={(e) => onMetaChange({ directionRetour: e.target.value })}
            />
          </div>
          {(termini.starts.length > 0 || termini.ends.length > 0) && (
            <p className="line-editor-termini-summary">
              {termini.starts.length > 0 && (
                <span>Départs : {termini.starts.join(" · ")}</span>
              )}
              {termini.ends.length > 0 && (
                <span>Arrivées : {termini.ends.join(" · ")}</span>
              )}
            </p>
          )}
        </div>
      </div>

      <div className="line-editor-header-stats">
        <Stat icon={TransportIcon} label="Mode" value={TRANSPORT_MODE_LABELS[state.transportMode]} />
        <Stat icon={MapPin} label="Arrêts" value={String(stats.stopCount)} />
        <Stat icon={Route} label="Distance" value={formatDistance(stats.distanceKm)} />
        <Stat icon={Clock} label="Durée est." value={`${stats.travelMinutes} min`} />
      </div>

      <div className="line-editor-header-actions">
        {onOpenGuide && (
          <button
            type="button"
            className="line-editor-guide-btn"
            onClick={onOpenGuide}
            title="Consulter la documentation"
          >
            <BookOpen className="h-4 w-4" />
            Guide
          </button>
        )}
        <button
          type="button"
          className="line-editor-icon-btn"
          onClick={onUndo}
          disabled={!canUndo}
          title="Annuler"
        >
          <Undo2 className="h-4 w-4" />
        </button>
        <button
          type="button"
          className="line-editor-icon-btn"
          onClick={onRedo}
          disabled={!canRedo}
          title="Rétablir"
        >
          <Redo2 className="h-4 w-4" />
        </button>
        {lastSavedAt != null && (
          <span className="line-editor-autosave-pill">
            <Check className="h-3.5 w-3.5" />
            Enregistré
          </span>
        )}
        <button type="button" className="line-editor-btn-primary" onClick={onPublish}>
          <Send className="h-4 w-4" />
          Publier la ligne
        </button>
      </div>
    </header>
  );
}

function Stat({
  icon: Icon,
  label,
  value,
}: {
  icon: typeof Bus;
  label: string;
  value: string;
}) {
  return (
    <div className="line-editor-stat">
      <Icon className="h-3.5 w-3.5 text-[#3B82F6]" strokeWidth={1.75} />
      <div>
        <span className="line-editor-stat-label">{label}</span>
        <span className="line-editor-stat-value">{value}</span>
      </div>
    </div>
  );
}
