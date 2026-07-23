"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import Image from "next/image";
import { ArrowRight, Check, RefreshCw, TriangleAlert } from "lucide-react";
import { createClient } from "@/lib/supabase/client";

const REDIRECT_SECONDS = 6;

export function EmailConfirmationResult({
  success,
  authenticated,
  destination,
  error,
}: {
  success: boolean;
  authenticated: boolean;
  destination: string;
  error: string | null;
}) {
  const router = useRouter();
  const [seconds, setSeconds] = useState(REDIRECT_SECONDS);
  const [returningToLogin, setReturningToLogin] = useState(false);

  useEffect(() => {
    if (!success) return;
    const timer = window.setInterval(() => {
      setSeconds((current) => Math.max(0, current - 1));
    }, 1000);
    return () => window.clearInterval(timer);
  }, [success]);

  useEffect(() => {
    if (!success || seconds !== 0) return;
    router.replace(destination);
    router.refresh();
  }, [destination, router, seconds, success]);

  async function returnToLogin() {
    if (returningToLogin) return;
    setReturningToLogin(true);
    const supabase = createClient();
    await supabase.auth.signOut();
    router.replace("/login?mode=pro");
    router.refresh();
  }

  return (
    <main className="relative flex min-h-screen items-center justify-center overflow-hidden bg-[#020817] px-5 py-10 text-white">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_50%_20%,rgba(51,191,163,0.14),transparent_42%)]" />
      <div className="relative w-full max-w-lg rounded-3xl border border-white/10 bg-[#071225]/95 p-7 text-center shadow-2xl shadow-black/40 md:p-10">
        <Link href="/" className="mb-9 inline-flex items-center gap-2 text-lg font-bold tracking-tight">
          <Image
            src="/aule-logo.png"
            alt="Logo Aule"
            width={40}
            height={40}
            className="h-10 w-10 rounded-xl object-cover"
            priority
          />
          Aule
        </Link>

        {success ? (
          <>
            <span className="mx-auto flex h-20 w-20 items-center justify-center rounded-full border border-emerald-300/20 bg-emerald-400/10 text-emerald-300">
              <Check className="h-10 w-10" strokeWidth={2.4} />
            </span>
            <h1 className="mt-7 text-2xl font-bold md:text-3xl">Adresse e-mail confirmée</h1>
            <p className="mx-auto mt-3 max-w-sm text-sm leading-6 text-slate-400">
              Votre adresse a bien été vérifiée et votre compte Aule est maintenant actif.
            </p>

            <div className="mx-auto mt-8 flex h-24 w-24 items-center justify-center rounded-full border-4 border-white/10 text-3xl font-bold text-[#5fe0c4]">
              {seconds}
            </div>
            <p className="mt-4 text-xs text-slate-500">
              Redirection vers {authenticated ? "votre tableau de bord" : "la page de connexion"}…
            </p>

            <button
              type="button"
              onClick={() => {
                router.replace(destination);
                router.refresh();
              }}
              className="mt-8 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-[#33BFA3] px-5 py-3 font-bold text-[#03231d] transition hover:bg-[#5fe0c4]"
            >
              {authenticated ? "Accéder au tableau de bord" : "Se connecter"}
              <ArrowRight className="h-4 w-4" />
            </button>
          </>
        ) : (
          <>
            <span className="mx-auto flex h-20 w-20 items-center justify-center rounded-full border border-amber-300/20 bg-amber-400/10 text-amber-300">
              <TriangleAlert className="h-9 w-9" />
            </span>
            <h1 className="mt-7 text-2xl font-bold">Confirmation impossible</h1>
            <p className="mx-auto mt-3 max-w-sm text-sm leading-6 text-slate-400">
              {error || "Ce lien est invalide, incomplet ou a déjà expiré."}
            </p>
            <button
              type="button"
              onClick={() => void returnToLogin()}
              disabled={returningToLogin}
              className="mt-8 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-white/10 px-5 py-3 font-semibold text-white transition hover:bg-white/15"
            >
              <RefreshCw className={`h-4 w-4${returningToLogin ? " animate-spin" : ""}`} />
              {returningToLogin ? "Déconnexion…" : "Retourner à la connexion"}
            </button>
          </>
        )}
      </div>
    </main>
  );
}
