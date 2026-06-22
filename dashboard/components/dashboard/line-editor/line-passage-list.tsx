"use client";

import { useEffect, useRef } from "react";
import { CircleDot, Trash2, Waypoints } from "lucide-react";
import type { RoutePoint } from "@/lib/line-editor-types";
import { pointRouteLabel } from "@/lib/line-editor-utils";

interface LinePassageListProps {
  passages: RoutePoint[];
  allPoints: RoutePoint[];
  selectedPointId: string | null;
  onSelect: (pointId: string) => void;
  onDelete: (pointId: string) => void;
}

function passageContext(allPoints: RoutePoint[], passageId: string): string {
  const routeIndex = allPoints.findIndex((p) => p.id === passageId);
  if (routeIndex < 0) return "";

  const prev = routeIndex > 0 ? allPoints[routeIndex - 1] : null;
  const next =
    routeIndex < allPoints.length - 1 ? allPoints[routeIndex + 1] : null;

  const from = prev ? pointRouteLabel(prev, allPoints) : "Début";
  const to = next ? pointRouteLabel(next, allPoints) : "Fin";
  return `${from} → ${to}`;
}

export function LinePassageList({
  passages,
  allPoints,
  selectedPointId,
  onSelect,
  onDelete,
}: LinePassageListProps) {
  const selectedItemRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!selectedPointId) return;
    const isPassageSelected = passages.some((passage) => passage.id === selectedPointId);
    if (!isPassageSelected) return;

    selectedItemRef.current?.scrollIntoView({
      block: "nearest",
      behavior: "smooth",
    });
  }, [selectedPointId, passages]);

  return (
    <section className="line-editor-passage-list">
      <div className="line-editor-passage-list-header">
        <h4 className="line-editor-card-title">
          <Waypoints className="h-4 w-4" />
          Points de passage
        </h4>
        <span className="line-editor-passage-list-count">
          {passages.length}
        </span>
      </div>

      {passages.length === 0 ? (
        <p className="line-editor-passage-list-empty">
          Aucun point de passage — cliquez sur le tracé ou utilisez les boutons
          + sur la carte.
        </p>
      ) : (
        <ul className="line-editor-passage-list-items">
          {passages.map((passage, index) => {
            const isSelected = passage.id === selectedPointId;
            const context = passageContext(allPoints, passage.id);

            return (
              <li key={passage.id} className="line-editor-passage-list-row">
                <button
                  ref={isSelected ? selectedItemRef : undefined}
                  type="button"
                  className={`line-editor-passage-item${isSelected ? " selected" : ""}`}
                  onClick={() => onSelect(passage.id)}
                  aria-current={isSelected ? "true" : undefined}
                >
                  <span className="line-editor-passage-item-index">
                    {index + 1}
                  </span>
                  <span className="line-editor-passage-item-body">
                    <span className="line-editor-passage-item-coords">
                      {passage.coordinates[1].toFixed(5)}°N ·{" "}
                      {passage.coordinates[0].toFixed(5)}°E
                    </span>
                    {context && (
                      <span className="line-editor-passage-item-context">
                        <CircleDot className="h-3 w-3 shrink-0" />
                        {context}
                      </span>
                    )}
                  </span>
                </button>
                <button
                  type="button"
                  className="line-editor-passage-item-delete"
                  onClick={() => onDelete(passage.id)}
                  aria-label={`Supprimer le point de passage ${index + 1}`}
                  title="Supprimer"
                >
                  <Trash2 className="h-3.5 w-3.5" />
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
