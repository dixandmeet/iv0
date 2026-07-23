type TrackingAnnouncement = {
  title: string;
  message: string;
  announcement_type:
    | "info"
    | "disruption"
    | "cancellation"
    | "deviation"
    | "delay";
  route_ids: string[];
  expires_at: string | null;
  is_active: boolean;
};

const PARIS_WEEKDAY_FORMATTER = new Intl.DateTimeFormat("en-US", {
  timeZone: "Europe/Paris",
  weekday: "short",
});

function normalizedReference(value: string): string {
  return value
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]/gi, "")
    .toUpperCase();
}

function disruptionLabel(
  announcement: TrackingAnnouncement,
): string | null {
  const copy = normalizedReference(
    `${announcement.title} ${announcement.message}`,
  );
  if (
    announcement.announcement_type === "cancellation" ||
    /COUP|INTERROMP|SUSPEND|ANNUL/.test(copy)
  ) {
    return "LIGNE COUPÉE";
  }
  if (
    announcement.announcement_type === "deviation" ||
    /DEVI/.test(copy)
  ) {
    return "LIGNE DÉVIÉE";
  }
  return announcement.announcement_type === "disruption"
    ? "LIGNE PERTURBÉE"
    : null;
}

function isFreeWeekend(now: Date): boolean {
  const weekday = PARIS_WEEKDAY_FORMATTER.format(now);
  return weekday === "Sat" || weekday === "Sun";
}

export function buildTrackingServiceMessage({
  announcements,
  lineReferences,
  now = new Date(),
}: {
  announcements: TrackingAnnouncement[];
  lineReferences: string[];
  now?: Date;
}): string | null {
  const references = new Set(
    lineReferences.map(normalizedReference).filter(Boolean),
  );
  const activeLabels = announcements
    .filter((announcement) => {
      if (!announcement.is_active) return false;
      if (
        announcement.expires_at &&
        new Date(announcement.expires_at).getTime() <= now.getTime()
      ) {
        return false;
      }
      return (
        announcement.route_ids.length === 0 ||
        announcement.route_ids.some((routeId) =>
          references.has(normalizedReference(routeId)),
        )
      );
    })
    .map(disruptionLabel)
    .filter((label): label is string => label != null);

  const disruption =
    activeLabels.includes("LIGNE COUPÉE")
      ? "LIGNE COUPÉE"
      : activeLabels.includes("LIGNE DÉVIÉE")
        ? "LIGNE DÉVIÉE"
        : activeLabels.includes("LIGNE PERTURBÉE")
          ? "LIGNE PERTURBÉE"
          : null;
  const messages = [
    disruption,
    isFreeWeekend(now) ? "GRATUIT CE WEEK-END" : null,
  ].filter((message): message is string => message != null);

  return messages.length ? messages.join(" · ") : null;
}
