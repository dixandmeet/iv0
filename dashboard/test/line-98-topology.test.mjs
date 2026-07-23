import assert from "node:assert/strict";
import test from "node:test";

import { TTX_DEPOT_LINES } from "../lib/ttx-depot-lines.ts";
import {
  buildLineTopologyFromTrips,
  fitTopologyColumnWidth,
  topologyMinWidth,
} from "../lib/line-topology.ts";

function stopId(name) {
  return name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-");
}

test("la ligne 98 affiche ses deux branches au départ de Neustrie", () => {
  const line = TTX_DEPOT_LINES.find((candidate) => candidate.id === "98");
  assert.ok(line);
  assert.equal(line.variants?.length, 2);

  const trips = line.variants.map((variant) => ({
    tripId: variant.id,
    headsign: variant.destination,
    directionId: 0,
    shapeId: null,
    stopIds: variant.stops.map(stopId),
    stops: variant.stops.map((name, index) => ({
      stopId: stopId(name),
      name,
      coordinates: [index, 0],
      theoreticalTime: "—",
    })),
  }));

  const topology = buildLineTopologyFromTrips(trips);
  assert.ok(topology?.isComplex);
  assert.equal(topology.laneCount, 2);
  assert.deepEqual(
    topology.variants.map((variant) => variant.destination),
    ["Brains", "St-Léger-les-Vignes"],
  );

  const termini = topology.nodes
    .filter((node) => node.role === "terminus")
    .map((node) => node.name);
  assert.deepEqual(termini, ["Neustrie", "Brains", "St-Léger-les-Vignes"]);

  const viewportWidth = 1800;
  const fittedColumnWidth = fitTopologyColumnWidth(
    topology.columnCount,
    viewportWidth,
  );
  assert.ok(fittedColumnWidth < 72);
  assert.ok(
    topologyMinWidth(topology.columnCount, fittedColumnWidth) <= viewportWidth,
  );
});
