"use client";

import { useEffect, useMemo, useRef, useState, type FormEvent } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { ArrowLeft, ArrowRight, BusFront, Check, Ship, TrainFront } from "lucide-react";
import { useNetwork } from "@/components/network/network-provider";
import { useCustomRegulationLines } from "@/hooks/use-custom-regulation-lines";
import { createClient } from "@/lib/supabase/client";
import { ADD_LINE_DEPOT_OPTIONS } from "@/lib/regulation-custom-line";
import {
  NETWORK_MODE_LABELS,
  type NetworkMode,
} from "@/lib/regulation-mock-data";

const TRANSPORT_MODES: Array<{
  value: NetworkMode;
  label: string;
  icon: typeof BusFront;
}> = [
  { value: "bus", label: NETWORK_MODE_LABELS.bus, icon: BusFront },
  { value: "tram", label: NETWORK_MODE_LABELS.tram, icon: TrainFront },
  { value: "boat", label: NETWORK_MODE_LABELS.boat, icon: Ship },
];

type DepotOption = { code: string; label: string };

export function CreateLinePage() {
  const router = useRouter();
  const { network, canManage, isPilotNetwork } = useNetwork();
  const { customLines, ready, addLine } = useCustomRegulationLines();
  const [shortName, setShortName] = useState("");
  const [origin, setOrigin] = useState("");
  const [destination, setDestination] = useState("");
  const [transportType, setTransportType] = useState<NetworkMode>("bus");
  const [depots, setDepots] = useState<DepotOption[]>(
    isPilotNetwork ? ADD_LINE_DEPOT_OPTIONS : [],
  );
  const [depotCode, setDepotCode] = useState(
    isPilotNetwork ? (ADD_LINE_DEPOT_OPTIONS[0]?.code ?? "NETWORK") : "",
  );
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const shortNameRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    shortNameRef.current?.focus();
  }, []);

  useEffect(() => {
    if (isPilotNetwork) return;

    const supabase = createClient();
    void supabase
      .from("network_depots")
      .select("code, name")
      .eq("network_id", network.id)
      .order("name")
      .then(({ data }) => {
        const options = (data ?? []).map((depot) => ({
          code: depot.code as string,
          label: depot.name as string,
        }));
        const next = options.length
          ? options
          : [{ code: "NETWORK", label: network.name }];
        setDepots(next);
        setDepotCode(next[0].code);
      });
  }, [isPilotNetwork, network.id, network.name]);

  const normalizedShortName = shortName.trim();
  const duplicateLine = useMemo(
    () =>
      customLines.find(
        (line) => line.shortName.toLocaleLowerCase("fr") === normalizedShortName.toLocaleLowerCase("fr"),
      ),
    [customLines, normalizedShortName],
  );
  const isValid =
    normalizedShortName.length > 0 &&
    origin.trim().length > 0 &&
    destination.trim().length > 0 &&
    depotCode.length > 0 &&
    !duplicateLine;

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!isValid || submitting) return;

    setSubmitting(true);
    setError(null);
    try {
      const line = await addLine({
        shortName: normalizedShortName,
        origin: origin.trim(),
        destination: destination.trim(),
        transportType,
        depotCode,
      });
      router.push(`/dashboard/lignes/${encodeURIComponent(line.id)}`);
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "La ligne n’a pas pu être créée. Réessayez dans un instant.",
      );
      setSubmitting(false);
    }
  }

  if (!canManage) {
    return (
      <main className="flex h-full items-center justify-center overflow-y-auto bg-[#050B18] p-6">
        <div className="w-full max-w-md rounded-2xl border border-white/10 bg-[#0D1B33] p-8 text-center">
          <h1 className="text-xl font-semibold text-white">Accès restreint</h1>
          <p className="mt-2 text-sm leading-6 text-slate-400">
            La création d’une ligne est réservée aux administrateurs du réseau.
          </p>
          <Link href="/dashboard/lignes" className="mt-6 inline-flex items-center gap-2 text-sm font-medium text-blue-300 hover:text-blue-200">
            <ArrowLeft className="h-4 w-4" />
            Retour au tableau de bord
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="h-full overflow-y-auto bg-[#050B18]">
      <div className="mx-auto w-full max-w-3xl px-5 py-8 sm:px-8 sm:py-12">
        <Link
          href="/dashboard/lignes"
          className="inline-flex items-center gap-2 text-sm font-medium text-slate-400 transition-colors hover:text-white"
        >
          <ArrowLeft className="h-4 w-4" />
          Toutes les lignes
        </Link>

        <header className="mb-8 mt-8">
          <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-2xl border border-blue-400/20 bg-blue-500/10 text-blue-300">
            <BusFront className="h-6 w-6" strokeWidth={1.7} />
          </div>
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-blue-300">
            {network.name}
          </p>
          <h1 className="mt-2 text-3xl font-semibold tracking-tight text-white">
            Créer une ligne
          </h1>
          <p className="mt-2 max-w-xl text-sm leading-6 text-slate-400">
            Renseignez l’identité de la ligne. Vous pourrez ensuite compléter ses arrêts et son tracé depuis le tableau de bord.
          </p>
        </header>

        <form
          onSubmit={handleSubmit}
          className="rounded-2xl border border-white/10 bg-[#0A162B] p-5 shadow-2xl shadow-black/10 sm:p-7"
        >
          <div className="grid gap-6">
            <div>
              <label htmlFor="line-short-name" className="mb-2 block text-sm font-medium text-slate-200">
                Numéro ou nom court
              </label>
              <input
                ref={shortNameRef}
                id="line-short-name"
                value={shortName}
                onChange={(event) => {
                  setShortName(event.target.value);
                  setError(null);
                }}
                placeholder="Ex. C1, 42, Navette centre"
                autoComplete="off"
                className="h-12 w-full rounded-xl border border-white/10 bg-[#081327] px-4 text-base font-medium text-white outline-none transition placeholder:text-slate-600 focus:border-blue-400/60 focus:ring-4 focus:ring-blue-500/10"
              />
              {ready && duplicateLine && normalizedShortName && (
                <p className="mt-2 text-xs text-amber-300">
                  Une ligne {duplicateLine.shortName} existe déjà sur ce réseau.
                </p>
              )}
            </div>

            <fieldset>
              <legend className="mb-2 text-sm font-medium text-slate-200">Mode de transport</legend>
              <div className="grid grid-cols-3 gap-2">
                {TRANSPORT_MODES.map(({ value, label, icon: Icon }) => {
                  const selected = value === transportType;
                  return (
                    <button
                      key={value}
                      type="button"
                      aria-pressed={selected}
                      onClick={() => setTransportType(value)}
                      className={`flex h-12 items-center justify-center gap-2 rounded-xl border text-sm font-medium transition ${
                        selected
                          ? "border-blue-400/60 bg-blue-500/15 text-white"
                          : "border-white/10 bg-[#081327] text-slate-400 hover:border-white/20 hover:text-slate-200"
                      }`}
                    >
                      <Icon className="h-4 w-4" strokeWidth={1.8} />
                      {label}
                    </button>
                  );
                })}
              </div>
            </fieldset>

            <div className="grid gap-5 sm:grid-cols-2">
              <div>
                <label htmlFor="line-origin" className="mb-2 block text-sm font-medium text-slate-200">
                  Terminus de départ
                </label>
                <input
                  id="line-origin"
                  value={origin}
                  onChange={(event) => setOrigin(event.target.value)}
                  placeholder="Ex. Haluchère-Batignolles"
                  autoComplete="off"
                  className="h-12 w-full rounded-xl border border-white/10 bg-[#081327] px-4 text-sm text-white outline-none transition placeholder:text-slate-600 focus:border-blue-400/60 focus:ring-4 focus:ring-blue-500/10"
                />
              </div>
              <div>
                <label htmlFor="line-destination" className="mb-2 block text-sm font-medium text-slate-200">
                  Terminus d’arrivée
                </label>
                <input
                  id="line-destination"
                  value={destination}
                  onChange={(event) => setDestination(event.target.value)}
                  placeholder="Ex. Gare de Chantenay"
                  autoComplete="off"
                  className="h-12 w-full rounded-xl border border-white/10 bg-[#081327] px-4 text-sm text-white outline-none transition placeholder:text-slate-600 focus:border-blue-400/60 focus:ring-4 focus:ring-blue-500/10"
                />
              </div>
            </div>

            <div>
              <label htmlFor="line-depot" className="mb-2 block text-sm font-medium text-slate-200">
                Dépôt ou unité d’exploitation
              </label>
              <select
                id="line-depot"
                value={depotCode}
                onChange={(event) => setDepotCode(event.target.value)}
                className="h-12 w-full appearance-none rounded-xl border border-white/10 bg-[#081327] px-4 text-sm text-white outline-none transition focus:border-blue-400/60 focus:ring-4 focus:ring-blue-500/10"
              >
                {depots.map((depot) => (
                  <option key={depot.code} value={depot.code}>
                    {depot.label}
                  </option>
                ))}
              </select>
            </div>
          </div>

          {error && (
            <div role="alert" className="mt-6 rounded-xl border border-red-400/20 bg-red-500/10 px-4 py-3 text-sm text-red-200">
              {error}
            </div>
          )}

          <div className="mt-8 flex flex-col-reverse gap-3 border-t border-white/10 pt-6 sm:flex-row sm:items-center sm:justify-between">
            <p className="flex items-center gap-2 text-xs text-slate-500">
              <Check className="h-3.5 w-3.5 text-emerald-400" />
              La ligne sera enregistrée sur {network.name}.
            </p>
            <button
              type="submit"
              disabled={!ready || !isValid || submitting}
              className="inline-flex h-11 items-center justify-center gap-2 rounded-xl bg-blue-600 px-5 text-sm font-semibold text-white transition hover:bg-blue-500 disabled:cursor-not-allowed disabled:opacity-40"
            >
              {submitting ? "Création…" : "Créer la ligne"}
              {!submitting && <ArrowRight className="h-4 w-4" />}
            </button>
          </div>
        </form>
      </div>
    </main>
  );
}
