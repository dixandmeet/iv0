"use client";

import { useCallback, useMemo } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowRight, BusFront, Plus } from "lucide-react";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { RegulationKpiBar } from "@/components/dashboard/regulation-kpi-bar";
import { LinesPanel } from "@/components/dashboard/lines-panel";
import { TimelineLegend } from "@/components/dashboard/timeline-legend";
import { useRegulationDashboard } from "@/hooks/use-regulation-dashboard";
import { useCustomRegulationLines } from "@/hooks/use-custom-regulation-lines";
import { useNetwork } from "@/components/network/network-provider";

export function OperationsDashboard() {
  const router = useRouter();
  const { network, canManage } = useNetwork();
  const {
    customLines,
    ready: customLinesReady,
    deleteLine,
  } = useCustomRegulationLines();
  const {
    lines: networkLines,
    loading,
    error,
    lastUpdated,
    refresh,
    kpis,
    alerts,
  } = useRegulationDashboard(null);

  const lines = useMemo(
    () => [...customLines, ...networkLines],
    [customLines, networkLines],
  );

  const handleDeleteLine = useCallback(
    (lineId: string) => {
      void deleteLine(lineId);
    },
    [deleteLine],
  );

  const openLine = useCallback(
    (lineId: string) => {
      router.push(`/lignes/${encodeURIComponent(lineId)}`);
    },
    [router],
  );

  return (
    <div className="regulation-workspace">
      <RegulationKpiBar
        onRefresh={refresh}
        loading={loading}
        kpis={kpis}
        alertCount={alerts.length}
      />

      <LinesPanel
        lines={lines}
        selectedLineId=""
        onSelectLine={openLine}
        onDeleteLine={handleDeleteLine}
        loading={loading || !customLinesReady}
      />

      <main className="regulation-main">
        {error && (
          <div className="px-4 pt-2">
            <ErrorBanner message={error} onRetry={refresh} />
          </div>
        )}

        <div className="flex flex-1 items-center justify-center overflow-y-auto p-8">
          <section className="w-full max-w-2xl rounded-3xl border border-white/10 bg-[#081327] p-8 text-center shadow-2xl shadow-black/10 sm:p-10">
            <div className="mx-auto flex h-14 w-14 items-center justify-center rounded-2xl border border-blue-400/20 bg-blue-500/10 text-blue-300">
              <BusFront className="h-7 w-7" strokeWidth={1.6} />
            </div>
            <p className="mt-6 text-xs font-semibold uppercase tracking-[0.16em] text-blue-300">
              {network.name}
            </p>
            <h1 className="mt-2 text-2xl font-semibold tracking-tight text-white">
              {lines.length > 0
                ? `${lines.length} ligne${lines.length > 1 ? "s" : ""} sur votre réseau`
                : "Votre réseau ne contient encore aucune ligne"}
            </h1>
            <p className="mx-auto mt-3 max-w-lg text-sm leading-6 text-slate-400">
              {lines.length > 0
                ? "Sélectionnez une ligne dans la liste pour ouvrir sa fiche d’exploitation, consulter son plan et accéder à ses actions."
                : "Créez une ligne manuellement ou importez votre fichier GTFS pour commencer à exploiter le réseau."}
            </p>

            {canManage && (
              <div className="mt-7 flex flex-wrap justify-center gap-3">
                <Link
                  href="/lignes/nouvelle"
                  className="inline-flex h-11 items-center gap-2 rounded-xl bg-blue-600 px-5 text-sm font-semibold text-white transition hover:bg-blue-500"
                >
                  <Plus className="h-4 w-4" />
                  Créer une ligne
                </Link>
                <Link
                  href="/configuration/reseau"
                  className="inline-flex h-11 items-center gap-2 rounded-xl border border-white/10 bg-white/5 px-5 text-sm font-semibold text-slate-200 transition hover:bg-white/10"
                >
                  Importer un GTFS
                  <ArrowRight className="h-4 w-4" />
                </Link>
              </div>
            )}
          </section>
        </div>
      </main>

      <TimelineLegend lastUpdated={lastUpdated} onRefresh={refresh} />
    </div>
  );
}
