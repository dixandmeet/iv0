"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { MessageSquare, Send, Users } from "lucide-react";
import { useMessagesData } from "@/hooks/use-messages-data";
import { useDriversData } from "@/hooks/use-drivers-data";
import { useGtfsData } from "@/hooks/use-gtfs-data";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label, Select } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { formatRelativeTime } from "@/lib/types";

export function CommunicationPageContent() {
  const searchParams = useSearchParams();
  const prefillDriver = searchParams.get("driver") ?? "";
  const prefillRoute = searchParams.get("route") ?? "";

  const { messages, loading, error, refresh, sendMessage } = useMessagesData();
  const { drivers } = useDriversData();
  const { routes } = useGtfsData();

  const [form, setForm] = useState({
    message_type: prefillDriver ? "direct" : prefillRoute ? "group" : "broadcast",
    recipient_id: prefillDriver,
    recipient_role: "",
    route_id: prefillRoute,
    subject: "",
    body: "",
  });
  const [sending, setSending] = useState(false);
  const [sendError, setSendError] = useState<string | null>(null);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.body.trim()) return;
    setSending(true);
    setSendError(null);
    try {
      await sendMessage({
        message_type: form.message_type as "direct" | "group" | "broadcast",
        recipient_id: form.message_type === "direct" ? form.recipient_id || null : null,
        recipient_role:
          form.message_type === "group" ? form.recipient_role || "driver" : null,
        route_id: form.route_id || null,
        subject: form.subject.trim() || undefined,
        body: form.body.trim(),
      });
      setForm((f) => ({ ...f, subject: "", body: "" }));
    } catch (err) {
      setSendError(err instanceof Error ? err.message : "Erreur envoi");
    }
    setSending(false);
  };

  return (
    <main
      className="dashboard-panel overflow-auto"
      style={{ gridColumn: "2 / -1", padding: 24 }}
    >
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <div className="mb-6">
        <h1 className="text-xl font-semibold">Centre de communication</h1>
        <p className="text-sm text-muted-foreground">
          Messages individuels, par ligne ou diffusion réseau.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="shadow-none">
          <CardContent className="p-4">
            <h2 className="mb-4 flex items-center gap-2 text-sm font-semibold">
              <Send className="h-4 w-4" />
              Nouveau message
            </h2>
            <form onSubmit={handleSend} className="space-y-3">
              <div className="space-y-1.5">
                <Label>Type</Label>
                <Select
                  value={form.message_type}
                  onChange={(e) =>
                    setForm((f) => ({ ...f, message_type: e.target.value }))
                  }
                >
                  <option value="direct">Message individuel</option>
                  <option value="group">Groupe (par rôle / ligne)</option>
                  <option value="broadcast">Diffusion réseau</option>
                </Select>
              </div>

              {form.message_type === "direct" && (
                <div className="space-y-1.5">
                  <Label>Conducteur</Label>
                  <Select
                    value={form.recipient_id}
                    onChange={(e) =>
                      setForm((f) => ({ ...f, recipient_id: e.target.value }))
                    }
                  >
                    <option value="">Sélectionner…</option>
                    {drivers.map((d) => (
                      <option key={d.driver_id} value={d.driver_id}>
                        {d.driver?.display_name ?? d.driver_id} — Ligne {d.route_id ?? "?"}
                      </option>
                    ))}
                  </Select>
                </div>
              )}

              {form.message_type === "group" && (
                <>
                  <div className="space-y-1.5">
                    <Label>Rôle cible</Label>
                    <Select
                      value={form.recipient_role}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, recipient_role: e.target.value }))
                      }
                    >
                      <option value="driver">Conducteurs</option>
                      <option value="msr_agent">Agents MSR</option>
                      <option value="msr_supervisor">Superviseurs MSR</option>
                    </Select>
                  </div>
                  <div className="space-y-1.5">
                    <Label>Ligne (optionnel)</Label>
                    <Select
                      value={form.route_id}
                      onChange={(e) =>
                        setForm((f) => ({ ...f, route_id: e.target.value }))
                      }
                    >
                      <option value="">Toutes lignes</option>
                      {routes.map((r) => (
                        <option key={r.route_id} value={r.route_id}>
                          {r.route_short_name ?? r.route_id}
                        </option>
                      ))}
                    </Select>
                  </div>
                </>
              )}

              <div className="space-y-1.5">
                <Label>Sujet</Label>
                <Input
                  value={form.subject}
                  onChange={(e) => setForm((f) => ({ ...f, subject: e.target.value }))}
                  placeholder="Optionnel"
                />
              </div>

              <div className="space-y-1.5">
                <Label>Message</Label>
                <Textarea
                  value={form.body}
                  onChange={(e) => setForm((f) => ({ ...f, body: e.target.value }))}
                  placeholder="Votre message…"
                  rows={4}
                  required
                />
              </div>

              {sendError && <p className="text-xs text-destructive">{sendError}</p>}

              <Button type="submit" disabled={sending || !form.body.trim()} className="w-full gap-2">
                <Send className="h-4 w-4" />
                {sending ? "Envoi…" : "Envoyer"}
              </Button>
            </form>
          </CardContent>
        </Card>

        <div>
          <h2 className="mb-3 flex items-center gap-2 text-sm font-semibold">
            <MessageSquare className="h-4 w-4" />
            Historique
            <Badge variant="secondary">{messages.length}</Badge>
          </h2>

          {loading ? (
            <ListSkeleton rows={4} />
          ) : messages.length === 0 ? (
            <EmptyState
              icon={Users}
              title="Aucun message"
              description="Les messages envoyés apparaîtront ici. Appliquez la migration 007 si la table n'existe pas encore."
            />
          ) : (
            <div className="space-y-2">
              {messages.map((msg) => (
                <Card key={msg.id} className="shadow-none">
                  <CardContent className="p-3">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <p className="text-sm font-medium">
                          {msg.subject ?? msg.message_type}
                        </p>
                        <p className="mt-1 text-sm text-muted-foreground">{msg.body}</p>
                        <p className="mt-2 text-xs text-muted-foreground">
                          {msg.sender?.display_name ?? "Staff"}
                          {msg.route_id ? ` · Ligne ${msg.route_id}` : ""}
                          {" · "}
                          {formatRelativeTime(msg.created_at)}
                        </p>
                      </div>
                      <Badge variant="outline" className="shrink-0 text-[10px]">
                        {msg.message_type}
                      </Badge>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
