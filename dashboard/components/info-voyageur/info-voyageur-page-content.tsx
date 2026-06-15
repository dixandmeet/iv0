"use client";

import { useState } from "react";
import { useSearchParams } from "next/navigation";
import { Megaphone, Trash2 } from "lucide-react";
import { useAnnouncementsData } from "@/hooks/use-announcements-data";
import { useGtfsData } from "@/hooks/use-gtfs-data";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label, Select } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import {
  announcementTypeLabel,
  formatRelativeTime,
  severityColor,
  severityLabel,
} from "@/lib/types";
import type { PassengerAnnouncement } from "@/lib/types";

export function InfoVoyageurPageContent() {
  const searchParams = useSearchParams();
  const prefillRoute = searchParams.get("route") ?? "";
  const prefillType = searchParams.get("type") ?? "info";
  const prefillIncident = searchParams.get("incident") ?? "";

  const {
    announcements,
    loading,
    error,
    refresh,
    publishAnnouncement,
    deactivateAnnouncement,
  } = useAnnouncementsData();
  const { routes } = useGtfsData();

  const [form, setForm] = useState({
    title: "",
    message: "",
    announcement_type: prefillType as PassengerAnnouncement["announcement_type"],
    route_ids: prefillRoute ? [prefillRoute] : [] as string[],
    severity: "warning" as PassengerAnnouncement["severity"],
    incident_id: prefillIncident || null,
  });
  const [selectedRoute, setSelectedRoute] = useState("");
  const [publishing, setPublishing] = useState(false);
  const [publishError, setPublishError] = useState<string | null>(null);

  const addRoute = () => {
    if (!selectedRoute || form.route_ids.includes(selectedRoute)) return;
    setForm((f) => ({ ...f, route_ids: [...f.route_ids, selectedRoute] }));
    setSelectedRoute("");
  };

  const handlePublish = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.title.trim() || !form.message.trim()) return;
    setPublishing(true);
    setPublishError(null);
    try {
      await publishAnnouncement({
        title: form.title.trim(),
        message: form.message.trim(),
        announcement_type: form.announcement_type,
        route_ids: form.route_ids,
        severity: form.severity,
        incident_id: form.incident_id,
      });
      setForm((f) => ({
        ...f,
        title: "",
        message: "",
        route_ids: prefillRoute ? [prefillRoute] : [],
      }));
    } catch (err) {
      setPublishError(err instanceof Error ? err.message : "Erreur publication");
    }
    setPublishing(false);
  };

  return (
    <main
      className="dashboard-panel overflow-auto"
      style={{ gridColumn: "2 / -1", padding: 24 }}
    >
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <div className="mb-6">
        <h1 className="text-xl font-semibold">Information voyageurs</h1>
        <p className="text-sm text-muted-foreground">
          Publication de perturbations, annulations, déviations et messages réseau.
        </p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="shadow-none">
          <CardContent className="p-4">
            <h2 className="mb-4 flex items-center gap-2 text-sm font-semibold">
              <Megaphone className="h-4 w-4" />
              Publier une annonce
            </h2>
            <form onSubmit={handlePublish} className="space-y-3">
              <div className="grid gap-3 sm:grid-cols-2">
                <div className="space-y-1.5">
                  <Label>Type</Label>
                  <Select
                    value={form.announcement_type}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        announcement_type: e.target.value as PassengerAnnouncement["announcement_type"],
                      }))
                    }
                  >
                    <option value="info">Information</option>
                    <option value="disruption">Perturbation</option>
                    <option value="cancellation">Annulation</option>
                    <option value="deviation">Déviation</option>
                    <option value="delay">Retard</option>
                  </Select>
                </div>
                <div className="space-y-1.5">
                  <Label>Sévérité</Label>
                  <Select
                    value={form.severity}
                    onChange={(e) =>
                      setForm((f) => ({
                        ...f,
                        severity: e.target.value as PassengerAnnouncement["severity"],
                      }))
                    }
                  >
                    <option value="info">Info</option>
                    <option value="warning">Alerte</option>
                    <option value="critical">Critique</option>
                  </Select>
                </div>
              </div>

              <div className="space-y-1.5">
                <Label>Titre</Label>
                <Input
                  value={form.title}
                  onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
                  placeholder="Ex. Perturbation ligne C4"
                  required
                />
              </div>

              <div className="space-y-1.5">
                <Label>Message voyageur</Label>
                <Textarea
                  value={form.message}
                  onChange={(e) => setForm((f) => ({ ...f, message: e.target.value }))}
                  placeholder="Message affiché aux voyageurs…"
                  rows={4}
                  required
                />
              </div>

              <div className="space-y-1.5">
                <Label>Lignes impactées</Label>
                <div className="flex gap-2">
                  <Select
                    value={selectedRoute}
                    onChange={(e) => setSelectedRoute(e.target.value)}
                  >
                    <option value="">Ajouter une ligne…</option>
                    {routes.map((r) => (
                      <option key={r.route_id} value={r.route_id}>
                        {r.route_short_name ?? r.route_id}
                      </option>
                    ))}
                  </Select>
                  <Button type="button" variant="outline" size="sm" onClick={addRoute}>
                    Ajouter
                  </Button>
                </div>
                {form.route_ids.length > 0 && (
                  <div className="flex flex-wrap gap-1 mt-2">
                    {form.route_ids.map((r) => (
                      <Badge key={r} variant="secondary">
                        {r}
                        <button
                          type="button"
                          className="ml-1"
                          onClick={() =>
                            setForm((f) => ({
                              ...f,
                              route_ids: f.route_ids.filter((id) => id !== r),
                            }))
                          }
                        >
                          ×
                        </button>
                      </Badge>
                    ))}
                  </div>
                )}
              </div>

              {publishError && <p className="text-xs text-destructive">{publishError}</p>}

              <Button
                type="submit"
                disabled={publishing || !form.title.trim() || !form.message.trim()}
                className="w-full"
              >
                {publishing ? "Publication…" : "Publier"}
              </Button>
            </form>
          </CardContent>
        </Card>

        <div>
          <h2 className="mb-3 text-sm font-semibold">
            Annonces actives ({announcements.filter((a) => a.is_active).length})
          </h2>

          {loading ? (
            <ListSkeleton rows={4} />
          ) : announcements.length === 0 ? (
            <EmptyState
              icon={Megaphone}
              title="Aucune annonce"
              description="Publiez une perturbation ou un message d'information pour les voyageurs."
            />
          ) : (
            <div className="space-y-2">
              {announcements.map((ann) => (
                <Card
                  key={ann.id}
                  className={`shadow-none ${!ann.is_active ? "opacity-60" : ""}`}
                >
                  <CardContent className="p-3">
                    <div className="flex items-start justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <strong className="text-sm">{ann.title}</strong>
                          <Badge variant="outline">
                            {announcementTypeLabel(ann.announcement_type)}
                          </Badge>
                          <Badge
                            style={{
                              background: `${severityColor(ann.severity)}22`,
                              color: severityColor(ann.severity),
                            }}
                          >
                            {severityLabel(ann.severity)}
                          </Badge>
                          {!ann.is_active && (
                            <Badge variant="secondary">Archivée</Badge>
                          )}
                        </div>
                        <p className="mt-1 text-sm text-muted-foreground">{ann.message}</p>
                        <p className="mt-2 text-xs text-muted-foreground">
                          {ann.route_ids.length > 0
                            ? `Lignes : ${ann.route_ids.join(", ")} · `
                            : "Réseau entier · "}
                          {formatRelativeTime(ann.published_at)}
                        </p>
                      </div>
                      {ann.is_active && (
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-8 w-8 shrink-0"
                          onClick={() => deactivateAnnouncement(ann.id)}
                        >
                          <Trash2 className="h-4 w-4 text-muted-foreground" />
                        </Button>
                      )}
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
