"use client";

import Link from "next/link";
import { Building2, Mail, MessageSquare, User } from "lucide-react";
import type { RegisteredDriver } from "@/lib/drivers-types";
import { driverStatusLabel } from "@/lib/types";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/empty-state";

interface DriverRosterPanelProps {
  drivers: RegisteredDriver[];
  loading: boolean;
}

export function DriverRosterPanel({ drivers, loading }: DriverRosterPanelProps) {
  if (loading) return null;

  if (drivers.length === 0) {
    return (
      <EmptyState
        icon={User}
        title="Aucun conducteur enregistré"
        description="Ajoutez un conducteur ou validez une demande d'inscription pour constituer l'annuaire."
      />
    );
  }

  return (
    <div className="space-y-3">
      <p className="text-sm text-muted-foreground">
        {drivers.length} conducteur{drivers.length > 1 ? "s" : ""} habilité{drivers.length > 1 ? "s" : ""} sur l&apos;app mobile.
      </p>
      {drivers.map((driver) => (
        <Card key={driver.id} className="shadow-none">
          <CardContent className="flex items-start gap-4 p-4">
            <div className="rounded-lg bg-muted p-2">
              <User className="h-5 w-5 text-muted-foreground" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <strong className="text-sm">
                  {driver.display_name ?? "Conducteur"}
                </strong>
                {driver.active_session_id ? (
                  <Badge variant="realtime">
                    {driverStatusLabel(
                      driver.active_session_status as "active" | "paused" | "detecting",
                    )}
                  </Badge>
                ) : (
                  <Badge variant="outline">Hors service</Badge>
                )}
              </div>
              <p className="mt-1 flex items-center gap-1 text-xs text-muted-foreground">
                <Mail className="h-3 w-3" />
                {driver.email}
              </p>
              {driver.depot_name && (
                <p className="mt-1 flex items-center gap-1 text-xs text-muted-foreground">
                  <Building2 className="h-3 w-3" />
                  {driver.depot_name}
                </p>
              )}
            </div>
            <div className="flex shrink-0 gap-2">
              <Button variant="outline" size="sm" className="h-8 gap-1 text-xs" asChild>
                <Link href={`/communication?driver=${driver.id}`}>
                  <MessageSquare className="h-3.5 w-3.5" />
                  Message
                </Link>
              </Button>
              {driver.active_session_id && (
                <Button variant="outline" size="sm" className="h-8 gap-1 text-xs" asChild>
                  <Link href={`/conducteurs?tab=sessions&session=${driver.active_session_id}`}>
                    Session
                  </Link>
                </Button>
              )}
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}
