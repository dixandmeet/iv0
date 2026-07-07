import type { VehicleDef } from "@/lib/carte-immersive/data";

function elFromHTML(html: string): HTMLDivElement {
  const el = document.createElement("div");
  el.className = "immersive-map-marker";
  el.innerHTML = html;
  return el;
}

function dotHTML(bg: string, glyph: string, size: number, radius: string, fontSize: number) {
  return `<div class="immersive-map-marker-dot" style="width:${size}px;height:${size}px;border-radius:${radius};background:${bg};font-size:${fontSize}px;">${glyph}</div>`;
}

export function createVehicleElement(vehicle: VehicleDef, onClick: () => void) {
  const html =
    vehicle.type === "bus"
      ? dotHTML("#2b3a36", "🚌", 28, "50%", 14)
      : vehicle.type === "tram"
        ? dotHTML("#17a08a", "🚋", 32, "50%", 16)
        : vehicle.type === "vtc"
          ? dotHTML("#0d0d0d", "🚖", 26, "40% 40% 40% 8px", 13)
          : dotHTML("#f2a93b", "🚕", 26, "40% 40% 40% 8px", 13);
  const el = elFromHTML(html);
  el.addEventListener("click", (ev) => {
    ev.stopPropagation();
    onClick();
  });
  return el;
}

export function createShopElement(emoji: string, onClick: () => void) {
  const el = elFromHTML(`<div class="immersive-map-marker-shop">${emoji}</div>`);
  el.addEventListener("click", (ev) => {
    ev.stopPropagation();
    onClick();
  });
  return el;
}

export function createUserElement() {
  const el = elFromHTML(
    '<div class="immersive-map-marker-user"><div class="immersive-map-marker-user-halo"></div><div class="immersive-map-marker-user-dot"></div></div>',
  );
  el.style.cursor = "default";
  return el;
}

export function createDestElement() {
  const el = elFromHTML('<div class="immersive-map-marker-dest"></div>');
  el.style.cursor = "default";
  return el;
}
