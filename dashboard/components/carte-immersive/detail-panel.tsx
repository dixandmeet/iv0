"use client";

export type DetailFact = { k: string; v: string };

export type SelectedDetail = {
  emoji: string;
  title: string;
  subtitle: string;
  facts: DetailFact[];
  actionLabel: string;
  action: () => void;
};

type DetailPanelProps = {
  selected: SelectedDetail;
  onClose: () => void;
};

export function DetailPanel({ selected, onClose }: DetailPanelProps) {
  return (
    <div className="immersive-map-panel immersive-map-panel-anim absolute bottom-6 right-5 z-[399] w-80 rounded-[22px] p-[22px]">
      <div className="mb-3.5 flex items-start justify-between">
        <div className="flex items-center gap-2.5">
          <span className="flex h-[42px] w-[42px] flex-none items-center justify-center rounded-2xl border border-[#33bfa3]/30 bg-[#33bfa3]/[.14] text-xl">
            {selected.emoji}
          </span>
          <div>
            <div className="text-base font-semibold">{selected.title}</div>
            <div className="text-[13px] text-white/55">{selected.subtitle}</div>
          </div>
        </div>
        <button
          type="button"
          onClick={onClose}
          className="immersive-map-icon-btn flex-none"
          aria-label="Fermer"
        >
          ×
        </button>
      </div>
      <div className="mb-4 grid grid-cols-2 gap-2.5">
        {selected.facts.map((fact, i) => (
          <div key={i} className="rounded-xl bg-white/5 px-3 py-2.5">
            <div className="mb-0.5 text-[11.5px] text-white/50">{fact.k}</div>
            <div className="text-[14.5px] font-semibold">{fact.v}</div>
          </div>
        ))}
      </div>
      <button
        type="button"
        onClick={selected.action}
        className="w-full rounded-2xl border-none bg-[#33bfa3] py-3.5 text-[14.5px] font-bold text-[#04211c]"
      >
        {selected.actionLabel}
      </button>
    </div>
  );
}
