"use client";

import { useEffect, useId } from "react";
import { BookOpen, X } from "lucide-react";
import {
  LINE_EDITOR_GUIDE_SECTIONS,
  LINE_EDITOR_GUIDE_TITLE,
} from "@/lib/line-editor-guide";

interface LineEditorGuideModalProps {
  open: boolean;
  onClose: () => void;
}

export function LineEditorGuideModal({ open, onClose }: LineEditorGuideModalProps) {
  const titleId = useId();

  useEffect(() => {
    if (!open) return;

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") onClose();
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className="line-editor-guide-overlay"
      onClick={onClose}
      role="presentation"
    >
      <div
        className="line-editor-guide-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        onClick={(event) => event.stopPropagation()}
      >
        <header className="line-editor-guide-header">
          <div className="line-editor-guide-header-title">
            <BookOpen className="h-5 w-5 text-[#3B82F6]" />
            <h2 id={titleId}>{LINE_EDITOR_GUIDE_TITLE}</h2>
          </div>
          <button
            type="button"
            className="line-editor-guide-close"
            onClick={onClose}
            aria-label="Fermer la documentation"
          >
            <X className="h-4 w-4" />
          </button>
        </header>

        <nav className="line-editor-guide-toc" aria-label="Sommaire">
          {LINE_EDITOR_GUIDE_SECTIONS.map((section) => (
            <a key={section.id} href={`#guide-${section.id}`}>
              {section.title}
            </a>
          ))}
        </nav>

        <div className="line-editor-guide-body">
          {LINE_EDITOR_GUIDE_SECTIONS.map((section) => (
            <section
              key={section.id}
              id={`guide-${section.id}`}
              className="line-editor-guide-section"
            >
              <h3>{section.title}</h3>
              {section.paragraphs.map((paragraph) => (
                <p key={paragraph}>{paragraph}</p>
              ))}
              {section.diagram && (
                <pre className="line-editor-guide-diagram">{section.diagram}</pre>
              )}
              {section.bullets && section.bullets.length > 0 && (
                <ul>
                  {section.bullets.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              )}
            </section>
          ))}
        </div>
      </div>
    </div>
  );
}
