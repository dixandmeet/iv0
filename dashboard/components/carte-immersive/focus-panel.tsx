"use client";

import { cn } from "@/lib/utils";
import type { Category } from "@/lib/carte-immersive/data";

export type RideItem = {
  id: string;
  emoji: string;
  title: string;
  meta: string;
  btn: string;
  onClick: () => void;
};

export type ShopResultItem = {
  id: string;
  emoji: string;
  title: string;
  cat: string;
  dist: string;
  walk: string;
  delivery: string;
  rating: string;
  price: string;
  openLabel: string;
  openColor: string;
  onClick: () => void;
  onEnter: () => void;
  onLeave: () => void;
};

export const SORT_OPTIONS = [
  { key: "distance", label: "📍 Les plus proches" },
  { key: "rating", label: "⭐ Les mieux notés" },
  { key: "delivery", label: "🚴 Temps de livraison" },
  { key: "price", label: "💰 Prix" },
  { key: "popularity", label: "🔥 Les plus populaires" },
  { key: "open", label: "🟢 Ouverts actuellement" },
] as const;

export type SortMode = (typeof SORT_OPTIONS)[number]["key"];

type FocusPanelProps = {
  mode: "ride" | "shop";
  title: string;
  onClose: () => void;
  rideItems: RideItem[];
  shopQuery: string;
  onShopQueryChange: (value: string) => void;
  categories: Category[];
  activeCats: Record<string, boolean>;
  onToggleCat: (key: string) => void;
  sortMode: SortMode;
  onSortChange: (mode: SortMode) => void;
  showSearchArea: boolean;
  onSearchThisArea: () => void;
  shopResults: ShopResultItem[];
};

export function FocusPanel({
  mode,
  title,
  onClose,
  rideItems,
  shopQuery,
  onShopQueryChange,
  categories,
  activeCats,
  onToggleCat,
  sortMode,
  onSortChange,
  showSearchArea,
  onSearchThisArea,
  shopResults,
}: FocusPanelProps) {
  const isShop = mode === "shop";

  return (
    <>
      {showSearchArea && (
        <button
          type="button"
          onClick={onSearchThisArea}
          className="immersive-map-toast absolute left-1/2 top-[172px] z-[398] -translate-x-1/2 rounded-full border-none bg-white px-5 py-2.5 font-semibold text-[#0a1614] shadow-[0_14px_30px_rgba(0,0,0,0.35)]"
        >
          🔄 Rechercher dans cette zone
        </button>
      )}

      <div
        className="immersive-map-panel immersive-map-panel-anim absolute bottom-6 left-5 z-[399] max-h-[62vh] overflow-y-auto rounded-[22px] p-5"
        style={{ width: isShop ? 360 : 320 }}
      >
        <div className="mb-3 flex items-center justify-between">
          <div className="text-[15px] font-semibold">{title}</div>
          <button type="button" onClick={onClose} className="immersive-map-icon-btn" aria-label="Fermer">
            ×
          </button>
        </div>

        {isShop && (
          <>
            <input
              value={shopQuery}
              onChange={(e) => onShopQueryChange(e.target.value)}
              placeholder="Rechercher un commerce (nom, cuisine...)"
              className="mb-2.5 w-full rounded-xl border border-white/[.14] bg-white/[.06] px-3 py-2.5 text-[13.5px] text-white outline-none"
            />
            <div className="mb-1 flex gap-1.5 overflow-x-auto pb-2">
              {categories.map((chip) => (
                <button
                  key={chip.key}
                  type="button"
                  onClick={() => onToggleCat(chip.key)}
                  className={cn("immersive-map-chip", activeCats[chip.key] && "immersive-map-chip--active")}
                >
                  <span>{chip.emoji}</span>
                  <span>{chip.label}</span>
                </button>
              ))}
            </div>
            <select
              value={sortMode}
              onChange={(e) => onSortChange(e.target.value as SortMode)}
              className="mb-3 w-full rounded-xl border border-white/[.14] bg-[#0e1614] px-2.5 py-2 text-[13px] text-white"
            >
              {SORT_OPTIONS.map((opt) => (
                <option key={opt.key} value={opt.key}>
                  {opt.label}
                </option>
              ))}
            </select>
          </>
        )}

        {!isShop &&
          rideItems.map((item) => (
            <div key={item.id} className="flex items-center gap-3 border-t border-white/[.08] py-2.5">
              <span className="flex h-[38px] w-[38px] flex-none items-center justify-center rounded-xl bg-white/[.06] text-lg">
                {item.emoji}
              </span>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-semibold">{item.title}</div>
                <div className="text-xs text-white/55">{item.meta}</div>
              </div>
              <button type="button" onClick={item.onClick} className="immersive-map-add-btn">
                {item.btn}
              </button>
            </div>
          ))}

        {isShop &&
          shopResults.map((item) => (
            <div
              key={item.id}
              onMouseEnter={item.onEnter}
              onMouseLeave={item.onLeave}
              className="border-t border-white/[.08] py-2.5"
            >
              <div className="flex items-center gap-3">
                <span className="flex h-[38px] w-[38px] flex-none items-center justify-center rounded-xl bg-white/[.06] text-lg">
                  {item.emoji}
                </span>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-sm font-semibold">{item.title}</div>
                </div>
                <button type="button" onClick={item.onClick} className="immersive-map-add-btn">
                  Commander
                </button>
              </div>
              <div className="ml-[50px] mt-2 flex flex-wrap items-center gap-2 text-[11.5px] text-white/55">
                <span>{item.cat}</span>
                <span>· {item.dist}</span>
                <span>· {item.walk} à pied</span>
                <span>· 🚴 {item.delivery}</span>
                <span>· ★ {item.rating}</span>
                <span>· {item.price}</span>
                <span style={{ color: item.openColor, fontWeight: 600 }}>· {item.openLabel}</span>
              </div>
            </div>
          ))}

        {isShop && shopResults.length === 0 && (
          <div className="py-6 text-center text-[13px] text-white/50">
            Aucun commerce ne correspond à cette recherche.
          </div>
        )}
      </div>
    </>
  );
}
