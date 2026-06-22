"use client";

import { ChevronLeft, ChevronRight } from "lucide-react";
import { MapPin } from "lucide-react";
import type { StationListItem } from "@/lib/stations-types";
import { EmptyState, ListSkeleton } from "@/components/ui/empty-state";
import { Button } from "@/components/ui/button";
import { StationListCard } from "@/components/stations/station-list-card";

interface StationsListPanelProps {
  stations: StationListItem[];
  loading: boolean;
  selectedId: string | null;
  onSelect: (id: string) => void;
  page: number;
  totalPages: number;
  totalCount: number;
  onPageChange: (page: number) => void;
}

export function StationsListPanel({
  stations,
  loading,
  selectedId,
  onSelect,
  page,
  totalPages,
  totalCount,
  onPageChange,
}: StationsListPanelProps) {
  return (
    <div className="stops-list-panel">
      <div className="stops-list-panel-header">
        <span className="stops-list-count">
          {totalCount} station{totalCount !== 1 ? "s" : ""}
        </span>
      </div>
      <div className="stops-list-scroll">
        {loading ? (
          <ListSkeleton rows={6} />
        ) : stations.length === 0 ? (
          <EmptyState
            icon={MapPin}
            title="Aucune station trouvée"
            description="Modifiez vos filtres ou votre recherche."
          />
        ) : (
          stations.map((station) => (
            <StationListCard
              key={station.id}
              station={station}
              selected={selectedId === station.id}
              onSelect={() => onSelect(station.id)}
            />
          ))
        )}
      </div>
      {totalPages > 1 && (
        <div className="stops-list-pagination">
          <Button variant="outline" size="sm" disabled={page === 0} onClick={() => onPageChange(page - 1)}>
            <ChevronLeft className="h-4 w-4" />
          </Button>
          <span>
            {page + 1} / {totalPages}
          </span>
          <Button
            variant="outline"
            size="sm"
            disabled={page >= totalPages - 1}
            onClick={() => onPageChange(page + 1)}
          >
            <ChevronRight className="h-4 w-4" />
          </Button>
        </div>
      )}
    </div>
  );
}
