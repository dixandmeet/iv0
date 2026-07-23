import { headers } from "next/headers";
import { Space_Grotesk } from "next/font/google";
import { LandingClassic } from "./landing-classic";
import { ScrollyLanding } from "./scrolly-landing";

const spaceGrotesk = Space_Grotesk({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-space-grotesk",
  display: "swap",
});

/**
 * Téléphone : version classique empilée (sans scrollytelling).
 * Tablette / ordinateur : version immersive scrollytelling.
 * Détection par User-Agent côté serveur (l'utilisateur « sur son téléphone »),
 * pas par largeur de fenêtre — évite tout double rendu de carte et tout
 * décalage d'hydratation.
 */
function isMobilePhone(userAgent: string): boolean {
  if (/iPhone|iPod/i.test(userAgent)) return true;
  // Les tablettes Android n'ont pas le token « Mobile » ; iPad → non plus.
  if (/Android/i.test(userAgent) && /Mobile/i.test(userAgent)) return true;
  return /Windows Phone|BlackBerry|BB10|Opera Mini|IEMobile/i.test(userAgent);
}

export async function LandingPage() {
  const userAgent = (await headers()).get("user-agent") ?? "";

  if (isMobilePhone(userAgent)) {
    return <LandingClassic fontClassName={spaceGrotesk.variable} />;
  }

  return <ScrollyLanding fontClassName={spaceGrotesk.variable} />;
}
