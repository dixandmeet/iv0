import type { LatLng } from "./geo";

export const CITY_CENTER: LatLng = [47.2184, -1.5536]; // Nantes

// "vtc"/"taxi" restent nécessaires au rendu 3D partagé (utilisé par l'animation
// d'accueil landing/hero-phone-map.tsx), même si la carte immersive n'affiche
// plus de VTC/taxis fictifs.
export type VehicleType = "bus" | "tram" | "vtc" | "taxi";

/** Représentation d'une ligne réelle en cours de suivi simulé sur son tracé GTFS. */
export type VehicleDef = {
  id: string;
  type: VehicleType;
  line?: string;
  dest?: string;
  nextStop?: string;
  status?: string;
};
