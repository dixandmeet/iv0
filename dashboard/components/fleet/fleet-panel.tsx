import type { LiveFleetPosition } from "@/lib/types";
import { reliabilityColor, sourceLabel } from "@/lib/types";

interface FleetPanelProps {
  fleet: LiveFleetPosition[];
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}

export function FleetPanel({ fleet, selectedId, onSelect }: FleetPanelProps) {
  return (
    <section>
      <h2 style={{ margin: "0 0 12px", fontSize: 16 }}>Flotte live</h2>
      <p className="muted" style={{ margin: "0 0 12px" }}>
        {fleet.length} véhicule{fleet.length !== 1 ? "s" : ""}
      </p>
      {fleet.length === 0 && (
        <p className="muted">Aucune position — vérifiez les migrations Supabase.</p>
      )}
      {fleet.map((v) => (
        <button
          key={v.id}
          type="button"
          className="fleet-item"
          onClick={() => onSelect(v.id === selectedId ? null : v.id)}
          style={{
            width: "100%",
            textAlign: "left",
            cursor: "pointer",
            borderColor: v.id === selectedId ? "var(--accent)" : undefined,
            background: "transparent",
            color: "inherit",
          }}
        >
          <div style={{ display: "flex", justifyContent: "space-between" }}>
            <strong>Ligne {v.route_id}</strong>
            <span
              className="badge"
              style={{
                background: `${reliabilityColor(v.reliability_score)}22`,
                color: reliabilityColor(v.reliability_score),
              }}
            >
              {v.reliability_score}%
            </span>
          </div>
          <div className="muted" style={{ marginTop: 6 }}>
            {sourceLabel(v.source)} · {v.transport_type} · il y a {v.freshness_seconds}s
          </div>
        </button>
      ))}
    </section>
  );
}
