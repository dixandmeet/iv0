import assert from "node:assert/strict";
import test from "node:test";

import { buildTrackingServiceMessage } from "../lib/carte-immersive/tracking-service-message.ts";

const baseAnnouncement = {
  title: "Information ligne",
  message: "",
  announcement_type: "info",
  route_ids: ["C6"],
  expires_at: null,
  is_active: true,
};

test("affiche une déviation active pour la ligne suivie", () => {
  assert.equal(
    buildTrackingServiceMessage({
      announcements: [
        { ...baseAnnouncement, announcement_type: "deviation" },
      ],
      lineReferences: ["C6"],
      now: new Date("2026-07-24T12:00:00Z"),
    }),
    "LIGNE DÉVIÉE",
  );
});

test("priorise une coupure et ajoute la gratuité le week-end", () => {
  assert.equal(
    buildTrackingServiceMessage({
      announcements: [
        {
          ...baseAnnouncement,
          title: "Service interrompu",
          announcement_type: "disruption",
        },
      ],
      lineReferences: ["C6"],
      now: new Date("2026-07-25T12:00:00Z"),
    }),
    "LIGNE COUPÉE · GRATUIT CE WEEK-END",
  );
});

test("ignore les annonces d'une autre ligne et les annonces expirées", () => {
  assert.equal(
    buildTrackingServiceMessage({
      announcements: [
        { ...baseAnnouncement, route_ids: ["C1"], announcement_type: "deviation" },
        {
          ...baseAnnouncement,
          announcement_type: "cancellation",
          expires_at: "2026-07-23T12:00:00Z",
        },
      ],
      lineReferences: ["C6"],
      now: new Date("2026-07-24T12:00:00Z"),
    }),
    null,
  );
});
