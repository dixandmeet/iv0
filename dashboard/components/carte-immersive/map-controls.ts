import type maplibregl from "maplibre-gl";

export function createOrbitControl(
  onRotateLeft: () => void,
  onRotateRight: () => void,
): maplibregl.IControl {
  let container: HTMLDivElement | null = null;
  let leftButton: HTMLButtonElement | null = null;
  let rightButton: HTMLButtonElement | null = null;

  return {
    onAdd() {
      container = document.createElement("div");
      container.className =
        "maplibregl-ctrl maplibregl-ctrl-group immersive-map-orbit-step-group";

      leftButton = document.createElement("button");
      leftButton.type = "button";
      leftButton.className = "immersive-map-orbit-step-control";
      leftButton.title = "Tourner de 30° vers la gauche";
      leftButton.setAttribute("aria-label", "Tourner la carte de 30° vers la gauche");
      leftButton.textContent = "↺";
      leftButton.addEventListener("click", onRotateLeft);

      rightButton = document.createElement("button");
      rightButton.type = "button";
      rightButton.className = "immersive-map-orbit-step-control";
      rightButton.title = "Tourner de 30° vers la droite";
      rightButton.setAttribute("aria-label", "Tourner la carte de 30° vers la droite");
      rightButton.textContent = "↻";
      rightButton.addEventListener("click", onRotateRight);

      container.append(leftButton, rightButton);

      return container;
    },
    onRemove() {
      leftButton?.removeEventListener("click", onRotateLeft);
      rightButton?.removeEventListener("click", onRotateRight);
      container?.remove();
      leftButton = null;
      rightButton = null;
      container = null;
    },
  };
}

export function createViewControl(
  onToggleView: () => void,
  onButtonReady: (button: HTMLButtonElement | null) => void,
): maplibregl.IControl {
  let container: HTMLDivElement | null = null;
  let button: HTMLButtonElement | null = null;

  return {
    onAdd() {
      container = document.createElement("div");
      container.className = "maplibregl-ctrl maplibregl-ctrl-group";

      button = document.createElement("button");
      button.type = "button";
      button.className = "immersive-map-view-control";
      button.title = "Passer en vue 2D";
      button.setAttribute("aria-label", "Passer en vue 2D");
      button.setAttribute("aria-pressed", "true");

      const icon = document.createElement("span");
      icon.className = "immersive-map-view-control-icon";
      icon.textContent = "3D";
      icon.setAttribute("aria-hidden", "true");
      button.appendChild(icon);
      button.addEventListener("click", onToggleView);
      container.appendChild(button);
      onButtonReady(button);

      return container;
    },
    onRemove() {
      button?.removeEventListener("click", onToggleView);
      onButtonReady(null);
      container?.remove();
      button = null;
      container = null;
    },
  };
}
