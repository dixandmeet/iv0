"use client";

export type FilterKey = "bus" | "tram" | "vtc" | "taxi" | "shop";

const FILTERS: { key: FilterKey; emoji: string; label: string }[] = [
  { key: "bus", label: "Bus", emoji: "🚌" },
  { key: "tram", label: "Tram", emoji: "🚋" },
  { key: "vtc", label: "VTC", emoji: "🚖" },
  { key: "taxi", label: "Taxi", emoji: "🚕" },
  { key: "shop", label: "Commerçants", emoji: "🛍️" },
];

type FiltersPanelProps = {
  filters: Record<FilterKey, boolean>;
  onToggle: (key: FilterKey) => void;
};

export function FiltersPanel({ filters, onToggle }: FiltersPanelProps) {
  return (
    <div className="immersive-map-panel immersive-map-panel-anim absolute right-5 top-32 z-[399] w-[190px] rounded-2xl p-4">
      <div className="mb-2.5 text-xs uppercase tracking-[0.1em] text-white/50">Afficher</div>
      {FILTERS.map((f) => (
        <label key={f.key} className="flex cursor-pointer items-center gap-2.5 py-1.5 text-sm text-white/90">
          <input
            type="checkbox"
            checked={filters[f.key]}
            onChange={() => onToggle(f.key)}
            className="h-4 w-4 accent-[#33bfa3]"
          />
          <span>{f.emoji}</span>
          <span>{f.label}</span>
        </label>
      ))}
    </div>
  );
}
