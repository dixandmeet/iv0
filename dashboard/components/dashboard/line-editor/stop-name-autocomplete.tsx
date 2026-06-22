"use client";

import { useCallback, useEffect, useId, useMemo, useRef, useState } from "react";
import { Loader2, MapPin, Plus } from "lucide-react";
import {
  filterRegisteredStops,
  hasExactRegisteredStopName,
  type RegisteredStop,
} from "@/lib/registered-stops";

interface StopNameAutocompleteProps {
  value: string;
  catalog: RegisteredStop[];
  catalogLoading?: boolean;
  onChange: (value: string) => void;
  onSelectStop: (stop: RegisteredStop) => void;
  onCreateStop: (name: string) => void;
}

type SuggestionItem =
  | { kind: "stop"; stop: RegisteredStop }
  | { kind: "create"; name: string };

export function StopNameAutocomplete({
  value,
  catalog,
  catalogLoading = false,
  onChange,
  onSelectStop,
  onCreateStop,
}: StopNameAutocompleteProps) {
  const listboxId = useId();
  const containerRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);

  const trimmedValue = value.trim();
  const suggestions = useMemo(() => filterRegisteredStops(catalog, value), [catalog, value]);
  const showCreate =
    trimmedValue.length > 0 && !hasExactRegisteredStopName(catalog, trimmedValue);

  const items = useMemo((): SuggestionItem[] => {
    const list: SuggestionItem[] = suggestions.map((stop) => ({
      kind: "stop",
      stop,
    }));
    if (showCreate) {
      list.push({ kind: "create", name: trimmedValue });
    }
    return list;
  }, [suggestions, showCreate, trimmedValue]);

  const showDropdown =
    open &&
    (catalogLoading || items.length > 0 || (trimmedValue.length > 0 && !catalogLoading));

  const pick = useCallback(
    (item: SuggestionItem) => {
      if (item.kind === "create") {
        onCreateStop(item.name);
      } else {
        onSelectStop(item.stop);
      }
      setOpen(false);
      setActiveIndex(-1);
    },
    [onCreateStop, onSelectStop],
  );

  useEffect(() => {
    setActiveIndex(-1);
  }, [value, items.length]);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (!containerRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div ref={containerRef} className="line-editor-stop-autocomplete">
      <input
        className="line-editor-input"
        value={value}
        onChange={(e) => {
          onChange(e.target.value);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        onKeyDown={(e) => {
          if (e.key === "ArrowDown") {
            e.preventDefault();
            if (items.length === 0) return;
            setActiveIndex((index) => Math.min(index + 1, items.length - 1));
          } else if (e.key === "ArrowUp") {
            e.preventDefault();
            setActiveIndex((index) => Math.max(index - 1, 0));
          } else if (e.key === "Enter" && activeIndex >= 0) {
            e.preventDefault();
            pick(items[activeIndex]);
          } else if (e.key === "Escape") {
            setOpen(false);
          }
        }}
        placeholder="Ex. Commerce"
        autoComplete="off"
        role="combobox"
        aria-expanded={showDropdown}
        aria-controls={listboxId}
      />

      {showDropdown && (
        <ul id={listboxId} className="line-editor-stop-dropdown" role="listbox">
          {catalogLoading && items.length === 0 && (
            <li className="line-editor-stop-dropdown-status">
              <Loader2 className="h-4 w-4 animate-spin" />
              Chargement des arrêts…
            </li>
          )}

          {!catalogLoading && trimmedValue.length === 0 && items.length === 0 && (
            <li className="line-editor-stop-dropdown-status">
              Aucun arrêt enregistré pour le moment
            </li>
          )}

          {!catalogLoading &&
            trimmedValue.length > 0 &&
            suggestions.length === 0 &&
            !showCreate && (
              <li className="line-editor-stop-dropdown-status">
                Aucun arrêt trouvé
              </li>
            )}

          {items.map((item, index) =>
            item.kind === "create" ? (
              <li key={`create-${item.name}`} role="presentation">
                <button
                  type="button"
                  role="option"
                  aria-selected={index === activeIndex}
                  className={`line-editor-stop-option line-editor-stop-option--create${
                    index === activeIndex ? " line-editor-stop-option--active" : ""
                  }`}
                  onClick={() => pick(item)}
                >
                  <Plus className="line-editor-stop-option-icon h-4 w-4 shrink-0" />
                  <span className="line-editor-stop-option-main">
                    <span className="line-editor-stop-option-name">
                      Créer l&apos;arrêt « {item.name} »
                    </span>
                    <span className="line-editor-stop-option-meta">
                      Nouvel arrêt sur cette ligne
                    </span>
                  </span>
                </button>
              </li>
            ) : (
              <li key={item.stop.id} role="presentation">
                <button
                  type="button"
                  role="option"
                  aria-selected={index === activeIndex}
                  className={`line-editor-stop-option${
                    index === activeIndex ? " line-editor-stop-option--active" : ""
                  }`}
                  onClick={() => pick(item)}
                >
                  <MapPin className="line-editor-stop-option-icon h-4 w-4 shrink-0" />
                  <span className="line-editor-stop-option-main">
                    <span className="line-editor-stop-option-name">{item.stop.name}</span>
                    <span className="line-editor-stop-option-meta">
                      {item.stop.code && <span>Code {item.stop.code}</span>}
                      {item.stop.stationName && <span>{item.stop.stationName}</span>}
                      {item.stop.source === "editor" && <span>Brouillon éditeur</span>}
                    </span>
                  </span>
                </button>
              </li>
            ),
          )}
        </ul>
      )}
    </div>
  );
}
