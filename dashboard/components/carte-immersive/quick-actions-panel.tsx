"use client";

type QuickActionsPanelProps = {
  visible: boolean;
  collapsed: boolean;
  onToggleCollapse: () => void;
  onRoute: () => void;
  onRide: () => void;
  onShop: () => void;
};

export function QuickActionsPanel({
  visible,
  collapsed,
  onToggleCollapse,
  onRoute,
  onRide,
  onShop,
}: QuickActionsPanelProps) {
  if (!visible) return null;

  return (
    <div
      className="immersive-map-panel immersive-map-panel-anim absolute left-5 top-[82px] z-[398] w-[280px] max-w-[calc(100vw-40px)] rounded-[22px] p-4"
    >
      <div className="mb-3 flex items-center justify-between" style={{ marginBottom: collapsed ? 0 : 12 }}>
        <div className="flex items-center gap-2 text-xs uppercase tracking-[0.12em] text-white/60">
          <span className="h-1.5 w-1.5 rounded-full bg-[#33bfa3]" />
          Actions rapides
        </div>
        <button
          type="button"
          onClick={onToggleCollapse}
          className="immersive-map-icon-btn"
          aria-label={collapsed ? "Déplier" : "Replier"}
        >
          {collapsed ? "⌃" : "⌄"}
        </button>
      </div>

      {!collapsed && (
        <div className="flex flex-col gap-2.5">
          <div onClick={onRoute} className="immersive-map-quick-card">
            <span className="inline-flex h-9 w-9 items-center justify-center rounded-[11px] border border-[#33bfa3]/30 bg-[#33bfa3]/[.14] text-lg">
              🧭
            </span>
            <div className="text-sm font-semibold leading-tight">
              Où allons-nous aujourd&apos;hui&nbsp;?
            </div>
            <div className="text-xs leading-snug text-white/60">
              Marche, transports, VTC &amp; taxi combinés en temps réel.
            </div>
          </div>
          <div onClick={onRide} className="immersive-map-quick-card">
            <span className="inline-flex h-9 w-9 items-center justify-center rounded-[11px] border border-[#33bfa3]/30 bg-[#33bfa3]/[.14] text-lg">
              🚖
            </span>
            <div className="text-sm font-semibold leading-tight">Réserver un VTC ou un taxi</div>
            <div className="text-xs leading-snug text-white/60">
              Chauffeurs disponibles autour de vous en quelques secondes.
            </div>
          </div>
          <div onClick={onShop} className="immersive-map-quick-card">
            <span className="inline-flex h-9 w-9 items-center justify-center rounded-[11px] border border-[#33bfa3]/30 bg-[#33bfa3]/[.14] text-lg">
              🛍️
            </span>
            <div className="text-sm font-semibold leading-tight">Commander à proximité</div>
            <div className="text-xs leading-snug text-white/60">
              Commerçants partenaires près de vous, livrés à votre arrêt.
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
