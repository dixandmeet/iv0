"use client";

export type FilterKey = "bus" | "tram" | "vtc" | "taxi" | "shop";

const FILTERS: { key: FilterKey; emoji: string; label: string }[] = [
  { key: "bus", label: "Bus", emoji: "🚌" },
  { key: "tram", label: "Tram", emoji: "🚋" },
];

type FiltersPanelProps = {
  filters: Record<FilterKey, boolean>;
  onToggle: (key: FilterKey) => void;
  mobileOpen?: boolean;
};

export function FiltersPanel({ filters, onToggle, mobileOpen = false }: FiltersPanelProps) {
  return (
    <div
      className={`immersive-map-panel immersive-map-panel-anim immersive-map-filters-panel absolute right-5 top-32 z-[399] w-[190px] rounded-2xl p-4${
        mobileOpen ? " immersive-map-filters-panel--open" : ""
      }`}
    >
      <div className="mb-2.5 text-xs uppercase tracking-[0.1em] text-white/50">Afficher</div>
      <div className="immersive-map-filters-list">
        {FILTERS.map((filter) => (
          <label key={filter.key} className="flex cursor-pointer items-center gap-2.5 py-1.5 text-sm text-white/90">
            <input
              type="checkbox"
              checked={filters[filter.key]}
              onChange={() => onToggle(filter.key)}
              className="h-4 w-4 accent-[#33bfa3]"
            />
            <span>{filter.emoji}</span>
            <span>{filter.label}</span>
          </label>
        ))}
        <div className="flex items-center gap-2.5 py-1.5 text-sm text-white/90">
          <input
            type="checkbox"
            checked
            readOnly
            className="h-4 w-4 accent-[#33bfa3]"
            aria-label="Navibus affiché"
          />
          <span>⛴️</span>
          <span>Navibus</span>
        </div>
      </div>
    </div>
  );
}
