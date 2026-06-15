"use client";

import { useMemo } from "react";
import { LandingMapView } from "./landing-map-view";
import { networks } from "./landing-data";
import { FRANCE_CENTER } from "@/lib/landing-map-style";

export function CoverageMap({ className }: { className?: string }) {
  const markers = useMemo(
    () =>
      networks.map((n) => ({
        id: n.id,
        lng: n.lng,
        lat: n.lat,
        label: n.city,
        status: n.status as "pilot" | "coming",
        badge: n.status === "pilot" ? "Pilote" : undefined,
      })),
    [],
  );

  return (
    <LandingMapView
      center={FRANCE_CENTER}
      zoom={5.4}
      minZoom={4}
      maxZoom={8}
      interactive={false}
      markers={markers}
      className={className}
      ariaLabel="Carte de France avec les réseaux de transport couverts par Aule"
    />
  );
}
