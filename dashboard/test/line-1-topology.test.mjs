import assert from "node:assert/strict";
import test from "node:test";

import { getNetworkLinePatterns } from "../lib/network-line-patterns.ts";
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

test("la ligne 1 conserve ses quatre terminus et ses deux bifurcations", () => {
  const patterns = getNetworkLinePatterns("1");
  assert.equal(patterns.length, 4);

  const trips = patterns.map((pattern) => ({
    tripId: pattern.id,
    headsign: pattern.destination,
    directionId: 0,
    shapeId: null,
    stopIds: pattern.stops.map(stopId),
    stops: pattern.stops.map((name, index) => ({
      stopId: stopId(name),
      name,
      coordinates: [index, 0],
      theoreticalTime: "—",
    })),
  }));

  const topology = buildLineTopologyFromTrips(trips);
  assert.ok(topology?.isComplex);
  assert.equal(topology.variants.length, 4);

  const termini = topology.nodes
    .filter((node) => node.role === "terminus")
    .map((node) => node.name)
    .sort((a, b) => a.localeCompare(b, "fr"));
  assert.deepEqual(termini, [
    "Babinière",
    "Beaujoire",
    "François Mitterrand",
    "Jamet",
  ]);

  const croixBonneau = topology.nodes.find((node) => node.name === "Croix Bonneau");
  const haluchere = topology.nodes.find(
    (node) => node.name === "Haluchère - Batignolles",
  );
  const jamet = topology.nodes.find((node) => node.name === "Jamet");
  assert.equal(croixBonneau?.role, "hub");
  assert.equal(haluchere?.role, "hub");
  assert.equal(jamet?.column, (croixBonneau?.column ?? 0) - 1);

  const viewportWidth = 1600;
  const fittedColumnWidth = fitTopologyColumnWidth(
    topology.columnCount,
    viewportWidth,
  );
  assert.ok(
    topologyMinWidth(topology.columnCount, fittedColumnWidth) <= viewportWidth,
  );
});
