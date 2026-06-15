"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Clock, MapPin, MessageSquare, User } from "lucide-react";
import { useDriversData } from "@/hooks/use-drivers-data";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  driverStatusLabel,
  formatRelativeTime,
  statusLabel,
} from "@/lib/types";

export function DriversPageContent() {
  const searchParams = useSearchParams();
  const highlightSession = searchParams.get("session");
  const { drivers, loading, error, lastUpdated, refresh } = useDriversData();

  const activeCount = drivers.filter(
    (d) => d.status === "active" || d.status === "paused",
  ).length;

  return (
    <main
      className="dashboard-panel overflow-auto"
      style={{ gridColumn: "2 / -1", padding: 24 }}
    >
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold">Conducteurs</h1>
          <p className="text-sm text-muted-foreground">
            Sessions actives, statut de service et contact direct.
          </p>
        </div>
        <div className="flex items-center gap-2">
          <Badge variant="realtime">{activeCount} en service</Badge>
          {lastUpdated && (
            <span className="text-xs text-muted-foreground">
              MAJ {lastUpdated.toLocaleTimeString("fr-FR")}
            </span>
          )}
        </div>
      </div>

      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        {(["active", "paused", "detecting"] as const).map((status) => {
          const count = drivers.filter((d) => d.status === status).length;
          return (
            <Card key={status} className="shadow-none">
              <CardContent className="p-3">
                <p className="text-xs text-muted-foreground">
                  {driverStatusLabel(status)}
                </p>
                <p className="text-2xl font-semibold">{count}</p>
              </CardContent>
            </Card>
          );
        })}
        <Card className="shadow-none">
          <CardContent className="p-3">
            <p className="text-xs text-muted-foreground">Total sessions</p>
            <p className="text-2xl font-semibold">{drivers.length}</p>
          </CardContent>
        </Card>
      </div>

      {loading ? (
        <ListSkeleton rows={4} />
      ) : drivers.length === 0 ? (
        <EmptyState
          icon={User}
          title="Aucun conducteur connecté"
          description="Les sessions actives apparaîtront lorsque des conducteurs démarrent leur service."
        />
      ) : (
        <div className="space-y-3">
          {drivers.map((session) => {
            const isHighlighted = highlightSession === session.id;
            return (
              <Card
                key={session.id}
                className={`shadow-none ${isHighlighted ? "border-primary" : ""}`}
              >
                <CardContent className="flex items-start gap-4 p-4">
                  <div className="rounded-lg bg-muted p-2">
                    <User className="h-5 w-5 text-muted-foreground" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <strong className="text-sm">
                        {session.driver?.display_name ?? "Conducteur"}
                      </strong>
                      <Badge variant="outline">
                        {driverStatusLabel(session.status)}
                      </Badge>
                      {session.route_id && (
                        <Badge variant="secondary">Ligne {session.route_id}</Badge>
                      )}
                    </div>
                    {session.headsign && (
                      <p className="mt-1 text-xs text-muted-foreground">
                        {session.headsign}
                      </p>
                    )}
                    <p className="mt-1 flex items-center gap-3 text-xs text-muted-foreground">
                      <span className="flex items-center gap-1">
                        <Clock className="h-3 w-3" />
                        Début {formatRelativeTime(session.started_at)}
                      </span>
                      {session.detection_confidence != null && (
                        <span>Confiance {session.detection_confidence}%</span>
                      )}
                    </p>
                  </div>
                  <div className="flex shrink-0 gap-2">
                    <Button variant="outline" size="sm" className="h-8 gap-1 text-xs" asChild>
                      <Link
                        href={`/communication?driver=${session.driver_id}&route=${session.route_id ?? ""}`}
                      >
                        <MessageSquare className="h-3.5 w-3.5" />
                        Message
                      </Link>
                    </Button>
                    <Button variant="outline" size="sm" className="h-8 gap-1 text-xs" asChild>
                      <Link href={`/dashboard`}>
                        <MapPin className="h-3.5 w-3.5" />
                        Carte
                      </Link>
                    </Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}
    </main>
  );
}
