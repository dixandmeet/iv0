"use client";

import { useCallback, useEffect, useState } from "react";
import { Crosshair } from "lucide-react";

interface PointCoordinatesFieldProps {
  coordinates: [number, number];
  onCommit: (coordinates: [number, number]) => void;
}

function formatCoord(value: number): string {
  return value.toFixed(6);
}

function parseCoord(raw: string): number | null {
  const normalized = raw.trim().replace(",", ".");
  if (!normalized) return null;
  const num = Number(normalized);
  return Number.isFinite(num) ? num : null;
}

export function PointCoordinatesField({
  coordinates,
  onCommit,
}: PointCoordinatesFieldProps) {
  const [lng, setLng] = useState(formatCoord(coordinates[0]));
  const [lat, setLat] = useState(formatCoord(coordinates[1]));
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setLng(formatCoord(coordinates[0]));
    setLat(formatCoord(coordinates[1]));
    setError(null);
  }, [coordinates]);

  const apply = useCallback(() => {
    const lngNum = parseCoord(lng);
    const latNum = parseCoord(lat);

    if (lngNum == null || latNum == null) {
      setError("Saisissez des nombres décimaux valides");
      return;
    }
    if (latNum < -90 || latNum > 90) {
      setError("La latitude doit être entre -90 et 90");
      return;
    }
    if (lngNum < -180 || lngNum > 180) {
      setError("La longitude doit être entre -180 et 180");
      return;
    }

    setError(null);
    setLng(formatCoord(lngNum));
    setLat(formatCoord(latNum));

    if (
      Math.abs(lngNum - coordinates[0]) < 1e-7 &&
      Math.abs(latNum - coordinates[1]) < 1e-7
    ) {
      return;
    }

    onCommit([lngNum, latNum]);
  }, [coordinates, lat, lng, onCommit]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      e.preventDefault();
      apply();
    }
  };

  return (
    <div className="line-editor-coords-field">
      <h4 className="line-editor-card-title">
        <Crosshair className="h-4 w-4" />
        Coordonnées GPS
      </h4>
      <div className="line-editor-form-grid">
        <Field label="Latitude">
          <input
            className="line-editor-input"
            type="text"
            inputMode="decimal"
            value={lat}
            onChange={(e) => {
              setLat(e.target.value);
              setError(null);
            }}
            onBlur={apply}
            onKeyDown={handleKeyDown}
            placeholder="47.218371"
            aria-label="Latitude"
          />
        </Field>
        <Field label="Longitude">
          <input
            className="line-editor-input"
            type="text"
            inputMode="decimal"
            value={lng}
            onChange={(e) => {
              setLng(e.target.value);
              setError(null);
            }}
            onBlur={apply}
            onKeyDown={handleKeyDown}
            placeholder="-1.553621"
            aria-label="Longitude"
          />
        </Field>
      </div>
      {error && <p className="line-editor-coords-error">{error}</p>}
      <p className="line-editor-coords-hint">
        Format décimal (WGS 84). Validez avec Entrée ou en quittant le champ.
      </p>
    </div>
  );
}

function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="line-editor-field">
      <span className="line-editor-field-label">{label}</span>
      {children}
    </label>
  );
}
