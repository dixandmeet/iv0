import assert from "node:assert/strict";
import test from "node:test";

import { distanceMeters } from "../lib/carte-immersive/geo.ts";

test("distanceMeters returns zero for the same point", () => {
  assert.equal(distanceMeters([47.2184, -1.5536], [47.2184, -1.5536]), 0);
});

test("distanceMeters computes a realistic distance around Nantes", () => {
  const distance = distanceMeters(
    [47.2184, -1.5536],
    [47.2257, -1.5224],
  );

  assert.ok(distance > 2_400 && distance < 2_600, `distance: ${distance}`);
});
