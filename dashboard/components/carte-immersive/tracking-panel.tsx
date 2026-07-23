"use client";

import { useState, type CSSProperties } from "react";
import { TravelerCommentCard } from "@/components/dashboard/traveler-comment-card";
import { lineBadgeTextColor } from "@/lib/carte-immersive/stop-schedule";
import type { TravelerComment } from "@/lib/traveler-comments";

export type TrackingStopPlanItem = {
  id: string;
  occurrenceKey: string;
  name: string;
  passageAt: number | null;
  state: "passed" | "next" | "upcoming";
};

export type TrackingPanelData = {
  emoji: string;
  title: string;
  /** Numéro de ligne seul, affiché dans la girouette (« 1 », « C6 »…). */
  lineLabel: string;
  /** Couleur officielle de la ligne ; à défaut la girouette reste ambre. */
  lineColor: string | null;
  /** Information de service affichée sous la destination. */
  serviceMessage: string | null;
  mode: "bus" | "tram" | "navibus";
  destination: string;
  nextStop: string;
  /** Véhicule à quai : la girouette affiche alors l'arrêt courant. */
  atStop: boolean;
  /** Arrêt d'où le suivi a été lancé : sert de repère « arrive dans N arrêts ». */
  boardingStopName: string | null;
  eta: string;
  distance: string;
  distanceTraveledM: number | null;
  routeDistanceM: number | null;
  status: string;
  dataStatus: string;
  hasRealtime: boolean;
  proximityLabel: string;
  notificationEnabled: boolean;
  stopsVisible: boolean;
  canBoard: boolean;
  approachAlert: string | null;
  linePlan: TrackingStopPlanItem[];
  comments: TravelerComment[];
};

type TrackingPanelProps = {
  data: TrackingPanelData;
  onStop: () => void;
  onRecenter: () => void;
  onToggleStops: () => void;
  onToggleNotification: () => void;
  onBoard: () => void;
};

// Destination et prochain arrêt sont désormais portés par la girouette.
const INFO_ITEMS: Array<{
  key: keyof Pick<TrackingPanelData, "eta" | "distance" | "status">;
  label: string;
}> = [
  { key: "eta", label: "Arrivée estimée" },
  { key: "distance", label: "Distance arrêt" },
  { key: "status", label: "Statut" },
];

const KILOMETER_FORMATTER = new Intl.NumberFormat("fr-FR", {
  minimumFractionDigits: 1,
  maximumFractionDigits: 1,
});

const PASSAGE_TIME_FORMATTER = new Intl.DateTimeFormat("fr-FR", {
  timeZone: "Europe/Paris",
  hour: "2-digit",
  minute: "2-digit",
  hourCycle: "h23",
});

function formatKilometers(distanceM: number | null) {
  if (distanceM == null) return "Indisponible";
  return `${KILOMETER_FORMATTER.format(Math.max(0, distanceM) / 1_000)} km`;
}

/**
 * Une couleur de ligne sombre (rouge, bleu foncé…) resterait illisible en
 * « diodes » sur le fond noir de la girouette : on l'éclaircit juste ce qu'il
 * faut, la pastille du numéro gardant elle la teinte exacte de la ligne.
 */
