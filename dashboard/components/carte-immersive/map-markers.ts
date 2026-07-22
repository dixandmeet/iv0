function elFromHTML(html: string): HTMLDivElement {
  const el = document.createElement("div");
  el.className = "immersive-map-marker";
  el.innerHTML = html;
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
