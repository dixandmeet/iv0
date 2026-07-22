import test from "node:test";
import assert from "node:assert/strict";

import { nextDepartureWaitSeconds } from "../lib/carte-immersive/naolib-realtime.ts";
import {
  canBoardScheduledDeparture,
  journeyPathKey,
  rankTransitCandidates,
  transitRouteRefreshDelay,
} from "../lib/carte-immersive/transit-quality.ts";
import {
  activeStopPassages,
  lineBadgeTextColor,
  nextDayScheduleIndex,
  serviceDayElapsedSeconds,
  stopPassageWaitMinutes,
} from "../lib/carte-immersive/stop-schedule.ts";
import { selectLiveVehicleForSchedule } from "../lib/carte-immersive/vehicles.ts";
import { lineStringCoordinates } from "../lib/geo.ts";
import { getVehicleShadowStyle } from "../lib/carte-immersive/vehicle-time-palette.ts";

function passage(directionKey, destination, expectedAt) {
  return {
    id: `${directionKey}-${expectedAt}`,
    line: "C6",
    direction: destination,
    destination,
    expectedAt,
    waitMinutes: 0,
    realtime: true,
    directionKey,
  };
}

test("le temps réel est associé au terminus et non à direction_id + 1", () => {
  const passages = [
    passage(1, "Chantrerie - Grandes Écoles", "2026-07-19T20:33:00.000Z"),
    passage(2, "Hermeland", "2026-07-19T20:36:00.000Z"),
  ];
  const match = nextDepartureWaitSeconds(
    passages,
    "C6",
    "Hermeland",
    new Date("2026-07-19T20:32:00.000Z"),
  );

  assert.equal(match?.expectedAt, "2026-07-19T20:36:00.000Z");
  assert.equal(match?.destination, "Hermeland");
  assert.equal(match?.waitSeconds, 4 * 60);
});

test("un terminus composite accepte une de ses destinations opérationnelles", () => {
  const match = nextDepartureWaitSeconds(
    [passage(1, "Jamet", "2026-07-19T20:40:00.000Z")],
    "C6",
    "François Mitterrand / Jamet",
    new Date("2026-07-19T20:35:00.000Z"),
  );
  assert.equal(match?.destination, "Jamet");
});

test("sans terminus, un flux contenant deux sens n'est jamais deviné", () => {
  const match = nextDepartureWaitSeconds(
    [
      passage(1, "Chantrerie", "2026-07-19T20:33:00.000Z"),
      passage(2, "Hermeland", "2026-07-19T20:36:00.000Z"),
    ],
    "C6",
    null,
    new Date("2026-07-19T20:32:00.000Z"),
  );
  assert.equal(match, null);
});

test("deux points de correspondance d'une même chaîne restent distincts", () => {
  const routes = ["C6", "3"];
  const common = {
    type: "transit",
    route_id: "C6",
    from_stop_id: "ranzay",
  };
  const saintPierre = journeyPathKey(routes, [
    { ...common, to_stop_id: "saint-pierre" },
    { type: "walk", kind: "transfer", from_stop_id: "saint-pierre", to_stop_id: "commerce" },
  ]);
  const placeDuCirque = journeyPathKey(routes, [
    { ...common, to_stop_id: "place-du-cirque" },
    { type: "walk", kind: "transfer", from_stop_id: "place-du-cirque", to_stop_id: "bretagne" },
  ]);
  assert.notEqual(saintPierre, placeDuCirque);
});

test("le classement élimine un trajet de même arrivée mais avec plus de marche", () => {
  const requestedAt = new Date("2026-07-19T20:27:00.000Z");
  const ranked = rankTransitCandidates(
    [
      {
        id: "saint-pierre",
        duration: 4200,
        departureAt: requestedAt.toISOString(),
        arrivalAt: "2026-07-19T21:43:00.000Z",
        transfers: 1,
        walkSeconds: 29 * 60,
      },
      {
        id: "place-du-cirque",
        duration: 4200,
        departureAt: requestedAt.toISOString(),
        arrivalAt: "2026-07-19T21:43:00.000Z",
        transfers: 1,
        walkSeconds: 25 * 60,
      },
    ],
    requestedAt,
    4,
  );
  assert.deepEqual(ranked.map(({ id }) => id), ["place-du-cirque"]);
});

