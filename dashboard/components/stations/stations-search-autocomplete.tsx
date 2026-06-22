"use client";

import { useCallback, useEffect, useId, useRef, useState } from "react";
import { Loader2, MapPin, Search } from "lucide-react";
import { useStationSearchSuggestions } from "@/hooks/use-station-search-suggestions";
import type { StationListItem } from "@/lib/stations-types";
import { Input } from "@/components/ui/input";

interface StationsSearchAutocompleteProps {
  value: string;
  onChange: (value: string) => void;
  onSelectStation: (stationId: string, stationName: string) => void;
}

export function StationsSearchAutocomplete({
  value,
  onChange,
  onSelectStation,
}: StationsSearchAutocompleteProps) {
  const listboxId = useId();
  const containerRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const { suggestions, loading, hasQuery } = useStationSearchSuggestions(value);
  const showDropdown = open && hasQuery && (loading || suggestions.length > 0);

  const pick = useCallback(
    (item: StationListItem) => {
      onChange(item.name);
      onSelectStation(item.id, item.name);
      setOpen(false);
      setActiveIndex(-1);
    },
    [onChange, onSelectStation],
  );

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (!containerRef.current?.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div ref={containerRef} className="stops-search-autocomplete">
      <Search className="stops-search-icon h-4 w-4" />
      <Input
        value={value}
        onChange={(e) => {
          onChange(e.target.value);
          setOpen(true);
        }}
        onFocus={() => setOpen(true)}
        onKeyDown={(e) => {
          if (e.key === "ArrowDown") {
            e.preventDefault();
            setActiveIndex((i) => Math.min(i + 1, suggestions.length - 1));
          } else if (e.key === "ArrowUp") {
            e.preventDefault();
            setActiveIndex((i) => Math.max(i - 1, 0));
          } else if (e.key === "Enter" && activeIndex >= 0) {
            e.preventDefault();
            pick(suggestions[activeIndex]);
          } else if (e.key === "Escape") {
            setOpen(false);
          }
        }}
        placeholder="Rechercher une station (Commerce, Ranzay, Gare Sud…)"
        className="stops-search-input"
        autoComplete="off"
        role="combobox"
        aria-expanded={showDropdown}
      />
      {showDropdown && (
        <ul id={listboxId} className="stops-search-dropdown" role="listbox">
          {loading && suggestions.length === 0 && (
            <li className="stops-search-dropdown-status">
              <Loader2 className="h-4 w-4 animate-spin" /> Recherche…
            </li>
          )}
          {!loading && suggestions.length === 0 && (
            <li className="stops-search-dropdown-status">Aucune station trouvée</li>
          )}
          {suggestions.map((item, index) => (
            <li key={item.id} role="presentation">
              <button
                type="button"
                role="option"
                className={`stops-search-option${index === activeIndex ? " stops-search-option--active" : ""}`}
                onClick={() => pick(item)}
              >
                <MapPin className="stops-search-option-icon h-4 w-4 shrink-0" />
                <span className="stops-search-option-main">
                  <span className="stops-search-option-name">{item.name}</span>
                  <span className="stops-search-option-meta">
                    {item.commune && <span>{item.commune}</span>}
                    <span>{item.stop_count} arrêt{item.stop_count !== 1 ? "s" : ""}</span>
                  </span>
                </span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
