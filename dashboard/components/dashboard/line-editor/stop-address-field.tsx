"use client";

import { useCallback, useEffect, useId, useRef, useState } from "react";
import { Loader2, MapPinned, Search } from "lucide-react";
import { searchAddresses, type GeocodeResult } from "@/lib/geocode";

interface StopAddressFieldProps {
  value: string;
  onChange: (address: string) => void;
  onLocate: (result: GeocodeResult) => void;
}

export function StopAddressField({
  value,
  onChange,
  onLocate,
}: StopAddressFieldProps) {
  const listboxId = useId();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [suggestions, setSuggestions] = useState<GeocodeResult[]>([]);
  const [open, setOpen] = useState(false);
  const abortRef = useRef<AbortController | null>(null);

  const pick = useCallback(
    (result: GeocodeResult) => {
      onChange(result.label);
      onLocate(result);
      setSuggestions([]);
      setOpen(false);
      setError(null);
    },
    [onChange, onLocate],
  );

  const runSearch = useCallback(async (query: string) => {
    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    setLoading(true);
    setError(null);
    try {
      const results = await searchAddresses(query, controller.signal);
      if (results.length === 1) {
        pick(results[0]);
        return;
      }
      setSuggestions(results);
      setOpen(results.length > 0);
      if (results.length === 0) {
        setError("Aucun résultat — précisez l'adresse ou ajoutez « Nantes ».");
      }
    } catch (err) {
      if (controller.signal.aborted) return;
      setSuggestions([]);
      setOpen(false);
      setError(
        err instanceof Error ? err.message : "Impossible de localiser l'adresse",
      );
    } finally {
      if (!controller.signal.aborted) setLoading(false);
    }
  }, [pick]);

  const handleLocate = useCallback(() => {
    const query = value.trim();
    if (query.length < 3) {
      setError("Saisissez au moins 3 caractères");
      return;
    }
    void runSearch(query);
  }, [runSearch, value]);

  useEffect(() => {
    return () => abortRef.current?.abort();
  }, []);

  return (
    <div className="line-editor-address-field">
      <Field label="Adresse de l'arrêt" className="col-span-2">
        <div className="line-editor-address-input-wrap">
          <input
            className="line-editor-input line-editor-address-input"
            value={value}
            onChange={(e) => {
              onChange(e.target.value);
              setError(null);
            }}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                handleLocate();
              }
            }}
            placeholder="Ex. 10 rue de Strasbourg, 44000 Nantes"
            autoComplete="street-address"
            role="combobox"
            aria-expanded={open}
            aria-controls={listboxId}
          />
          <button
            type="button"
            className="line-editor-address-locate-btn"
            onClick={handleLocate}
            disabled={loading || value.trim().length < 3}
            title="Localiser sur la carte"
          >
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Search className="h-4 w-4" />
            )}
            Localiser
          </button>
        </div>
      </Field>

      {error && <p className="line-editor-address-error">{error}</p>}

      {open && suggestions.length > 0 && (
        <ul
          id={listboxId}
          className="line-editor-address-suggestions"
          role="listbox"
        >
          {suggestions.map((result) => (
            <li key={`${result.lng}-${result.lat}-${result.label}`}>
              <button
                type="button"
                className="line-editor-address-suggestion"
                onClick={() => pick(result)}
              >
                <MapPinned className="h-3.5 w-3.5 shrink-0" />
                <span>{result.label}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function Field({
  label,
  children,
  className,
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <label className={`line-editor-field${className ? ` ${className}` : ""}`}>
      <span className="line-editor-field-label">{label}</span>
      {children}
    </label>
  );
}
