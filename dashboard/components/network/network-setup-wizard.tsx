"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, Building2, Bus, Check, Database, Loader2, MapPin, Network, Upload } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { createCustomRegulationLine } from "@/lib/regulation-custom-line";
import type { NetworkContextValue } from "@/lib/network/types";

type SetupStep = "identity" | "depots" | "data" | "done";

export function NetworkSetupWizard({ context }: { context: NetworkContextValue }) {
  const router = useRouter();
  const [step, setStep] = useState<SetupStep>("identity");
  const [name, setName] = useState(context.network.name);
  const [operator, setOperator] = useState(context.network.operator ?? "");
  const [territory, setTerritory] = useState(context.network.territory ?? "");
  const [depotName, setDepotName] = useState("");
  const [depotCode, setDepotCode] = useState("");
  const [depots, setDepots] = useState<{ code: string; name: string }[]>([]);
  const [lineShortName, setLineShortName] = useState("");
  const [lineOrigin, setLineOrigin] = useState("");
  const [lineDestination, setLineDestination] = useState("");
  const [createdLine, setCreatedLine] = useState<string | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [importResult, setImportResult] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const identityValid = name.trim().length >= 2 && operator.trim().length >= 2 && territory.trim().length >= 2;
  const lineValid = lineShortName.trim() && lineOrigin.trim() && lineDestination.trim();
  const stepIndex = useMemo(() => ["identity", "depots", "data", "done"].indexOf(step), [step]);

  useEffect(() => {
    const supabase = createClient();
    void supabase.from("network_depots").select("code, name").eq("network_id", context.network.id).order("name").then(({ data }) => {
      setDepots((data ?? []).map((depot) => ({ code: depot.code as string, name: depot.name as string })));
    });
  }, [context.network.id]);

  async function addDepot() {
    if (!depotName.trim() || !depotCode.trim()) return;
    setLoading(true); setError(null);
    const supabase = createClient();
    const code = depotCode.trim().toUpperCase();
    const { error: insertError } = await supabase.from("network_depots").insert({
      network_id: context.network.id,
      code,
      name: depotName.trim(),
    });
    setLoading(false);
    if (insertError) return setError(insertError.message);
    setDepots((items) => [...items, { code, name: depotName.trim() }]);
    setDepotCode(""); setDepotName("");
  }

  async function addLine() {
    if (!lineValid) return;
    setLoading(true); setError(null);
    const supabase = createClient();
    const base = createCustomRegulationLine({
      shortName: lineShortName,
      origin: lineOrigin,
      destination: lineDestination,
      transportType: "bus",
      depotCode: depots[0]?.code ?? "NETWORK",
    });
    const lineId = lineShortName.trim();
    const data = { ...base, id: `network:${context.network.id}:${lineId}`, routeId: lineId };
    const { error: insertError } = await supabase.from("network_lines").upsert({
      network_id: context.network.id,
      line_id: lineId,
      short_name: lineId,
      long_name: `${lineOrigin.trim()} ↔ ${lineDestination.trim()}`,
      transport_mode: "bus",
      color: base.lineColor,
      source: "manual",
      data,
    }, { onConflict: "network_id,line_id" });
    setLoading(false);
    if (insertError) return setError(insertError.message);
    setCreatedLine(lineId);
  }

  async function importGtfs() {
    if (!file) return;
    setLoading(true); setError(null); setImportResult(null);
    const body = new FormData(); body.set("file", file);
    const response = await fetch("/api/network/gtfs-import", { method: "POST", body });
    const result = await response.json() as { error?: string; routeCount?: number; stopCount?: number };
    setLoading(false);
    if (!response.ok) return setError(result.error ?? "Import impossible");
    setImportResult(`${result.routeCount ?? 0} lignes et ${result.stopCount ?? 0} arrêts validés`);
  }

  async function finish() {
    setLoading(true); setError(null);
    const supabase = createClient();
    const { error: rpcError } = await supabase.rpc("complete_network_setup", {
      p_network_id: context.network.id,
      p_name: name.trim(),
      p_operator: operator.trim(),
      p_territory: territory.trim(),
    });
    setLoading(false);
    if (rpcError) return setError(rpcError.message);
    setStep("done");
  }

  return (
    <main className="min-h-screen bg-[#020817] px-5 py-10 text-white">
      <div className="mx-auto max-w-3xl">
        <div className="mb-8 flex items-center justify-between">
          <div className="flex items-center gap-3"><Network className="text-[#33BFA3]" /><div><p className="font-bold">Aule Pro</p><p className="text-xs text-slate-500">Configuration du réseau</p></div></div>
          {context.network.setupCompletedAt && <Link href="/dashboard" className="text-sm text-slate-400 hover:text-white"><ArrowLeft className="mr-1 inline h-4 w-4" />Tableau de bord</Link>}
        </div>
        <div className="mb-8 flex gap-2">{[0, 1, 2, 3].map((index) => <span key={index} className={`h-1 flex-1 rounded ${index <= stepIndex ? "bg-[#33BFA3]" : "bg-white/10"}`} />)}</div>
        <section className="rounded-2xl border border-white/10 bg-[#071225] p-6 shadow-2xl md:p-9">
          {step === "identity" && <>
            <Building2 className="mb-4 text-[#33BFA3]" /><h1 className="text-2xl font-bold">Identité de votre réseau</h1><p className="mt-2 text-sm text-slate-400">Ces informations remplaceront les libellés du réseau pilote dans votre espace.</p>
            <div className="mt-7 grid gap-5"><Field label="Nom du réseau" value={name} onChange={setName} placeholder="Réseau Astuce" /><Field label="Exploitant ou opérateur" value={operator} onChange={setOperator} placeholder="Métropole Mobilités" /><Field label="Territoire desservi" value={territory} onChange={setTerritory} placeholder="Ville, métropole ou département" /></div>
            <Primary disabled={!identityValid} onClick={() => setStep("depots")}>Continuer</Primary>
          </>}
          {step === "depots" && <>
            <MapPin className="mb-4 text-[#33BFA3]" /><h1 className="text-2xl font-bold">Dépôts et sites d’exploitation</h1><p className="mt-2 text-sm text-slate-400">Ajoutez au moins les sites utiles à vos lignes. Cette étape peut être complétée plus tard.</p>
            <div className="mt-7 grid gap-4 md:grid-cols-2"><Field label="Code" value={depotCode} onChange={setDepotCode} placeholder="DEPOT-NORD" /><Field label="Nom" value={depotName} onChange={setDepotName} placeholder="Dépôt Nord" /></div>
            <button onClick={() => void addDepot()} disabled={loading || !depotCode.trim() || !depotName.trim()} className="mt-4 rounded-lg border border-[#33BFA3]/40 px-4 py-2 text-sm text-[#5fe0c4] disabled:opacity-40">Ajouter le dépôt</button>
            {depots.map((depot) => <div key={depot.code} className="mt-3 rounded-lg bg-white/5 px-4 py-3 text-sm"><Check className="mr-2 inline h-4 w-4 text-[#33BFA3]" />{depot.code} · {depot.name}</div>)}
            <Primary onClick={() => setStep("data")}>Continuer</Primary>
          </>}
          {step === "data" && <>
            <Database className="mb-4 text-[#33BFA3]" /><h1 className="text-2xl font-bold">Premières données réseau</h1><p className="mt-2 text-sm text-slate-400">Créez une première ligne ou importez votre GTFS statique. Vous pourrez utiliser les deux méthodes ensuite.</p>
            <div className="mt-7 grid gap-5 rounded-xl border border-white/10 p-5"><div className="flex items-center gap-2 font-semibold"><Bus className="h-5 w-5 text-blue-400" />Créer une ligne manuellement</div><div className="grid gap-4 md:grid-cols-3"><Field label="N° de ligne" value={lineShortName} onChange={setLineShortName} placeholder="A1" /><Field label="Origine" value={lineOrigin} onChange={setLineOrigin} placeholder="Gare" /><Field label="Destination" value={lineDestination} onChange={setLineDestination} placeholder="Centre" /></div><button onClick={() => void addLine()} disabled={loading || !lineValid} className="w-fit rounded-lg bg-blue-600 px-4 py-2 text-sm font-semibold disabled:opacity-40">Créer la ligne</button>{createdLine && <p className="text-sm text-emerald-400">Ligne {createdLine} créée et enregistrée.</p>}</div>
            <div className="mt-5 rounded-xl border border-white/10 p-5"><div className="flex items-center gap-2 font-semibold"><Upload className="h-5 w-5 text-violet-400" />Importer un GTFS</div><p className="mt-2 text-xs text-slate-500">ZIP de 50 Mo maximum contenant routes.txt, stops.txt, trips.txt et stop_times.txt.</p><input type="file" accept=".zip,application/zip" onChange={(event) => setFile(event.target.files?.[0] ?? null)} className="mt-4 block w-full text-sm text-slate-300" /><button onClick={() => void importGtfs()} disabled={loading || !file} className="mt-4 rounded-lg bg-violet-600 px-4 py-2 text-sm font-semibold disabled:opacity-40">Valider et importer</button>{importResult && <p className="mt-3 text-sm text-emerald-400">{importResult}</p>}</div>
            <Primary onClick={() => void finish()}>Terminer la configuration</Primary>
          </>}
          {step === "done" && <div className="py-10 text-center"><span className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-emerald-400/15 text-emerald-300"><Check className="h-8 w-8" /></span><h1 className="mt-6 text-2xl font-bold">Votre réseau est prêt</h1><p className="mt-2 text-slate-400">Le poste de contrôle affichera uniquement les données de {name}.</p><button onClick={() => { router.push("/dashboard"); router.refresh(); }} className="mt-8 rounded-xl bg-[#33BFA3] px-6 py-3 font-bold text-[#03231d]">Ouvrir le poste de contrôle</button></div>}
          {error && <p role="alert" className="mt-5 rounded-lg border border-red-400/20 bg-red-400/10 p-3 text-sm text-red-200">{error}</p>}
          {loading && <p className="mt-4 text-sm text-slate-400"><Loader2 className="mr-2 inline h-4 w-4 animate-spin" />Enregistrement…</p>}
        </section>
      </div>
    </main>
  );
}

function Field({ label, value, onChange, placeholder }: { label: string; value: string; onChange: (value: string) => void; placeholder: string }) {
  return <label className="grid gap-2 text-sm text-slate-300"><span>{label}</span><input value={value} onChange={(event) => onChange(event.target.value)} placeholder={placeholder} className="rounded-lg border border-white/10 bg-black/20 px-3 py-2.5 text-white outline-none focus:border-[#33BFA3]" /></label>;
}

function Primary({ children, disabled, onClick }: { children: React.ReactNode; disabled?: boolean; onClick: () => void }) {
  return <button onClick={onClick} disabled={disabled} className="mt-8 w-full rounded-xl bg-[#33BFA3] px-5 py-3 font-bold text-[#03231d] disabled:opacity-40">{children}</button>;
}
