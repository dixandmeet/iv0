"use client";

import { useCallback, useMemo, useState } from "react";
import { MessageSquare } from "lucide-react";
import { TravelerCommentCard } from "@/components/dashboard/traveler-comment-card";
import { EmptyState } from "@/components/ui/empty-state";
import type { TravelerComment } from "@/lib/traveler-comments";

interface VehicleTravelerCommentsProps {
  comments: TravelerComment[];
  loading?: boolean;
}

export function VehicleTravelerComments({
  comments,
  loading,
}: VehicleTravelerCommentsProps) {
  const [deletedIds, setDeletedIds] = useState<Set<string>>(new Set());

  const visibleComments = useMemo(
    () => comments.filter((comment) => !deletedIds.has(comment.id)),
    [comments, deletedIds],
  );

  const handleDelete = useCallback((commentId: string) => {
    const comment = comments.find((entry) => entry.id === commentId);
    if (!comment) return;
    if (!confirm("Supprimer ce commentaire voyageur ?")) return;
    setDeletedIds((prev) => new Set(prev).add(commentId));
  }, [comments]);

  return (
    <section className="vehicle-traveler-comments">
      <div className="vehicle-traveler-comments-header">
        <h2 className="text-sm font-semibold text-white">Commentaires voyageurs</h2>
        <span className="text-xs text-[#64748B]">{visibleComments.length} actif(s) · 24 h</span>
      </div>
      <p className="mb-3 text-xs text-[#94A3B8]">
        Retours et signalements des usagers sur ce véhicule et sa ligne.
      </p>

      {loading ? (
        <p className="text-sm text-[#64748B]">Chargement…</p>
      ) : visibleComments.length === 0 ? (
        <EmptyState
          icon={MessageSquare}
          title="Aucun commentaire récent"
          description="Les retours voyageurs apparaîtront ici pendant 24 h."
        />
      ) : (
        <div className="vehicle-traveler-comments-list">
          {visibleComments.map((comment) => (
            <TravelerCommentCard
              key={comment.id}
              comment={comment}
              onDelete={handleDelete}
            />
          ))}
        </div>
      )}
    </section>
  );
}
