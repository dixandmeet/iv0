"use client";

import { useEffect } from "react";
import Link from "next/link";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    void fetch("/api/client-errors", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      keepalive: true,
      body: JSON.stringify({
        type: "global-render-error",
        message: error.message,
        digest: error.digest,
        path: window.location.pathname,
      }),
    }).catch(() => undefined);
  }, [error]);

  return (
    <html lang="fr">
      <body className="m-0 bg-[#050908] font-sans text-white">
        <main className="flex min-h-screen items-center justify-center px-6">
          <div className="max-w-lg text-center">
            <p className="text-sm font-bold uppercase tracking-[0.2em] text-[#78dfca]">Incident technique</p>
            <h1 className="mt-5 text-4xl font-bold">Aule a rencontré une erreur.</h1>
            <p className="mt-5 leading-7 text-white/60">L&apos;incident a été enregistré. Vous pouvez réessayer ou revenir à l&apos;accueil.</p>
            <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
              <button className="rounded-full bg-[#33bfa3] px-6 py-3 font-semibold text-[#04211c]" onClick={reset}>Réessayer</button>
              <Link className="rounded-full border border-white/15 px-6 py-3 font-semibold text-white" href="/">Accueil</Link>
            </div>
          </div>
        </main>
      </body>
    </html>
  );
}
