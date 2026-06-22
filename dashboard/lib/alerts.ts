import type { DriverSession, LiveFleetPosition, NetworkIncident, OperationalAlert } from "./types";

const DELAY_WARNING_SEC = 300; // 5 min
const DELAY_CRITICAL_SEC = 600; // 10 min
const GPS_STALE_SEC = 120;
const IMMOBILIZED_SPEED = 2;

export function computeOperationalAlerts(
  fleet: LiveFleetPosition[],
  incidents: NetworkIncident[],
  drivers: DriverSession[],
): OperationalAlert[] {
  const alerts: OperationalAlert[] = [];
  const now = Date.now();

  for (const v of fleet) {
    const delay = v.estimated_delay_seconds ?? 0;

    if (delay >= DELAY_CRITICAL_SEC) {
      alerts.push({
        id: `delay-critical-${v.id}`,
        type: "delay",
        severity: "critical",
        title: `Retard majeur — Ligne ${v.route_id}`,
        description: `Retard estimé de ${Math.round(delay / 60)} min`,
        route_id: v.route_id,
        vehicle_id: v.id,
        created_at: v.last_seen_at,
      });
    } else if (delay >= DELAY_WARNING_SEC) {
      alerts.push({
        id: `delay-warning-${v.id}`,
        type: "delay",
        severity: "warning",
        title: `Retard — Ligne ${v.route_id}`,
        description: `Retard estimé de ${Math.round(delay / 60)} min`,
        route_id: v.route_id,
        vehicle_id: v.id,
        created_at: v.last_seen_at,
      });
    }

    if (v.freshness_seconds >= GPS_STALE_SEC || v.reliability_score < 30) {
      alerts.push({
        id: `gps-${v.id}`,
        type: "gps_loss",
        severity: v.freshness_seconds >= 180 ? "critical" : "warning",
        title: `Signal GPS faible — Ligne ${v.route_id}`,
        description: `Dernière position il y a ${v.freshness_seconds}s (fiabilité ${v.reliability_score}%)`,
        route_id: v.route_id,
        vehicle_id: v.id,
        created_at: v.last_seen_at,
      });
    }

    if (
      v.speed != null &&
      v.speed <= IMMOBILIZED_SPEED &&
      v.freshness_seconds < 60
    ) {
      alerts.push({
        id: `immobile-${v.id}`,
        type: "immobilized",
        severity: "warning",
        title: `Immobilisation — Ligne ${v.route_id}`,
        description: `Vitesse ${Math.round(v.speed)} km/h, position récente`,
        route_id: v.route_id,
        vehicle_id: v.id,
        created_at: v.last_seen_at,
      });
    }

    if (v.coherence_score != null && v.coherence_score < 50) {
      alerts.push({
        id: `offroute-${v.id}`,
        type: "off_route",
        severity: "warning",
        title: `Cohérence faible — Ligne ${v.route_id}`,
        description: `Score de cohérence ${v.coherence_score}% — possible sortie d'itinéraire`,
        route_id: v.route_id,
        vehicle_id: v.id,
        created_at: v.last_seen_at,
      });
    }

    if (v.active_user_count != null && v.active_user_count >= 15) {
      alerts.push({
        id: `crowding-${v.id}`,
        type: "crowding",
        severity: v.active_user_count >= 25 ? "critical" : "warning",
        title: `Affluence — Ligne ${v.route_id}`,
        description: `${v.active_user_count} contributeurs actifs sur ce trajet`,
        route_id: v.route_id,
        vehicle_id: v.id,
        created_at: v.last_seen_at,
      });
    }
  }

  const fleetDriverSessions = new Set(
    fleet.filter((v) => v.driver_session_id).map((v) => v.driver_session_id),
  );

  for (const d of drivers) {
    if (d.status === "active" && !fleetDriverSessions.has(d.id)) {
      const elapsed = (now - new Date(d.started_at).getTime()) / 1000;
      if (elapsed > 120) {
        alerts.push({
          id: `driver-disconnect-${d.id}`,
          type: "driver_disconnect",
          severity: "warning",
          title: `Conducteur sans position — ${d.driver?.display_name ?? "Inconnu"}`,
          description: `Session active ligne ${d.route_id ?? "?"} sans remontée GPS`,
          route_id: d.route_id,
          created_at: d.started_at,
        });
      }
    }
  }

  for (const inc of incidents) {
    if (inc.severity === "critical" || inc.status === "open") {
      alerts.push({
        id: `incident-${inc.id}`,
        type: "incident",
        severity: inc.severity === "critical" ? "critical" : inc.severity === "warning" ? "warning" : "info",
        title: inc.title,
        description: inc.description ?? inc.incident_type,
        route_id: inc.route_id,
        incident_id: inc.id,
        created_at: inc.created_at,
      });
    }
  }

  const severityOrder = { critical: 0, warning: 1, info: 2 };
  return alerts.sort(
    (a, b) => severityOrder[a.severity] - severityOrder[b.severity],
  );
}

export function computePunctualityRate(fleet: LiveFleetPosition[]): number {
  if (fleet.length === 0) return 0;
  const onTime = fleet.filter(
    (v) => !v.estimated_delay_seconds || v.estimated_delay_seconds <= 60,
  ).length;
  return Math.round((onTime / fleet.length) * 100);
}

export function countActiveLines(fleet: LiveFleetPosition[]): number {
  return new Set(fleet.map((v) => v.route_id)).size;
}

export function sumActiveUsers(fleet: LiveFleetPosition[]): number {
  return fleet.reduce((acc, v) => acc + (v.active_user_count ?? 0), 0);
}