function ledColor(lineColor: string | null): string | null {
  const hex = /^#?([0-9a-f]{6})$/i.exec(lineColor?.trim() ?? "")?.[1];
  if (!hex) return null;
  const value = parseInt(hex, 16);
  const rgb = [(value >> 16) & 255, (value >> 8) & 255, value & 255];
  const luminance =
    (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255;
  const lift = Math.min(0.7, Math.max(0, (0.62 - luminance) / 0.62));
  const lifted = rgb.map((channel) =>
    Math.round(channel + (255 - channel) * lift),
  );
  return `#${lifted.map((channel) => channel.toString(16).padStart(2, "0")).join("")}`;
}

/** Variables de teinte de la ligne, ou rien pour conserver l'ambre par défaut. */
function girouetteStyle(data: TrackingPanelData): CSSProperties | undefined {
  const led = ledColor(data.lineColor);
  if (!led || !data.lineColor) return undefined;
  return {
    "--girouette-led": led,
    "--girouette-badge": data.lineColor,
    "--girouette-badge-text": lineBadgeTextColor(data.lineColor),
  } as CSSProperties;
}

/** Afficheur de façade : numéro de ligne + destination, aux couleurs de la ligne. */
function Girouette({ data }: { data: TrackingPanelData }) {
  return (
    <div
      className="immersive-map-girouette"
      role="img"
      aria-label={`${data.title} · direction ${data.destination}${
        data.serviceMessage ? ` · ${data.serviceMessage}` : ""
      }`}
      style={girouetteStyle(data)}
    >
      <span className="immersive-map-girouette-line">{data.lineLabel}</span>
      <span className="immersive-map-girouette-copy">
        <span className="immersive-map-girouette-dest">{data.destination}</span>
        {data.serviceMessage && (
          <span className="immersive-map-girouette-service">
            {data.serviceMessage}
          </span>
        )}
      </span>
    </div>
  );
}

/**
 * Sur mobile, la girouette prend la place du header pendant le suivi. Elle est
 * rendue hors du panneau de suivi : celui-ci est animé en `transform`, ce qui
 * y piégerait tout positionnement fixe.
 */
export function TrackingGirouetteBar({ data }: { data: TrackingPanelData }) {
  return (
    <div className="immersive-map-girouette-bar">
      <Girouette data={data} />
    </div>
  );
}

export function TrackingPanel({
  data,
  onStop,
  onRecenter,
  onToggleStops,
  onToggleNotification,
  onBoard,
}: TrackingPanelProps) {
  const [mobilePanel, setMobilePanel] = useState<"line" | "comments" | null>(
    null,
  );
  const vehicleLabel =
    data.mode === "tram" ? "ce tram" : data.mode === "navibus" ? "ce navibus" : "ce bus";
  const distanceRemainingM =
    data.routeDistanceM == null || data.distanceTraveledM == null
      ? null
      : Math.max(0, data.routeDistanceM - data.distanceTraveledM);
  const mileageProgress =
    data.routeDistanceM && data.distanceTraveledM != null
      ? Math.min(100, Math.max(0, (data.distanceTraveledM / data.routeDistanceM) * 100))
      : 0;

  // Le plan de ligne marque « next » l'arrêt vers lequel roule le véhicule —
  // ou celui où il stationne quand il est à quai (cas du terminus au départ).
  const nextIndex = data.linePlan.findIndex((stop) => stop.state === "next");
  const markedStop = nextIndex >= 0 ? data.linePlan[nextIndex] : null;
  const standingAtStop = data.atStop && markedStop != null;
  const currentStopName = standingAtStop ? markedStop.name : null;
  const atTerminus =
    standingAtStop &&
    (nextIndex === 0 || nextIndex === data.linePlan.length - 1);
  const upcomingStopName = standingAtStop
    ? (data.linePlan.slice(nextIndex + 1).find((stop) => stop.state !== "passed")?.name ??
      null)
    : (markedStop?.name ?? data.nextStop ?? null);

  // Repère d'arrivée : l'arrêt d'où part le voyageur, à défaut le terminus.
  const boardingIndex = data.boardingStopName
    ? data.linePlan.findIndex((stop) => stop.name === data.boardingStopName)
    : -1;
  const targetIndex = boardingIndex >= 0 ? boardingIndex : data.linePlan.length - 1;
  const targetStop = targetIndex >= 0 ? data.linePlan[targetIndex] : null;
  const stopsAway =
    targetStop && nextIndex >= 0 ? targetIndex - nextIndex : null;
  const arrivalStatus =
    stopsAway == null
      ? "Position en cours de calcul"
      : stopsAway < 0
        ? "Arrêt déjà desservi"
        : stopsAway === 0
          ? standingAtStop
            ? `${vehicleLabel.replace("ce ", "Le ")} est à quai`
            : "Arrive à cet arrêt"
          : stopsAway === 1
            ? "Dans 1 arrêt"
            : `Dans ${stopsAway} arrêts`;

  return (
    <section
      className="immersive-map-tracking-panel immersive-map-panel-anim"
      aria-label={`${data.hasRealtime ? "Suivi en temps réel" : "Suivi théorique"} de ${data.title}`}
      style={girouetteStyle(data)}
    >
      {data.approachAlert && (
        <div className="immersive-map-tracking-alert" role="alert">
          <span className="immersive-map-tracking-alert-dot" />
          {data.approachAlert}
        </div>
      )}

      {data.linePlan.length > 0 && (
        <aside
          id="immersive-tracking-line-panel"
          className={`immersive-map-tracking-line-card immersive-map-panel${
            mobilePanel === "line" ? " is-mobile-open" : ""
          }`}
          aria-label="Plan de ligne du véhicule suivi"
        >
          <div className="immersive-map-tracking-line-head">
            <div>
              <span>Plan de ligne</span>
              <strong>{data.nextStop}</strong>
            </div>
            <div className="immersive-map-tracking-line-head-actions">
              <div className="immersive-map-tracking-line-legend">
                <span className="is-passed">Passé</span>
                <span className="is-upcoming">À venir</span>
              </div>
              <button
                type="button"
                className="immersive-map-tracking-mobile-close"
                aria-label="Fermer le plan de ligne"
                onClick={() => setMobilePanel(null)}
              >
                ×
              </button>
            </div>
          </div>

          <div className="immersive-map-tracking-line-scroll">
            <ol className="immersive-map-tracking-line-plan">
              {data.linePlan.map((stop) => (
                <li
                  key={stop.occurrenceKey}
                  className={`immersive-map-tracking-stop immersive-map-tracking-stop--${stop.state}`}
                  aria-current={stop.state === "next" ? "step" : undefined}
                >
                  <span className="immersive-map-tracking-stop-node">
                    {stop.state === "next" ? data.emoji : ""}
                  </span>
                  <span className="immersive-map-tracking-stop-name">
                    {stop.name}
                  </span>
                  {stop.passageAt != null && (
                    <time
                      className="immersive-map-tracking-stop-time"
                      dateTime={new Date(stop.passageAt).toISOString()}
                      title="Horaire théorique de passage"
                    >
                      {PASSAGE_TIME_FORMATTER.format(stop.passageAt)}
                    </time>
                  )}
                </li>
              ))}
            </ol>
          </div>
        </aside>
      )}

      <div className="immersive-map-tracking-main-card immersive-map-panel">
        <div className="immersive-map-tracking-head">
          <div className="immersive-map-tracking-kicker">
            <span className="immersive-map-tracking-live-dot" />
            {data.hasRealtime ? "Suivi en temps réel" : "Suivi théorique"}
          </div>
          <div className="immersive-map-tracking-data-state">
            {data.dataStatus}
          </div>
          <button
            type="button"
            onClick={onStop}
            className="immersive-map-tracking-exit"
          >
            Quitter le suivi
          </button>
        </div>

        {/* Girouette : la façade du véhicule, numéro de ligne + destination.
            Sur mobile elle est reprise en haut d'écran, à la place du header. */}
        <Girouette data={data} />

        {(currentStopName || upcomingStopName) && (
          <div className="immersive-map-girouette-stops">
            {currentStopName && (
              <div className="immersive-map-girouette-stop immersive-map-girouette-stop--current">
                <span>{atTerminus ? "Terminus · à quai" : "Arrêt actuel"}</span>
                <strong>{currentStopName}</strong>
              </div>
            )}
            {upcomingStopName && (
              <div className="immersive-map-girouette-stop">
                <span>Prochain arrêt</span>
                <strong>{upcomingStopName}</strong>
              </div>
            )}
          </div>
        )}

        {targetStop && (
          <div
            className={`immersive-map-tracking-arrival${
              data.canBoard ? " immersive-map-tracking-arrival--boardable" : ""
            }`}
            title={data.proximityLabel}
            aria-live="polite"
          >
            <div className="immersive-map-tracking-arrival-copy">
              <span>
                {boardingIndex >= 0 ? "Arrivée à" : "Terminus"} {targetStop.name}
              </span>
              <strong>
                {arrivalStatus}
                {targetStop.passageAt != null &&
                  ` · ${PASSAGE_TIME_FORMATTER.format(targetStop.passageAt)}`}
              </strong>
            </div>
            <div
              className="immersive-map-tracking-arrival-count"
              aria-hidden="true"
            >
              <strong>{stopsAway != null && stopsAway > 0 ? stopsAway : "—"}</strong>
              <span>{stopsAway === 1 ? "arrêt" : "arrêts"}</span>
            </div>
            {data.canBoard && (
              <button
                type="button"
                onClick={onBoard}
                className="immersive-map-tracking-arrival-board"
              >
                Monter dans {vehicleLabel}
              </button>
            )}
          </div>
        )}

        <div className="immersive-map-tracking-info">
          {INFO_ITEMS.map((item) => (
            <div key={item.key}>
              <span>{item.label}</span>
              <strong>{data[item.key]}</strong>
            </div>
          ))}
        </div>

        <div
          className="immersive-map-tracking-mileage"
          aria-label="Kilométrage de la course"
        >
          <div className="immersive-map-tracking-mileage-icon" aria-hidden="true">
            ↝
          </div>
          <div className="immersive-map-tracking-mileage-copy">
            <span>Kilométrage de la course</span>
            <strong>
              {data.distanceTraveledM == null
                ? "Position indisponible"
                : `${formatKilometers(data.distanceTraveledM)} parcourus`}
            </strong>
          </div>
          <div className="immersive-map-tracking-mileage-progress-copy">
            <strong>{distanceRemainingM == null ? "—" : formatKilometers(distanceRemainingM)}</strong>
            <span>
              {distanceRemainingM == null ? "Distance restante" : "restants"} · trajet de{" "}
              {formatKilometers(data.routeDistanceM)}
            </span>
          </div>
          <div
            className="immersive-map-tracking-mileage-bar"
            role="progressbar"
            aria-label="Progression kilométrique de la course"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={
              data.distanceTraveledM == null ? undefined : Math.round(mileageProgress)
            }
          >
            <span style={{ width: `${mileageProgress}%` }} />
          </div>
        </div>

        <div className="immersive-map-tracking-actions">
          <button type="button" onClick={onRecenter}>
            <span>◎</span>
            Recentrer
          </button>
          <button
            type="button"
            onClick={onToggleStops}
            aria-pressed={data.stopsVisible}
            className={data.stopsVisible ? "is-active" : ""}
          >
            <span>●</span>
            {data.stopsVisible ? "Masquer les arrêts" : "Voir les arrêts"}
          </button>
          <button
            type="button"
            onClick={onToggleNotification}
            aria-pressed={data.notificationEnabled}
            className={data.notificationEnabled ? "is-active" : ""}
          >
            <span>{data.notificationEnabled ? "🔔" : "♢"}</span>
            {data.notificationEnabled ? "Alerte activée" : "Notifier à l’approche"}
          </button>
        </div>
      </div>

      <div
        className="immersive-map-tracking-mobile-tabs"
        aria-label="Informations complémentaires du suivi"
      >
        {data.linePlan.length > 0 && (
          <button
            type="button"
            className={mobilePanel === "line" ? "is-active" : ""}
            aria-controls="immersive-tracking-line-panel"
            aria-expanded={mobilePanel === "line"}
            onClick={() =>
              setMobilePanel((panel) => (panel === "line" ? null : "line"))
            }
          >
            <span aria-hidden="true">⌖</span>
            {mobilePanel === "line" ? "Fermer le plan" : "Plan de ligne"}
            <strong>{data.linePlan.length}</strong>
          </button>
        )}
        <button
          type="button"
          className={mobilePanel === "comments" ? "is-active" : ""}
          aria-controls="immersive-tracking-comments-panel"
          aria-expanded={mobilePanel === "comments"}
          onClick={() =>
            setMobilePanel((panel) =>
              panel === "comments" ? null : "comments",
            )
          }
        >
          <span aria-hidden="true">◌</span>
          {mobilePanel === "comments" ? "Fermer les commentaires" : "Commentaires"}
          <strong>{data.comments.length}</strong>
        </button>
      </div>

      <aside
        id="immersive-tracking-comments-panel"
        className={`immersive-map-tracking-comments immersive-map-panel${
          mobilePanel === "comments" ? " is-mobile-open" : ""
        }`}
        aria-label="Commentaires voyageurs du véhicule suivi"
      >
        <div className="immersive-map-tracking-comments-head">
          <div>
            <span>Commentaires usagers</span>
            <strong>{data.comments.length} actif(s)</strong>
          </div>
          <div className="immersive-map-tracking-comments-head-actions">
            <span>24 h</span>
            <button
              type="button"
              className="immersive-map-tracking-mobile-close"
              aria-label="Fermer les commentaires"
              onClick={() => setMobilePanel(null)}
            >
              ×
            </button>
          </div>
        </div>
        {data.comments.length === 0 ? (
          <p className="immersive-map-tracking-comments-empty">
            Aucun commentaire récent sur ce service.
          </p>
        ) : (
          <div className="immersive-map-tracking-comments-list">
            {data.comments.map((comment) => (
              <TravelerCommentCard key={comment.id} comment={comment} />
            ))}
          </div>
        )}
      </aside>
    </section>
  );
}
