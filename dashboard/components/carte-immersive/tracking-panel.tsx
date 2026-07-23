"use client";

import { useState } from "react";
import { TravelerCommentCard } from "@/components/dashboard/traveler-comment-card";
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
  mode: "bus" | "tram" | "navibus";
  destination: string;
  nextStop: string;
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

const INFO_ITEMS: Array<{
  key: keyof Pick<
    TrackingPanelData,
    "destination" | "nextStop" | "eta" | "distance" | "status"
  >;
  label: string;
}> = [
  { key: "destination", label: "Destination" },
  { key: "nextStop", label: "Prochain arrêt" },
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

  return (
    <section
      className="immersive-map-tracking-panel immersive-map-panel-anim"
      aria-label={`${data.hasRealtime ? "Suivi en temps réel" : "Suivi théorique"} de ${data.title}`}
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
          <div className="immersive-map-tracking-identity">
            <span className="immersive-map-tracking-vehicle">{data.emoji}</span>
            <div>
              <div className="immersive-map-tracking-kicker">
                <span className="immersive-map-tracking-live-dot" />
                {data.hasRealtime ? "Suivi en temps réel" : "Suivi théorique"}
              </div>
              <h2>{data.title}</h2>
            </div>
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
          <button
            type="button"
            onClick={onBoard}
            disabled={!data.canBoard}
            title={data.canBoard ? `Monter dans ${vehicleLabel}` : data.proximityLabel}
            className="immersive-map-tracking-board"
          >
            <span>↗</span>
            {data.canBoard ? `Monter dans ${vehicleLabel}` : data.proximityLabel}
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
