"use client";

import { useEffect, useRef, useState } from "react";
import { Check, ChevronsUpDown, Layers } from "lucide-react";
import { PROFILE_META } from "@/lib/access/profiles";
import { useAccess, type ProfileFocus } from "./access-provider";

interface ProfileSwitcherProps {
  collapsed?: boolean;
}

/**
 * Focus de navigation pour les utilisateurs cumulant plusieurs profils.
 * Masqué s'il n'y a qu'un profil (aucun choix à offrir). Le défaut « Tous »
 * respecte le principe du brief : les modules se cumulent automatiquement.
 */
export function ProfileSwitcher({ collapsed = false }: ProfileSwitcherProps) {
  const { profiles, focus, setFocus } = useAccess();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    function onDown(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", onDown);
    return () => document.removeEventListener("mousedown", onDown);
  }, [open]);

  if (profiles.length < 2) return null;

  const currentLabel =
    focus === "all" ? "Tous les profils" : PROFILE_META[focus].label;

  function choose(next: ProfileFocus) {
    setFocus(next);
    setOpen(false);
  }

  return (
    <div className="profile-switcher" ref={ref}>
      <button
        type="button"
        className="profile-switcher-trigger"
        onClick={() => setOpen((v) => !v)}
        aria-haspopup="listbox"
        aria-expanded={open}
        title={collapsed ? currentLabel : undefined}
      >
        <Layers className="h-[16px] w-[16px] shrink-0" strokeWidth={1.5} />
        {!collapsed && (
          <>
            <span className="profile-switcher-label flex-1 truncate">
              {currentLabel}
            </span>
            <ChevronsUpDown
              className="h-[14px] w-[14px] shrink-0 opacity-60"
              strokeWidth={1.5}
            />
          </>
        )}
      </button>

      {open && (
        <div className="profile-switcher-menu" role="listbox">
          <Option
            label="Tous les profils"
            active={focus === "all"}
            onClick={() => choose("all")}
          />
          <div className="profile-switcher-sep" />
          {profiles.map((p) => (
            <Option
              key={p}
              label={PROFILE_META[p].label}
              active={focus === p}
              onClick={() => choose(p)}
            />
          ))}
        </div>
      )}
    </div>
  );
}

function Option({
  label,
  active,
  onClick,
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      role="option"
      aria-selected={active}
      className={`profile-switcher-option${active ? " active" : ""}`}
      onClick={onClick}
    >
      <span className="flex-1 truncate">{label}</span>
      {active && <Check className="h-[14px] w-[14px] shrink-0" strokeWidth={2} />}
    </button>
  );
}
