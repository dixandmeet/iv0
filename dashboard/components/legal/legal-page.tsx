import Link from "next/link";
import type { ReactNode } from "react";

type LegalPageProps = {
  title: string;
  eyebrow: string;
  description: string;
  sections: Array<{
    title: string;
    body: ReactNode;
  }>;
};

export function LegalPage({ title, eyebrow, description, sections }: LegalPageProps) {
  return (
    <main className="min-h-screen bg-[#050908] text-white">
      <section className="mx-auto flex w-full max-w-4xl flex-col gap-10 px-6 py-10 sm:px-8 sm:py-14 lg:py-20">
        <nav aria-label="Navigation secondaire">
          <Link
            href="/"
            className="inline-flex items-center rounded-full border border-white/10 px-4 py-2 text-sm font-semibold text-white/70 transition hover:border-[#33bfa3]/40 hover:text-[#33bfa3]"
          >
            Retour à l&apos;accueil
          </Link>
        </nav>

        <header className="max-w-3xl">
          <p className="mb-4 text-xs font-bold uppercase tracking-[0.18em] text-[#33bfa3]">
            {eyebrow}
          </p>
          <h1 className="text-4xl font-bold leading-tight tracking-normal sm:text-5xl">
            {title}
          </h1>
          <p className="mt-5 text-base leading-8 text-white/64 sm:text-lg">
            {description}
          </p>
        </header>

        <div className="grid gap-4">
          {sections.map((section) => (
            <section
              key={section.title}
              className="rounded-2xl border border-white/10 bg-white/[0.035] p-5 sm:p-6"
            >
              <h2 className="text-lg font-bold tracking-normal text-white">
                {section.title}
              </h2>
              <p className="mt-3 text-sm leading-7 text-white/62">{section.body}</p>
            </section>
          ))}
        </div>

        <footer className="border-t border-white/10 pt-6 text-sm text-white/48">
          Dernière mise à jour : juillet 2026 · Contact :{" "}
          <a className="text-[#33bfa3] hover:text-white" href="mailto:contact@aule.fr">
            contact@aule.fr
          </a>
        </footer>
      </section>
    </main>
  );
}
