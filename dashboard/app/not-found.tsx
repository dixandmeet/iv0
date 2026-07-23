import Link from "next/link";

export default function NotFound() {
  return (
    <main className="flex min-h-screen items-center justify-center bg-[#050908] px-6 text-white">
      <div className="w-full max-w-xl text-center">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-[#78dfca]">Erreur 404</p>
        <h1 className="mt-5 text-4xl font-bold tracking-tight sm:text-6xl">Cette page n&apos;existe pas.</h1>
        <p className="mx-auto mt-5 max-w-lg text-base leading-7 text-white/60">
          Le lien a peut-être changé ou la page n&apos;est pas encore disponible. Revenez à l&apos;accueil ou connectez-vous à votre espace professionnel.
        </p>
        <div className="mt-8 flex flex-col justify-center gap-3 sm:flex-row">
          <Link className="rounded-full bg-[#33bfa3] px-6 py-3 font-semibold text-[#04211c] transition hover:bg-[#8deedd]" href="/">
            Retour à l&apos;accueil
          </Link>
          <Link className="rounded-full border border-white/15 bg-white/5 px-6 py-3 font-semibold text-white transition hover:bg-white/10" href="/login">
            Connexion au dashboard
          </Link>
        </div>
      </div>
    </main>
  );
}
