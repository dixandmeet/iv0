"use client";

import { cn } from "@/lib/utils";
import type { BuiltMenuSection } from "@/lib/carte-immersive/data";

export type MerchantInfo = {
  emoji: string;
  name: string;
  cat: string;
  openLabel: string;
  open: boolean;
  facts: { icon: string; v: string }[];
};

export type MenuChip = { key: string; label: string; active: boolean };

export type CartLine = { id: string; name: string; qty: number; lineTotal: string };

type MerchantSheetProps = {
  merchant: MerchantInfo;
  menuChips: MenuChip[];
  onPickMenuChip: (key: string) => void;
  menuSections: BuiltMenuSection[];
  cart: Record<string, number>;
  onAddItem: (id: string) => void;
  onDecItem: (id: string) => void;
  fmt: (n: number) => string;
  cartLines: CartLine[];
  cartCount: number;
  cartTotalLabel: string;
  cartExpanded: boolean;
  onToggleCart: () => void;
  onClose: () => void;
  onOrder: () => void;
  orderConfirmVisible: boolean;
};

export function MerchantSheet({
  merchant,
  menuChips,
  onPickMenuChip,
  menuSections,
  cart,
  onAddItem,
  onDecItem,
  fmt,
  cartLines,
  cartCount,
  cartTotalLabel,
  cartExpanded,
  onToggleCart,
  onClose,
  onOrder,
  orderConfirmVisible,
}: MerchantSheetProps) {
  const canOrder = cartCount > 0;

  return (
    <>
      <div className="immersive-map-backdrop" onClick={onClose} />
      <div className="immersive-map-sheet">
        {orderConfirmVisible && (
          <div className="immersive-map-order-confirm">
            <div className="flex h-[76px] w-[76px] items-center justify-center rounded-full border border-[#33bfa3]/40 bg-[#33bfa3]/[.16] text-[34px] text-[#33bfa3]">
              ✓
            </div>
            <div className="text-[19px] font-bold">Commande envoyée</div>
            <div className="max-w-[300px] text-sm text-white/60">
              {merchant.name} prépare votre commande. Elle sera livrée à votre arrêt.
            </div>
          </div>
        )}

        {/* Hero */}
        <div className="relative h-[176px] flex-none overflow-hidden">
          <div className="immersive-map-sheet-hero" />
          <div className="absolute inset-0 flex items-center justify-center font-mono text-[11px] uppercase tracking-[0.18em] text-white/[.28]">
            photo du commerce
          </div>
          <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(5,8,7,0.1)_0%,rgba(5,8,7,0.35)_45%,rgba(9,14,12,0.94)_100%)]" />
          <button
            type="button"
            onClick={onClose}
            className="immersive-map-round-btn absolute left-4 top-4 z-[2] h-10 w-10 text-lg"
          >
            ←
          </button>
          <div className="absolute bottom-4 left-5 right-5 z-[2] flex items-end gap-3.5">
            <span className="immersive-map-sheet-icon">{merchant.emoji}</span>
            <div className="min-w-0 flex-1 pb-0.5">
              <div className="flex flex-wrap items-center gap-2">
                <div className="text-[23px] font-bold leading-tight">{merchant.name}</div>
                <span
                  className="rounded-full border px-2.5 py-0.5 text-[11px] font-bold"
                  style={{
                    background: merchant.open ? "rgba(51,191,163,0.2)" : "rgba(255,107,94,0.2)",
                    color: merchant.open ? "#5fe0c4" : "#FF8B7E",
                    borderColor: merchant.open ? "rgba(51,191,163,0.4)" : "rgba(255,107,94,0.4)",
                  }}
                >
                  {merchant.openLabel}
                </span>
              </div>
              <div className="mt-0.5 text-[13.5px] text-white/65">{merchant.cat}</div>
            </div>
          </div>
        </div>

        {/* Faits */}
        <div className="flex flex-none flex-wrap gap-2 border-b border-white/[.08] px-5 py-3.5">
          {merchant.facts.map((fact, i) => (
            <div key={i} className="flex items-center gap-1.5 rounded-full bg-white/5 px-[11px] py-1.5 text-[12.5px] text-white/[.82]">
              <span className="text-[#33bfa3]">{fact.icon}</span>
              <span>{fact.v}</span>
            </div>
          ))}
        </div>

        {/* Catégories */}
        <div className="flex flex-none gap-2 overflow-x-auto px-5 pb-2 pt-3">
          {menuChips.map((chip) => (
            <button
              key={chip.key}
              type="button"
              onClick={() => onPickMenuChip(chip.key)}
              className={cn(
                "flex-none whitespace-nowrap rounded-full border px-3.5 py-2 text-[12.5px] font-semibold transition-colors",
                chip.active
                  ? "border-[#33bfa3] bg-[#33bfa3] text-[#04211c]"
                  : "border-white/[.16] bg-white/[.06] text-white/[.85]",
              )}
            >
              {chip.label}
            </button>
          ))}
        </div>

        {/* Articles */}
        <div className="flex-1 overflow-y-auto px-5 pb-[22px] pt-1">
          {menuSections.map((sec) => (
            <div key={sec.name} className="mt-3.5">
              <div className="mb-1 text-xs uppercase tracking-[0.12em] text-white/50">{sec.name}</div>
              {sec.items.map((it) => {
                const qty = cart[it.id] || 0;
                return (
                  <div key={it.id} className="flex items-center gap-3.5 border-t border-white/[.07] py-3.5">
                    <div className="min-w-0 flex-1">
                      <div className="text-[14.5px] font-semibold">{it.name}</div>
                      {it.desc && (
                        <div className="mt-0.5 text-[12.5px] leading-snug text-white/50">{it.desc}</div>
                      )}
                      <div className="mt-1.5 text-[13.5px] font-semibold text-[#33bfa3]">{fmt(it.price)}</div>
                    </div>
                    {qty > 0 ? (
                      <div className="flex flex-none items-center gap-1 rounded-full border border-white/[.14] bg-white/[.06] p-1">
                        <button
                          type="button"
                          onClick={() => onDecItem(it.id)}
                          className="flex h-[30px] w-[30px] items-center justify-center rounded-full border-none bg-white/[.08] text-lg text-white"
                        >
                          −
                        </button>
                        <span className="min-w-5 text-center text-sm font-bold">{qty}</span>
                        <button
                          type="button"
                          onClick={() => onAddItem(it.id)}
                          className="flex h-[30px] w-[30px] items-center justify-center rounded-full border-none bg-[#33bfa3] text-lg text-[#04211c]"
                        >
                          +
                        </button>
                      </div>
                    ) : (
                      <button type="button" onClick={() => onAddItem(it.id)} className="immersive-map-add-btn">
                        ＋ Ajouter
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          ))}
        </div>

        {/* Panier */}
        <div className="flex-none border-t border-white/10 bg-[rgba(6,10,9,0.55)]">
          {cartExpanded && (
            <div className="max-h-[30vh] overflow-y-auto px-5 pt-3">
              {cartLines.map((line) => (
                <div key={line.id} className="flex items-center gap-3 border-t border-white/[.06] py-2">
                  <span className="min-w-[26px] text-[13px] font-bold text-[#33bfa3]">{line.qty}×</span>
                  <div className="min-w-0 flex-1 truncate text-[13.5px]">{line.name}</div>
                  <div className="min-w-[62px] text-right text-[13px] text-white/[.85]">{line.lineTotal}</div>
                  <button
                    type="button"
                    onClick={() => onDecItem(line.id)}
                    className="h-[26px] w-[26px] flex-none rounded-full border-none bg-white/[.08] text-base text-white"
                  >
                    −
                  </button>
                  <button
                    type="button"
                    onClick={() => onAddItem(line.id)}
                    className="h-[26px] w-[26px] flex-none rounded-full border-none bg-[rgba(51,191,163,0.9)] text-base text-[#04211c]"
                  >
                    +
                  </button>
                </div>
              ))}
            </div>
          )}
          <div className="flex items-center gap-3 px-5 py-3.5">
            <button
              type="button"
              onClick={onToggleCart}
              className="flex flex-1 items-center justify-between gap-2.5 rounded-2xl border border-white/[.12] bg-white/5 px-3.5 py-2.5 text-white"
            >
              <span className="flex items-center gap-2.5 text-[13.5px]">
                <span className="inline-flex h-6 min-w-6 items-center justify-center rounded-full bg-[#33bfa3] px-1.5 text-xs font-bold text-[#04211c]">
                  🛒 {cartCount}
                </span>
                <span className="text-white/80">Panier</span>
              </span>
              <span className="text-[15px] font-bold">{cartTotalLabel}</span>
            </button>
            <button
              type="button"
              onClick={onOrder}
              disabled={!canOrder}
              className="flex-none rounded-2xl border-none px-[22px] py-3.5 text-[14.5px] font-bold"
              style={{
                background: canOrder ? "#33bfa3" : "rgba(255,255,255,0.1)",
                color: canOrder ? "#04211c" : "rgba(255,255,255,0.35)",
                cursor: canOrder ? "pointer" : "not-allowed",
              }}
            >
              Commander
            </button>
          </div>
        </div>
      </div>
    </>
  );
}
