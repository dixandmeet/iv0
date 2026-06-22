"use client";

import { EyeOff, Flag, ShieldCheck, ThumbsUp, Trash2 } from "lucide-react";
import {
  TRAVELER_COMMENT_CATEGORY_COLORS,
  TRAVELER_COMMENT_CATEGORY_LABELS,
  type TravelerComment,
  isTravelerCommentHidden,
  travelerCommentElapsedLabel,
  travelerCommentInitials,
} from "@/lib/traveler-comments";

interface TravelerCommentCardProps {
  comment: TravelerComment;
  onDelete?: (commentId: string) => void;
}

export function TravelerCommentCard({ comment, onDelete }: TravelerCommentCardProps) {
  if (isTravelerCommentHidden(comment)) {
    return (
      <article className="traveler-comment-card traveler-comment-card--moderated">
        <div className="traveler-comment-avatar traveler-comment-avatar--muted">
          <EyeOff className="h-4 w-4" strokeWidth={1.5} />
        </div>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-white">
            Ce commentaire est en cours de modération.
          </p>
          <p className="mt-1 text-xs text-[#94A3B8]">
            {comment.lineName} · {comment.stopName} · {travelerCommentElapsedLabel(comment)}
          </p>
          <p className="mt-2 text-xs text-[#64748B]">
            {comment.reportCount} signalement{comment.reportCount > 1 ? "s" : ""}
          </p>
        </div>
        {onDelete && (
          <button
            type="button"
            className="traveler-comment-delete-btn"
            onClick={() => onDelete(comment.id)}
            aria-label="Supprimer le commentaire"
            title="Supprimer"
          >
            <Trash2 className="h-4 w-4" strokeWidth={1.5} />
          </button>
        )}
      </article>
    );
  }

  const categoryColor = TRAVELER_COMMENT_CATEGORY_COLORS[comment.category];

  return (
    <article className="traveler-comment-card">
      <div className="traveler-comment-avatar">
        {travelerCommentInitials(comment.authorName)}
      </div>
      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-sm font-semibold text-white">{comment.authorName}</span>
          {comment.authorCertified && (
            <span className="traveler-comment-certified">
              <ShieldCheck className="h-3 w-3" strokeWidth={2} />
              Voyageur certifié
            </span>
          )}
        </div>
        <p className="mt-0.5 text-xs text-[#94A3B8]">
          Ligne {comment.lineName} · {comment.vehicleService} · {comment.stopName} ·{" "}
          {travelerCommentElapsedLabel(comment)}
        </p>
        <p className="mt-2 text-sm leading-relaxed text-[#E2E8F0]">{comment.message}</p>
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <span
            className="traveler-comment-category"
            style={{
              color: categoryColor,
              background: `${categoryColor}1F`,
              borderColor: `${categoryColor}2E`,
            }}
          >
            {TRAVELER_COMMENT_CATEGORY_LABELS[comment.category]}
          </span>
          <span className="traveler-comment-reactions">
            <ThumbsUp className="h-3.5 w-3.5" strokeWidth={1.5} />
            {comment.reactionCount}
          </span>
          {comment.reportCount > 0 && (
            <span className="traveler-comment-reports">
              <Flag className="h-3 w-3" strokeWidth={1.5} />
              {comment.reportCount} signalement{comment.reportCount > 1 ? "s" : ""}
            </span>
          )}
        </div>
      </div>
      {onDelete && (
        <button
          type="button"
          className="traveler-comment-delete-btn"
          onClick={() => onDelete(comment.id)}
          aria-label="Supprimer le commentaire"
          title="Supprimer"
        >
          <Trash2 className="h-4 w-4" strokeWidth={1.5} />
        </button>
      )}
    </article>
  );
}
