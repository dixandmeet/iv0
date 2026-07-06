"use client";

import { useMemo } from "react";
import { BarChart3, Download, FileText } from "lucide-react";
import { useOperationsData } from "@/hooks/use-operations-data";
import { useIncidentsData } from "@/hooks/use-incidents-data";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  computePunctualityRate,
  countActiveLines,
  sumActiveUsers,
} from "@/lib/alerts";
import { statusLabel } from "@/lib/types";

function exportCsv(rows: string[][]) {
  const csv = rows.map((r) => r.map((c) => `"${c.replace(/"/g, '""')}"`).join(",")).join("\n");
  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = `aule-report-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(url);
}

export function ReportingPageContent() {
  const { fleet, error: fleetError, refresh } = useOperationsData();
  const { incidents: allIncidents, error: incError } = useIncidentsData({
    statusFilter: "all",
  });

  const punctuality = computePunctualityRate(fleet);
  const activeLines = countActiveLines(fleet);
  const activeUsers = sumActiveUsers(fleet);

  const incidentStats = useMemo(() => {
    const byType: Record<string, number> = {};
    const byRoute: Record<string, number> = {};
    let resolvedCount = 0;
    let totalResolutionMin = 0;

    for (const inc of allIncidents) {
      byType[inc.incident_type] = (byType[inc.incident_type] ?? 0) + 1;
      const route = inc.route_id ?? "Réseau";
      byRoute[route] = (byRoute[route] ?? 0) + 1;
      if (inc.status === "resolved" || inc.status === "closed") {
        resolvedCount++;
        const created = new Date(inc.created_at).getTime();
        const resolved = Date.now();
        totalResolutionMin += (resolved - created) / 60000;
      }
    }

    const avgResolution =
      resolvedCount > 0 ? Math.round(totalResolutionMin / resolvedCount) : 0;
    const incidentRate =
      allIncidents.length > 0
        ? Math.round((allIncidents.length / Math.max(activeLines, 1)) * 10) / 10
        : 0;

    return { byType, byRoute, avgResolution, incidentRate, total: allIncidents.length };
  }, [allIncidents, activeLines]);

  const punctualityByRoute = useMemo(() => {
    const map: Record<string, { onTime: number; total: number }> = {};
    for (const v of fleet) {
      if (!map[v.route_id]) map[v.route_id] = { onTime: 0, total: 0 };
      map[v.route_id].total++;
      if (!v.estimated_delay_seconds || v.estimated_delay_seconds <= 60) {
        map[v.route_id].onTime++;
      }
    }
    return Object.entries(map)
      .map(([route, { onTime, total }]) => ({
        route,
        rate: Math.round((onTime / total) * 100),
        total,
      }))
      .sort((a, b) => a.rate - b.rate);
  }, [fleet]);

  const handleExportCsv = () => {
    const rows: string[][] = [
      ["Indicateur", "Valeur"],
      ["Ponctualité globale", `${punctuality}%`],
      ["Véhicules actifs", String(fleet.length)],
      ["Lignes actives", String(activeLines)],
      ["Contributeurs actifs", String(activeUsers)],
      ["Incidents total", String(incidentStats.total)],
      ["Temps résolution moy. (min)", String(incidentStats.avgResolution)],
      ["Taux incidents/ligne", String(incidentStats.incidentRate)],
      [],
      ["Ponctualité par ligne", "Taux", "Véhicules"],
      ...punctualityByRoute.map((r) => [r.route, `${r.rate}%`, String(r.total)]),
      [],
      ["Incidents par type", "Count"],
      ...Object.entries(incidentStats.byType).map(([t, c]) => [t, String(c)]),
    ];
    exportCsv(rows);
  };

  const error = fleetError || incError;

  return (
    <main
      className="dashboard-main-column dashboard-panel overflow-auto"
      style={{ padding: 24 }}
    >
      {error && <ErrorBanner message={error} onRetry={refresh} />}

      <div className="mb-6 flex items-start justify-between gap-4">
        <div>
          <h1 className="text-xl font-semibold">Reporting & historique</h1>
          <p className="text-sm text-muted-foreground">
            Indicateurs opérationnels et exports pour analyse.
          </p>
        </div>
        <div className="flex gap-2">
          <Button variant="outline" size="sm" className="gap-2" onClick={handleExportCsv}>
            <Download className="h-4 w-4" />
            Export CSV
          </Button>
        </div>
      </div>

      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-4">
        <KpiCard label="Ponctualité" value={`${punctuality}%`} />
        <KpiCard label="Incidents" value={String(incidentStats.total)} />
        <KpiCard
          label="Résolution moy."
          value={`${incidentStats.avgResolution} min`}
        />
        <KpiCard label="Taux incidents/ligne" value={String(incidentStats.incidentRate)} />
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="shadow-none">
          <CardContent className="p-4">
            <h2 className="mb-4 flex items-center gap-2 text-sm font-semibold">
              <BarChart3 className="h-4 w-4" />
              Ponctualité par ligne
            </h2>
            {punctualityByRoute.length === 0 ? (
              <p className="text-sm text-muted-foreground">Aucune donnée flotte.</p>
            ) : (
              <div className="space-y-2">
                {punctualityByRoute.map((r) => (
                  <div key={r.route} className="flex items-center gap-3">
                    <span className="w-12 text-sm font-medium">{r.route}</span>
                    <div className="flex-1 h-2 rounded-full bg-muted overflow-hidden">
                      <div
                        className="h-full rounded-full bg-primary transition-all"
                        style={{
                          width: `${r.rate}%`,
                          background:
                            r.rate >= 80
                              ? "#16a34a"
                              : r.rate >= 60
                                ? "#ea580c"
                                : "#dc2626",
                        }}
                      />
                    </div>
                    <span className="text-xs text-muted-foreground w-16 text-right">
                      {r.rate}% ({r.total})
                    </span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="shadow-none">
          <CardContent className="p-4">
            <h2 className="mb-4 flex items-center gap-2 text-sm font-semibold">
              <FileText className="h-4 w-4" />
              Incidents par type
            </h2>
            {Object.keys(incidentStats.byType).length === 0 ? (
              <p className="text-sm text-muted-foreground">Aucun incident.</p>
            ) : (
              <div className="space-y-2">
                {Object.entries(incidentStats.byType).map(([type, count]) => (
                  <div
                    key={type}
                    className="flex items-center justify-between rounded-lg border border-border px-3 py-2 text-sm"
                  >
                    <span>{type}</span>
                    <strong>{count}</strong>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        <Card className="shadow-none lg:col-span-2">
          <CardContent className="p-4">
            <h2 className="mb-4 text-sm font-semibold">Incidents par ligne</h2>
            <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
              {Object.entries(incidentStats.byRoute).map(([route, count]) => (
                <div
                  key={route}
                  className="flex items-center justify-between rounded-lg border border-border px-3 py-2 text-sm"
                >
                  <span>Ligne {route}</span>
                  <strong>{count}</strong>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>

        <Card className="shadow-none lg:col-span-2">
          <CardContent className="p-4">
            <h2 className="mb-4 text-sm font-semibold">Incidents récents</h2>
            <div className="space-y-2">
              {allIncidents.slice(0, 10).map((inc) => (
                <div
                  key={inc.id}
                  className="flex items-center justify-between rounded-lg border border-border px-3 py-2 text-sm"
                >
                  <div className="min-w-0">
                    <p className="truncate font-medium">{inc.title}</p>
                    <p className="text-xs text-muted-foreground">
                      {inc.incident_type}
                      {inc.route_id ? ` · ${inc.route_id}` : ""}
                    </p>
                  </div>
                  <span className="text-xs text-muted-foreground shrink-0">
                    {statusLabel(inc.status)}
                  </span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </main>
  );
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <Card className="shadow-none">
      <CardContent className="p-3">
        <p className="text-xs text-muted-foreground">{label}</p>
        <p className="text-2xl font-semibold">{value}</p>
      </CardContent>
    </Card>
  );
}
