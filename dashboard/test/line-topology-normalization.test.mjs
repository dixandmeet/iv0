import assert from "node:assert/strict";
import test from "node:test";

import {
  buildLineTopologyFromEditorState,
  buildLineTopologyFromTrips,
  variantForTripId,
} from "../lib/line-topology.ts";

function trip(tripId, names, directionId = 0) {
  const suffix = directionId === 0 ? "1" : "2";
  return {
    tripId,
    headsign: names[names.length - 1],
    directionId,
    shapeId: `${tripId}-shape`,
    stopIds: names.map((name) => `${name}${suffix}`),
    stops: names.map((name, index) => ({
      stopId: `${name}${suffix}`,
      stationId: `station-${name}`,
      name,
      coordinates: [index, directionId],
      theoreticalTime: `08:${String(index).padStart(2, "0")}`,
    })),
  };
}

function editorPoint(id, name, code, type) {
  return {
    id,
    coordinates: [Number(id.replace(/\D/g, "")) || 0, 0],
    type,
    stop: {
      name,
      code,
      address: "",
      direction: "both",
      order: 1,
      travelTimeMinutes: 2,
      wheelchairAccessible: false,
      connections: "",
      notes: "",
    },
  };
}

test("regroupe les quais aller et retour d'un même parcours physique", () => {
  const aller = trip("aller", ["A", "B", "C", "D"], 0);
  const retour = trip("retour", ["D", "C", "B", "A"], 1);
  const topology = buildLineTopologyFromTrips([aller, retour]);

  assert.ok(topology);
  assert.equal(topology.variants.length, 1);
  assert.equal(topology.variants[0].kind, "full");
  assert.equal(topology.nodes.length, 4);
  assert.equal(variantForTripId(topology, "aller")?.id, topology.variants[0].id);
  assert.equal(variantForTripId(topology, "retour")?.id, topology.variants[0].id);
});

test("classe un service intérieur comme parcours partiel, pas comme branche", () => {
  const full = trip("full", ["A", "B", "C", "D", "E"], 0);
  const partial = trip("partial", ["D", "C", "B"], 1);
  const topology = buildLineTopologyFromTrips([full, partial]);

  assert.ok(topology);
  assert.equal(topology.variants.length, 2);
  assert.equal(
    topology.variants.find((variant) => variant.tripId === "partial")?.kind,
    "partial",
  );
  assert.equal(topology.laneCount, 1);
});

test("un éditeur sans branche produit un seul parcours aller-retour", () => {
  const aller = [
    editorPoint("a1", "Alpha", "ALP1", "terminus_start"),
    editorPoint("b1", "Beta", "BET1", "stop"),
    editorPoint("c1", "Gamma", "GAM1", "terminus_end"),
  ];
  const retour = [
    editorPoint("c2", "Gamma", "GAM2", "terminus_start"),
    editorPoint("b2", "Beta", "BET2", "stop"),
    editorPoint("a2", "Alpha", "ALP2", "terminus_end"),
  ];
  const topology = buildLineTopologyFromEditorState({
    id: "line-2",
    name: "Ligne 2",
    shortName: "2",
    color: "#22C55E",
    transportMode: "tram",
    directionAller: "Alpha → Gamma",
    directionRetour: "Gamma → Alpha",
    status: "draft",
    activeVoice: "aller",
    pointsAller: aller,
    pointsRetour: retour,
    branchesAller: [],
    branchesRetour: [],
    originLegsAller: [],
    originLegsRetour: [],
    activeBranchId: null,
    activeOriginLegId: null,
    selectedPointId: "a1",
  });

  assert.ok(topology);
  assert.equal(topology.variants.length, 1);
  assert.equal(topology.isComplex, false);
  assert.equal(topology.nodes.length, 3);
});
