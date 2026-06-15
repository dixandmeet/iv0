import type { NetworkIncident } from "@/lib/types";

const SEVERITY_COLOR: Record<string, string> = {
  critical: "#dc2626",
  warning: "#ea580c",
  info: "#1b66f5",
};

interface IncidentsPanelProps {
  incidents: NetworkIncident[];
}

export function IncidentsPanel({ incidents }: IncidentsPanelProps) {
  return (
    <section style={{ marginTop: 24 }}>
      <h2 style={{ margin: "0 0 12px", fontSize: 16 }}>Incidents ouverts</h2>
      {incidents.length === 0 && (
        <p className="muted">Aucun incident en cours.</p>
      )}
      {incidents.map((inc) => (
        <div key={inc.id} className="incident-item">
          <div style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
            <strong>{inc.title}</strong>
            <span
              className="badge"
              style={{
                background: `${SEVERITY_COLOR[inc.severity] ?? "#666"}22`,
                color: SEVERITY_COLOR[inc.severity] ?? "#666",
              }}
            >
              {inc.severity}
            </span>
          </div>
          <div className="muted" style={{ marginTop: 6 }}>
            {inc.incident_type}
            {inc.route_id ? ` · Ligne ${inc.route_id}` : ""}
          </div>
        </div>
      ))}
    </section>
  );
}
