"use client";

import { TravelerCommentCard } from "@/components/dashboard/traveler-comment-card";
import type { TravelerComment } from "@/lib/traveler-comments";

export type TrackingStopPlanItem = {
  id: string;
  name: string;
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
  status: string;
  dataStatus: string;
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

export function TrackingPanel({
  data,
  onStop,
  onRecenter,
  onToggleStops,
  onToggleNotification,
  onBoard,
}: TrackingPanelProps) {
  const vehicleLabel =
    data.mode === "tram" ? "ce tram" : data.mode === "navibus" ? "ce navibus" : "ce bus";

  return (
    <section
      className="immersive-map-tracking-panel immersive-map-panel-anim"
      aria-label={`Suivi GPS de ${data.title}`}
    >
      {data.approachAlert && (
        <div className="immersive-map-tracking-alert" role="alert">
          <span className="immersive-map-tracking-alert-dot" />
          {data.approachAlert}
        </div>
      )}

      {data.linePlan.length > 0 && (
        <aside
          className="immersive-map-tracking-line-card immersive-map-panel"
          aria-label="Plan de ligne du véhicule suivi"
        >
          <div className="immersive-map-tracking-line-head">
            <div>
              <span>Plan de ligne</span>
              <strong>{data.nextStop}</strong>
            </div>
            <div className="immersive-map-tracking-line-legend">
              <span className="is-passed">Passé</span>
              <span className="is-upcoming">À venir</span>
            </div>
          </div>

          <div className="immersive-map-tracking-line-scroll">
            <ol className="immersive-map-tracking-line-plan">
              {data.linePlan.map((stop) => (
                <li
                  key={stop.id}
                  className={`immersive-map-tracking-stop immersive-map-tracking-stop--${stop.state}`}
                  aria-current={stop.state === "next" ? "step" : undefined}
                >
                  <span className="immersive-map-tracking-stop-node">
                    {stop.state === "next" ? data.emoji : ""}
                  </span>
                  <span className="immersive-map-tracking-stop-name">
                    {stop.name}
                  </span>
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
                Mode suivi GPS
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

      <aside
        className="immersive-map-tracking-comments immersive-map-panel"
        aria-label="Commentaires voyageurs du véhicule suivi"
      >
        <div className="immersive-map-tracking-comments-head">
          <div>
            <span>Commentaires usagers</span>
            <strong>{data.comments.length} actif(s)</strong>
          </div>
          <span>24 h</span>
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
