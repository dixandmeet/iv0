"use client";

import { useEffect, useState } from "react";
import { Loader2, Search, X } from "lucide-react";
import type { AddDriverPayload, DepotOption, DriverLookupResult } from "@/lib/drivers-types";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label, Select } from "@/components/ui/label";

interface DriverFormModalProps {
  open: boolean;
  onClose: () => void;
  onSubmit: (payload: AddDriverPayload) => Promise<void>;
  onLookup: (email: string) => Promise<DriverLookupResult | null>;
  depots: DepotOption[];
  submitting: boolean;
}

const EMPTY: AddDriverPayload = {
  email: "",
  display_name: "",
  depot_id: null,
  invite_if_missing: true,
};

export function DriverFormModal({
  open,
  onClose,
  onSubmit,
  onLookup,
  depots,
  submitting,
}: DriverFormModalProps) {
  const [form, setForm] = useState<AddDriverPayload>(EMPTY);
  const [lookup, setLookup] = useState<DriverLookupResult | null>(null);
  const [lookupLoading, setLookupLoading] = useState(false);
  const [lookupError, setLookupError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setForm(EMPTY);
      setLookup(null);
      setLookupError(null);
    }
  }, [open]);

  useEffect(() => {
    const email = form.email.trim();
    if (!email.includes("@") || email.length < 5) {
      setLookup(null);
      setLookupError(null);
      return;
    }

    const timer = setTimeout(async () => {
      setLookupLoading(true);
      setLookupError(null);
      try {
        const result = await onLookup(email);
        setLookup(result);
        if (result?.display_name && !form.display_name) {
          setForm((prev) => ({ ...prev, display_name: result.display_name ?? "" }));
        }
        if (result?.depot_id && !form.depot_id) {
          setForm((prev) => ({ ...prev, depot_id: result.depot_id }));
        }
      } catch (e) {
        setLookup(null);
        setLookupError(e instanceof Error ? e.message : "Recherche impossible");
      } finally {
        setLookupLoading(false);
      }
    }, 400);

    return () => clearTimeout(timer);
  }, [form.email, form.display_name, form.depot_id, onLookup]);

  if (!open) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!form.email.trim()) return;
    await onSubmit(form);
    onClose();
  };

  return (
    <div className="stops-modal-overlay" onClick={onClose}>
      <div className="stops-modal stops-glass-card" onClick={(e) => e.stopPropagation()}>
        <div className="stops-modal-header">
          <h2>Ajouter un conducteur</h2>
          <button type="button" onClick={onClose} className="stops-modal-close">
            <X className="h-5 w-5" />
          </button>
        </div>
        <form onSubmit={handleSubmit} className="stops-form stops-form--modal">
          <p className="text-sm text-muted-foreground">
            Promouvez un compte existant ou invitez un nouveau conducteur par e-mail.
          </p>

          <div className="space-y-1.5">
            <Label>Adresse e-mail</Label>
            <div className="relative">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
              <Input
                type="email"
                className="pl-9"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
                placeholder="conducteur@exemple.fr"
                required
                autoFocus
              />
            </div>
            {lookupLoading && (
              <p className="flex items-center gap-1 text-xs text-muted-foreground">
                <Loader2 className="h-3 w-3 animate-spin" />
                Recherche du compte…
              </p>
            )}
            {lookupError && (
              <p className="text-xs text-destructive">{lookupError}</p>
            )}
            {lookup && (
              <div className="rounded-lg border border-border bg-muted/40 px-3 py-2 text-xs">
                <p>
                  Compte trouvé — rôle actuel :{" "}
                  <strong>{roleLabel(lookup.role)}</strong>
                </p>
                {lookup.role === "driver" && (
                  <p className="mt-1 text-destructive">Ce compte est déjà conducteur.</p>
                )}
                {lookup.has_pending_request && (
                  <p className="mt-1 text-amber-600 dark:text-amber-400">
                    Une demande d&apos;inscription est en attente pour ce compte.
                  </p>
                )}
              </div>
            )}
            {!lookupLoading && !lookup && form.email.includes("@") && !lookupError && (
              <p className="text-xs text-muted-foreground">
                Aucun compte trouvé — une invitation par e-mail sera envoyée si configurée.
              </p>
            )}
          </div>

          <div className="grid gap-3 sm:grid-cols-2">
            <div className="space-y-1.5 sm:col-span-2">
              <Label>Nom affiché</Label>
              <Input
                value={form.display_name}
                onChange={(e) => setForm({ ...form, display_name: e.target.value })}
                placeholder="Jean Dupont"
              />
            </div>
            <div className="space-y-1.5 sm:col-span-2">
              <Label>Dépôt</Label>
              <Select
                value={form.depot_id ?? ""}
                onChange={(e) =>
                  setForm({ ...form, depot_id: e.target.value || null })
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
          </div>

          {!lookup && form.email.includes("@") && (
            <label className="flex items-start gap-2 text-sm">
              <input
                type="checkbox"
                className="mt-1"
                checked={form.invite_if_missing ?? false}
                onChange={(e) =>
                  setForm({ ...form, invite_if_missing: e.target.checked })
                }
              />
              <span className="text-muted-foreground">
                Envoyer une invitation par e-mail si le compte n&apos;existe pas encore
              </span>
            </label>
          )}

          <div className="stops-modal-footer">
            <Button type="button" variant="outline" onClick={onClose}>
              Annuler
            </Button>
            <Button
              type="submit"
              disabled={submitting || lookup?.role === "driver"}
            >
              {submitting ? "Enregistrement…" : lookup ? "Promouvoir conducteur" : "Inviter / ajouter"}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}

function roleLabel(role: string): string {
  switch (role) {
    case "driver":
      return "Conducteur";
    case "passenger":
      return "Passager";
    case "msr_agent":
      return "Agent MSR";
    case "regulator":
      return "Régulateur";
    case "admin":
      return "Administrateur";
    default:
      return role;
  }
}