test("le classement compare l'arrivée absolue, pas la seule durée embarquée", () => {
  const requestedAt = new Date("2026-07-19T20:00:00.000Z");
  const ranked = rankTransitCandidates(
    [
      {
        id: "depart-maintenant",
        duration: 60 * 60,
        departureAt: "2026-07-19T20:00:00.000Z",
        arrivalAt: "2026-07-19T21:00:00.000Z",
        transfers: 1,
      },
      {
        id: "depart-plus-tard",
        duration: 45 * 60,
        departureAt: "2026-07-19T20:20:00.000Z",
        arrivalAt: "2026-07-19T21:05:00.000Z",
        transfers: 1,
      },
    ],
    requestedAt,
    4,
  );
  assert.equal(ranked[0]?.id, "depart-maintenant");
});

test("une marche réelle trop longue invalide une correspondance théorique", () => {
  const scheduled = new Date("2026-07-19T21:00:00.000Z");
  assert.equal(
    canBoardScheduledDeparture(scheduled, new Date("2026-07-19T21:00:20.000Z")),
    true,
  );
  assert.equal(
    canBoardScheduledDeparture(scheduled, new Date("2026-07-19T21:01:00.000Z")),
    false,
  );
});

test("un itinéraire est recalculé dès que son heure de départ est passée", () => {
  const departureAt = "2026-07-20T16:20:00.000Z";

  assert.equal(
    transitRouteRefreshDelay(
      departureAt,
      new Date("2026-07-20T16:19:30.000Z"),
      1_000,
    ),
    31_000,
  );
  assert.equal(
    transitRouteRefreshDelay(
      departureAt,
      new Date("2026-07-20T16:23:00.000Z"),
      1_000,
    ),
    0,
  );
});

test("aucun recalcul horaire n'est programmé sans départ exploitable", () => {
  assert.equal(transitRouteRefreshDelay(undefined), null);
  assert.equal(transitRouteRefreshDelay("heure-invalide"), null);
});

test("les horaires de passage avancent et les départs échus disparaissent", () => {
  const now = new Date("2026-07-20T17:01:30.000Z").getTime();
  const passages = [
    { id: "passe", expectedAt: "2026-07-20T17:01:00.000Z" },
    { id: "suivant", expectedAt: "2026-07-20T17:17:00.000Z" },
  ];

  assert.deepEqual(activeStopPassages(passages, now).map(({ id }) => id), ["suivant"]);
  assert.equal(stopPassageWaitMinutes(passages[1].expectedAt, now), 16);
  assert.equal(
    stopPassageWaitMinutes(passages[1].expectedAt, now + 60_000),
    15,
  );
});

test("le texte des badges reste lisible sur les couleurs de ligne", () => {
  assert.equal(lineBadgeTextColor("#009640"), "#ffffff");
  assert.equal(lineBadgeTextColor("#ffed00"), "#102018");
});

test("les horaires journaliers distinguent les passages échus du prochain", () => {
  const now = new Date("2026-07-20T19:02:00.000Z").getTime();
  const times = [
    { seconds: 20 * 3_600 + 58 * 60 },
    { seconds: 21 * 3_600 + 12 * 60 },
    { seconds: 21 * 3_600 + 27 * 60 },
  ];

  assert.equal(serviceDayElapsedSeconds("2026-07-20", now), 21 * 3_600 + 2 * 60);
  assert.equal(nextDayScheduleIndex(times, "2026-07-20", now), 1);
});

