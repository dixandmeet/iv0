"use client";

import { useState } from "react";
import { useHubData, useResourceShell, sendChannelMessage } from "@/hooks/use-hub-data";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { ListSkeleton } from "@/components/ui/empty-state";

const SUPPORT_RESOURCE_ID = "00000000-0000-4000-8000-000000000101";

/** Navigation → Resource → Workspace (Notion/Linear). */
export function WorkspacePageContent() {
  const [selectedResourceId, setSelectedResourceId] = useState<string | null>(SUPPORT_RESOURCE_ID);
  const [activePanel, setActivePanel] = useState("discussion");
  const [message, setMessage] = useState("");

  const { data: navItems, loading: navLoading, error: navError, refresh } =
    useHubData("discussions");
  const { shell, loading: shellLoading } = useResourceShell(selectedResourceId);

  const resource = shell?.resource as Record<string, unknown> | undefined;
  const channelId = shell?.channel_id as string | undefined;
  const layout = (shell?.panel_layout as Array<{ panel: string; visible: boolean }>) ?? [
    { panel: "discussion", visible: true },
    { panel: "timeline", visible: true },
  ];

  const handleSend = async () => {
    if (!channelId || !message.trim()) return;
    await sendChannelMessage(channelId, message.trim());
    setMessage("");
  };

  return (
    <main
      className="dashboard-main-column dashboard-panel overflow-hidden flex flex-col"
      style={{ padding: 0, height: "100%" }}
    >
      {navError && <ErrorBanner message={navError} onRetry={refresh} />}

      <div className="flex flex-1 min-h-0">
        {/* Navigation — arborescence ressources */}
        <aside className="w-64 border-r bg-muted/30 overflow-auto p-3">
          <p className="text-xs font-semibold text-muted-foreground mb-2">Navigation</p>
          {navLoading ? (
            <ListSkeleton rows={6} />
          ) : (
            <ul className="space-y-1">
              <li>
                <button
                  type="button"
                  className={`w-full text-left px-2 py-1.5 rounded text-sm ${
                    selectedResourceId === SUPPORT_RESOURCE_ID ? "bg-primary/10 font-medium" : ""
                  }`}
                  onClick={() => setSelectedResourceId(SUPPORT_RESOURCE_ID)}
                >
                  Support Aule
                </button>
              </li>
              {(navItems as Array<Record<string, unknown>>).map((item) => (
                <li key={String(item.id)}>
                  <button
                    type="button"
                    className={`w-full text-left px-2 py-1.5 rounded text-sm ${
                      selectedResourceId === item.id ? "bg-primary/10 font-medium" : ""
                    }`}
                    onClick={() => setSelectedResourceId(String(item.id))}
                  >
                    {String(item.name ?? "Ressource")}
                  </button>
                </li>
              ))}
            </ul>
          )}
        </aside>

        {/* Resource header */}
        <section className="flex-1 flex flex-col min-w-0">
          <header className="border-b px-4 py-3">
            {shellLoading ? (
              <p className="text-sm text-muted-foreground">Chargement…</p>
            ) : (
              <>
                <h1 className="text-lg font-semibold">{String(resource?.name ?? "Ressource")}</h1>
                <p className="text-sm text-muted-foreground">
                  {String(resource?.type ?? "")} · {String(resource?.status ?? "")}
                </p>
              </>
            )}
          </header>

          {/* Workspace panels */}
          <div className="border-b px-4 flex gap-2 py-2">
            {layout
              .filter((p) => p.visible)
              .map((p) => (
                <Button
                  key={p.panel}
                  size="sm"
                  variant={activePanel === p.panel ? "default" : "outline"}
                  onClick={() => setActivePanel(p.panel)}
                >
                  {p.panel}
                </Button>
              ))}
          </div>

          <div className="flex-1 overflow-auto p-4">
            {activePanel === "discussion" && (
              <Card>
                <CardContent className="p-4 space-y-3">
                  <p className="text-sm text-muted-foreground">
                    Fil de discussion — canal {channelId?.slice(0, 8) ?? "…"}
                  </p>
                  <div className="flex gap-2">
                    <Input
                      value={message}
                      onChange={(e) => setMessage(e.target.value)}
                      placeholder="Message…"
                      onKeyDown={(e) => e.key === "Enter" && void handleSend()}
                    />
                    <Button onClick={() => void handleSend()} disabled={!channelId}>
                      Envoyer
                    </Button>
                  </div>
                </CardContent>
              </Card>
            )}
            {activePanel === "timeline" && (
              <p className="text-sm text-muted-foreground">Chronologie des événements ressource</p>
            )}
            {activePanel !== "discussion" && activePanel !== "timeline" && (
              <p className="text-sm text-muted-foreground">Panel « {activePanel} »</p>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}
