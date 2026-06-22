"use client";

import { useState } from "react";
import { Check, Clock, Mail, MessageSquare, User, X } from "lucide-react";
import type { DepotOption, DriverRegistrationRequest } from "@/lib/drivers-types";
import { formatRelativeTime } from "@/lib/types";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Label, Select } from "@/components/ui/label";
import { Input } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/empty-state";

interface DriverRequestsPanelProps {
  requests: DriverRegistrationRequest[];
  depots: DepotOption[];
  submitting: boolean;
  onApprove: (requestId: string, depotId: string | null) => Promise<void>;
  onReject: (requestId: string, reason: string) => Promise<void>;
}

export function DriverRequestsPanel({
  requests,
  depots,
  submitting,
  onApprove,
  onReject,
}: DriverRequestsPanelProps) {
  const [depotByRequest, setDepotByRequest] = useState<Record<string, string>>({});
  const [rejectingId, setRejectingId] = useState<string | null>(null);
  const [rejectReason, setRejectReason] = useState("");

  if (requests.length === 0) {
    return (
      <EmptyState
        icon={User}
        title="Aucune demande en attente"
        description="Les demandes d'inscription soumises depuis l'app mobile apparaîtront ici pour validation."
      />
    );
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        {requests.length} demande{requests.length > 1 ? "s" : ""} à traiter — validez ou refusez l&apos;accès conducteur.
      </p>
      {requests.map((request) => {
        const selectedDepot =
          depotByRequest[request.id] ?? request.depot_id ?? "";
        const isRejecting = rejectingId === request.id;

        return (
          <Card key={request.id} className="shadow-none border-amber-500/30">
            <CardContent className="p-4">
              <div className="flex flex-col gap-4 sm:flex-row sm:items-start">
                <div className="rounded-lg bg-amber-500/10 p-2">
                  <User className="h-5 w-5 text-amber-600 dark:text-amber-400" />
                </div>
                <div className="min-w-0 flex-1 space-y-2">
                  <div>
                    <strong className="text-sm">
                      {request.display_name ?? "Conducteur"}
                    </strong>
                    <p className="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground">
                      <Mail className="h-3 w-3" />
                      {request.email}
                    </p>
                  </div>
                  {request.message && (
                    <p className="flex items-start gap-1.5 rounded-md bg-muted/50 px-3 py-2 text-xs text-muted-foreground">
                      <MessageSquare className="mt-0.5 h-3.5 w-3.5 shrink-0" />
                      {request.message}
                    </p>
                  )}
                  <p className="flex items-center gap-1 text-xs text-muted-foreground">
                    <Clock className="h-3 w-3" />
                    Demandé {formatRelativeTime(request.created_at)}
                    {request.depot_name && ` · Dépôt souhaité : ${request.depot_name}`}
                  </p>

                  {!isRejecting ? (
                    <div className="flex flex-wrap items-end gap-3 pt-1">
                      <div className="min-w-[180px] space-y-1">
                        <Label className="text-xs">Dépôt assigné</Label>
                        <Select
                          value={selectedDepot}
                          onChange={(e) =>
                            setDepotByRequest({
                              ...depotByRequest,
                              [request.id]: e.target.value,
                            })
                          }
                        >
                          <option value="">— Non assigné —</option>
                          {depots.map((d) => (
                            <option key={d.id} value={d.id}>
                              {d.name}
                            </option>
                          ))}
                        </Select>
                      </div>
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          className="gap-1"
                          disabled={submitting}
                          onClick={() =>
                            onApprove(request.id, selectedDepot || null)
                          }
                        >
                          <Check className="h-3.5 w-3.5" />
                          Valider
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          className="gap-1"
                          disabled={submitting}
                          onClick={() => {
                            setRejectingId(request.id);
                            setRejectReason("");
                          }}
                        >
                          <X className="h-3.5 w-3.5" />
                          Refuser
                        </Button>
                      </div>
                    </div>
                  ) : (
                    <div className="space-y-2 rounded-lg border border-border p-3">
                      <Label className="text-xs">Motif du refus (optionnel)</Label>
                      <Input
                        value={rejectReason}
                        onChange={(e) => setRejectReason(e.target.value)}
                        placeholder="Ex. : matricule non reconnu"
                      />
                      <div className="flex gap-2">
                        <Button
                          size="sm"
                          variant="outline"
                          className="border-destructive/50 text-destructive hover:bg-destructive/10"
                          disabled={submitting}
                          onClick={async () => {
                            await onReject(request.id, rejectReason);
                            setRejectingId(null);
                          }}
                        >
                          Confirmer le refus
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => setRejectingId(null)}
                        >
                          Annuler
                        </Button>
                      </div>
                    </div>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>
        );
      })}
    </div>
  );
}
