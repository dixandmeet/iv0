"use client";

import {
  useCallback,
  useEffect,
  useId,
  useRef,
  useState,
  type KeyboardEvent,
} from "react";
import { searchAddresses, type GeocodeResult } from "@/lib/geocode";
import styles from "./scrolly-landing.module.css";

export function splitAddressLabel(labelText: string) {
  const [title, ...details] = labelText.split(",");

  return {
    title: title.trim(),
    details: details.join(",").trim(),
  };
}

export function useAddressAutocomplete({
  initialQuery = "",
  onUserInput,
}: {
  initialQuery?: string;
  onUserInput?: () => void;
} = {}) {
  const listboxId = useId();
  const abortRef = useRef<AbortController | null>(null);
  const touchedRef = useRef(false);
  const [query, setQuery] = useState(initialQuery);
  const [suggestions, setSuggestions] = useState<GeocodeResult[]>([]);
  const [selected, setSelected] = useState<GeocodeResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeIndex, setActiveIndex] = useState(-1);

  const clearSearch = useCallback(() => {
    abortRef.current?.abort();
    setSuggestions([]);
    setOpen(false);
    setActiveIndex(-1);
    setLoading(false);
  }, []);

  const pick = useCallback((result: GeocodeResult) => {
    setQuery(result.label);
    setSelected(result);
    setSuggestions([]);
    setOpen(false);
    setError(null);
    setActiveIndex(-1);
  }, []);

  const setValue = useCallback((value: string, result?: GeocodeResult | null) => {
    setQuery(value);
    setSelected(result ?? null);
    setSuggestions([]);
    setOpen(false);
    setError(null);
    setActiveIndex(-1);
    setLoading(false);
  }, []);

  const handleChange = useCallback(
    (nextValue: string) => {
      touchedRef.current = true;
      setQuery(nextValue);
      setSelected(null);
      setError(null);
      onUserInput?.();

      if (nextValue.trim().length < 3) {
        clearSearch();
      }
    },
    [clearSearch, onUserInput],
  );

  const handleFocus = useCallback(() => {
    setOpen(suggestions.length > 0);
  }, [suggestions.length]);

  const pickActiveSuggestion = useCallback(() => {
    if (suggestions.length === 0) return null;
    const nextIndex = activeIndex >= 0 ? activeIndex : 0;
    const result = suggestions[nextIndex];
    pick(result);
    return result;
  }, [activeIndex, pick, suggestions]);

  const handleKeyDown = useCallback(
    (event: KeyboardEvent<HTMLInputElement>) => {
      if (event.key === "ArrowDown" && suggestions.length > 0) {
        event.preventDefault();
        setOpen(true);
        setActiveIndex((current) => (current + 1) % suggestions.length);
        return;
      }

      if (event.key === "ArrowUp" && suggestions.length > 0) {
        event.preventDefault();
        setOpen(true);
        setActiveIndex((current) => (current <= 0 ? suggestions.length - 1 : current - 1));
        return;
      }

      if (event.key === "Enter" && open && suggestions.length > 0) {
        event.preventDefault();
        pickActiveSuggestion();
        return;
      }

      if (event.key === "Escape") {
        setOpen(false);
      }
    },
    [open, pickActiveSuggestion, suggestions.length],
  );

  useEffect(() => {
    const trimmedQuery = query.trim();

    if (trimmedQuery.length < 3 || selected?.label === query) {
      return undefined;
    }

    // Ne pas déclencher de recherche automatique sur la valeur initiale (adresse
    // pré-remplie) tant que l'utilisateur n'a pas interagi : évite l'ouverture de la
    // liste au chargement et le scroll intempestif vers le champ.
    if (!touchedRef.current && trimmedQuery === initialQuery.trim()) {
      return undefined;
    }

    const controller = new AbortController();
    abortRef.current?.abort();
    abortRef.current = controller;

    const timer = window.setTimeout(() => {
      setLoading(true);
      setError(null);

      void searchAddresses(trimmedQuery, controller.signal)
        .then((results) => {
          setSuggestions(results);
          setOpen(results.length > 0);
          setActiveIndex(results.length > 0 ? 0 : -1);
          setError(
            results.length === 0
              ? "Aucune adresse trouvée. Ajoutez la ville ou le code postal."
              : null,
          );
        })
        .catch((searchError: unknown) => {
          if (controller.signal.aborted) return;

          setSuggestions([]);
          setOpen(false);
          setActiveIndex(-1);
          setError(
            searchError instanceof Error
              ? searchError.message
              : "Impossible de rechercher cette adresse.",
          );
        })
        .finally(() => {
          if (!controller.signal.aborted) {
            setLoading(false);
          }
        });
    }, 260);

    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [query, selected?.label, initialQuery]);

  useEffect(() => {
    return () => abortRef.current?.abort();
  }, []);

  return {
    activeIndex,
    error,
    handleChange,
    handleFocus,
    handleKeyDown,
    listboxId,
    loading,
    open,
    pick,
    pickActiveSuggestion,
    query,
    selected,
    setError,
    setOpen,
    setValue,
    suggestions,
  };
}

export type AddressAutocompleteState = ReturnType<typeof useAddressAutocomplete>;

export function AddressSuggestions({
  autocomplete,
  label,
}: {
  autocomplete: AddressAutocompleteState;
  label: string;
}) {
  if (
    !autocomplete.loading &&
    !autocomplete.error &&
    autocomplete.suggestions.length === 0
  ) {
    return null;
  }

  return (
    <div
      id={autocomplete.listboxId}
      className={styles.addressAutocomplete}
      role="listbox"
      aria-label={label}
    >
      {autocomplete.loading ? (
        <div className={styles.addressAutocompleteStatus}>Recherche d&apos;adresses...</div>
      ) : null}
      {!autocomplete.loading
        ? autocomplete.suggestions.map((result, index) => {
          const address = splitAddressLabel(result.label);
          const isActive = autocomplete.open && index === autocomplete.activeIndex;

          return (
            <button
              key={`${result.lng}-${result.lat}-${result.label}`}
              id={`${autocomplete.listboxId}-${index}`}
              type="button"
              role="option"
              aria-selected={isActive}
              className={`${styles.addressSuggestion} ${isActive ? styles.addressSuggestionActive : ""}`}
              onMouseDown={(event) => {
                event.preventDefault();
                autocomplete.pick(result);
              }}
              onClick={() => autocomplete.pick(result)}
            >
              <span className={styles.addressSuggestionPin} aria-hidden="true" />
              <span>
                <strong>{address.title}</strong>
                {address.details ? <small>{address.details}</small> : null}
              </span>
            </button>
          );
        })
        : null}
      {!autocomplete.loading && autocomplete.error ? (
        <div className={styles.addressAutocompleteStatus}>{autocomplete.error}</div>
      ) : null}
    </div>
  );
}