test("un passage après minuit reste rattaché au jour de service précédent", () => {
  const now = new Date("2026-07-20T22:20:00.000Z").getTime();
  const times = [
    { seconds: 23 * 3_600 + 58 * 60 },
    { seconds: 24 * 3_600 + 28 * 60 },
    { seconds: 24 * 3_600 + 58 * 60 },
  ];

  assert.equal(serviceDayElapsedSeconds("2026-07-20", now), 24 * 3_600 + 20 * 60);
  assert.equal(nextDayScheduleIndex(times, "2026-07-20", now), 1);
});

test("le suivi choisit le véhicule réel de la bonne ligne et direction", () => {
  const common = {
    type: "bus",
    mode: "live",
    heading: 0,
    speedMps: 5,
    recordedAt: "2026-07-20T19:10:00.000Z",
    routeId: "C6",
  };
  const vehicles = [
    {
      ...common,
      id: "hermeland",
      lat: 47.245,
      lng: -1.53,
      destination: "Hermeland",
    },
    {
      ...common,
      id: "chantrerie",
      lat: 47.246,
      lng: -1.531,
      destination: "Chantrerie - Grandes Écoles",
    },
  ];

  assert.equal(
    selectLiveVehicleForSchedule(vehicles, {
      line: "C6",
      routeId: "C6",
      direction: "Chantrerie / Grandes Ecoles",
      estimatedPosition: { lat: 47.2461, lng: -1.5311 },
    })?.id,
    "chantrerie",
  );
});

test("le suivi ne remplace pas une course par un véhicule de l'autre terminus", () => {
  const vehicle = {
    id: "beaujoire",
    type: "tram",
    mode: "live",
    heading: 0,
    speedMps: 5,
    recordedAt: "2026-07-21T12:30:00.000Z",
    routeId: "1",
    destination: "Beaujoire / Babinière",
    lat: 47.251,
    lng: -1.53,
  };

  assert.equal(
    selectLiveVehicleForSchedule([vehicle], {
      line: "1",
      routeId: "1",
      direction: "François Mitterrand / Jamet",
      estimatedPosition: { lat: 47.251, lng: -1.53 },
    }),
    null,
  );
});

test("le tracé PostGIS conserve les points de la branche sélectionnée", () => {
  assert.deepEqual(
    lineStringCoordinates({
      type: "LineString",
      coordinates: [[-1.52, 47.25], [-1.53, 47.24]],
    }),
    [[-1.52, 47.25], [-1.53, 47.24]],
  );
});

test("l'ombre du véhicule suit la lumière et la météo de la carte", () => {
  const day = getVehicleShadowStyle({ period: "day", condition: "clear" });
  const night = getVehicleShadowStyle({ period: "night", condition: "clear" });
  const fog = getVehicleShadowStyle({ period: "day", condition: "fog" });

  assert.equal(day.color, "#756d5a");
  assert.equal(night.color, "#071521");
  assert.ok(day.opacity < night.opacity);
  assert.ok(fog.opacity < day.opacity);
});

test("au plus deux variantes d'une même chaîne occupent la liste", () => {
  const requestedAt = new Date("2026-07-19T20:00:00.000Z");
  const ranked = rankTransitCandidates(
    [
      ...[0, 1, 2].map((index) => ({
        id: `c6-3-${index}`,
        duration: 3600 + index * 60,
        arrivalAt: new Date(requestedAt.getTime() + (3600 + index * 60) * 1000).toISOString(),
        transfers: 1,
        walkSeconds: 1200 - index * 60,
        routeIds: ["C6", "3"],
      })),
      {
        id: "1-c8",
        duration: 3900,
        arrivalAt: new Date(requestedAt.getTime() + 3900 * 1000).toISOString(),
        transfers: 1,
        walkSeconds: 600,
        routeIds: ["1", "C8"],
      },
    ],
    requestedAt,
    4,
  );
  assert.equal(ranked.filter(({ routeIds }) => routeIds?.join(">") === "C6>3").length, 2);
  assert.ok(ranked.some(({ id }) => id === "1-c8"));
});
