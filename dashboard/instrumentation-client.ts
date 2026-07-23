type ClientErrorPayload = {
  type: "window-error" | "unhandled-rejection";
  message: string;
  path: string;
  stack?: string;
};

const sent = new Set<string>();

function report(payload: ClientErrorPayload) {
  const key = `${payload.type}:${payload.message}:${payload.path}`;
  if (sent.has(key) || sent.size >= 20) return;
  sent.add(key);

  const body = JSON.stringify(payload);
  if (navigator.sendBeacon) {
    navigator.sendBeacon("/api/client-errors", new Blob([body], { type: "application/json" }));
    return;
  }

  void fetch("/api/client-errors", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body,
    keepalive: true,
  }).catch(() => undefined);
}

window.addEventListener("error", (event) => {
  report({
    type: "window-error",
    message: event.message || "Erreur JavaScript inconnue",
    path: window.location.pathname,
    stack: event.error instanceof Error ? event.error.stack : undefined,
  });
});

window.addEventListener("unhandledrejection", (event) => {
  const reason = event.reason;
  report({
    type: "unhandled-rejection",
    message: reason instanceof Error ? reason.message : String(reason ?? "Promesse rejetée"),
    path: window.location.pathname,
    stack: reason instanceof Error ? reason.stack : undefined,
  });
});
