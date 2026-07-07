// Exemple d'intégration dans app/page.tsx — remplacez votre <section> hero
// actuelle par <ScrollVideoHero> et déplacez son contenu texte en children.

import ScrollVideoHero from "@/components/ScrollVideoHero";

export default function Home() {
  return (
    <main>
      <ScrollVideoHero src="/hero-scroll.mp4" scrollLength={3}>
        {/* ⬇️ votre contenu hero existant, inchangé, simplement déplacé ici */}
        <div className="flex h-full flex-col items-center justify-center px-6 text-center text-white">
          <h1 className="max-w-3xl text-5xl font-semibold tracking-tight md:text-7xl">
            Votre titre existant
          </h1>
          <p className="mt-6 max-w-xl text-lg text-white/80">
            Votre sous-titre existant.
          </p>
        </div>
      </ScrollVideoHero>

      {/* Le reste de la page continue normalement après les 300vh */}
      <section className="mx-auto max-w-4xl px-6 py-24">…</section>
    </main>
  );
}
