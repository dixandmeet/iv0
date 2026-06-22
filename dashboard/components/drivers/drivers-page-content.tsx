"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useDriversData } from "@/hooks/use-drivers-data";
import { useDriversManagement } from "@/hooks/use-drivers-management";
import { useDriverActions } from "@/hooks/use-driver-actions";
import { ErrorBanner } from "@/components/dashboard/error-banner";
import { DriversHeader } from "@/components/drivers/drivers-header";
import { DriversTabs } from "@/components/drivers/drivers-tabs";
import { DriverSessionsPanel } from "@/components/drivers/driver-sessions-panel";
import { DriverRosterPanel } from "@/components/drivers/driver-roster-panel";
import { DriverRequestsPanel } from "@/components/drivers/driver-requests-panel";
import { DriverFormModal } from "@/components/drivers/driver-form-modal";
import type { AddDriverPayload, DriversPageTab } from "@/lib/drivers-types";
import { ListSkeleton } from "@/components/ui/empty-state";

const VALID_TABS: DriversPageTab[] = ["sessions", "roster", "requests"];

function parseTab(value: string | null, pendingCount: number): DriversPageTab {
  if (value && VALID_TABS.includes(value as DriversPageTab)) {
    return value as DriversPageTab;
  }
  return pendingCount > 0 ? "requests" : "sessions";
}

export function DriversPageContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const highlightSession = searchParams.get("session");

  const {
    drivers: sessions,
    loading: sessionsLoading,
    error: sessionsError,
    lastUpdated: sessionsUpdated,
    refresh: refreshSessions,
  } = useDriversData();

  const {
    requests,
    roster,
    depots,
    loading: managementLoading,
    error: managementError,
    pendingCount,
    refresh: refreshManagement,
  } = useDriversManagement();

  const {
    lookupByEmail,
    addDriver,
    approveRequest,
    rejectRequest,
    submitting,
    error: actionError,
  } = useDriverActions();

  const [formOpen, setFormOpen] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const activeTab = parseTab(searchParams.get("tab"), pendingCount);

  const activeSessionCount = useMemo(
    () => sessions.filter((d) => d.status === "active" || d.status === "paused").length,
    [sessions],
  );

  const lastUpdated = sessionsUpdated;

  useEffect(() => {
    if (searchParams.get("tab")) return;
    if (pendingCount > 0) {
      const params = new URLSearchParams(searchParams.toString());
      params.set("tab", "requests");
      router.replace(`/conducteurs?${params.toString()}`, { scroll: false });
    }
  }, [pendingCount, router, searchParams]);

  const setTab = useCallback(
    (tab: DriversPageTab) => {
      const params = new URLSearchParams(searchParams.toString());
      params.set("tab", tab);
      if (tab !== "sessions") params.delete("session");
      router.replace(`/conducteurs?${params.toString()}`, { scroll: false });
    },
    [router, searchParams],
  );

  const handleRefresh = async () => {
    setRefreshing(true);
    await Promise.all([refreshSessions(), refreshManagement()]);
    setRefreshing(false);
  };

  const handleAddDriver = async (payload: AddDriverPayload) => {
    const result = await addDriver(payload);
    await refreshManagement();
    setSuccessMessage(
      result.invited
        ? `Invitation envoyée à ${payload.email.trim()}`
        : `${payload.display_name.trim() || payload.email.trim()} est maintenant conducteur`,
    );
    setTab("roster");
  };

  const handleApprove = async (requestId: string, depotId: string | null) => {
    await approveRequest(requestId, depotId);
    await refreshManagement();
    setSuccessMessage("Demande validée — le conducteur peut utiliser l'app mobile.");
    if (pendingCount <= 1) setTab("roster");
  };

  const handleReject = async (requestId: string, reason: string) => {
    await rejectRequest(requestId, reason);
    await refreshManagement();
    setSuccessMessage("Demande refusée.");
  };

  const error = sessionsError ?? managementError ?? actionError;

  return (
    <main className="dashboard-panel stops-page overflow-auto" style={{ gridColumn: "2 / -1" }}>
      {error && <ErrorBanner message={error} onRetry={handleRefresh} />}
      {successMessage && (
        <div className="mx-6 mt-4 rounded-lg border border-emerald-500/30 bg-emerald-500/10 px-4 py-3 text-sm text-emerald-800 dark:text-emerald-300">
          {successMessage}
          <button
            type="button"
            className="ml-3 text-xs underline opacity-70"
            onClick={() => setSuccessMessage(null)}
          >
            Fermer
          </button>
        </div>
      )}

      <DriversHeader
        activeTab={activeTab}
        pendingCount={pendingCount}
        activeSessionCount={activeSessionCount}
        rosterCount={roster.length}
        lastUpdated={lastUpdated}
        onAdd={() => setFormOpen(true)}
        onRefresh={handleRefresh}
        refreshing={refreshing}
      />

      <div className="px-6 pb-6">
        <DriversTabs
          activeTab={activeTab}
          onTabChange={setTab}
          pendingCount={pendingCount}
          sessionCount={sessions.length}
          rosterCount={roster.length}
        />

        {activeTab === "sessions" && (
          <DriverSessionsPanel
            sessions={sessions}
            loading={sessionsLoading}
            highlightSession={highlightSession}
          />
        )}

        {activeTab === "roster" && (
          managementLoading ? (
            <ListSkeleton rows={4} />
          ) : (
            <DriverRosterPanel drivers={roster} loading={managementLoading} />
          )
        )}

        {activeTab === "requests" && (
          managementLoading ? (
            <ListSkeleton rows={3} />
          ) : (
            <DriverRequestsPanel
              requests={requests}
              depots={depots}
              submitting={submitting}
              onApprove={handleApprove}
              onReject={handleReject}
            />
          )
        )}
      </div>

      <DriverFormModal
        open={formOpen}
        onClose={() => setFormOpen(false)}
        onSubmit={handleAddDriver}
        onLookup={lookupByEmail}
        depots={depots}
        submitting={submitting}
      />
    </main>
  );
}
