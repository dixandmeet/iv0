import test from "node:test";
import assert from "node:assert/strict";

import { vehicleScheduleMotionAt } from "../lib/carte-immersive/vehicle-schedule-motion.ts";
import { getVehicleTimeColor } from "../lib/carte-immersive/vehicle-time-palette.ts";

const stops = [
  { fraction: 0, passageAtMs: 100_000 },
  { fraction: 0.4, passageAtMs: 220_000 },
  { fraction: 1, passageAtMs: 400_000 },
];

test("le véhicule attend en station avant de repartir", () => {
  assert.deepEqual(vehicleScheduleMotionAt(stops, 110_000), {
    fraction: 0,
    fractionPerSecond: 0,
    stopped: true,
  });
});

test("le véhicule atteint chaque station à son heure de passage", () => {
  assert.equal(vehicleScheduleMotionAt(stops, 220_000)?.fraction, 0.4);
  assert.equal(vehicleScheduleMotionAt(stops, 400_000)?.fraction, 1);
});

test("la progression entre stations suit l'intervalle horaire", () => {
  const motion = vehicleScheduleMotionAt(stops, 160_000);
  assert.ok(motion && motion.fraction > 0 && motion.fraction < 0.4);
  assert.equal(motion?.stopped, false);
  assert.ok((motion?.fractionPerSecond ?? 0) > 0);
});

test("le tram est clair le jour et bleuté la nuit à l'heure de Paris", () => {
  assert.equal(
    getVehicleTimeColor("tram", new Date("2026-07-20T12:00:00.000Z")),
    "#e4eeeb",
  );
  assert.equal(
    getVehicleTimeColor("tram", new Date("2026-07-20T01:00:00.000Z")),
    "#3f6684",
  );
});

test("le bus reste clair au crépuscule", () => {
  assert.equal(
    getVehicleTimeColor("bus", new Date("2026-07-20T18:30:00.000Z")),
    "#d19499",
  );
});
