import { LandingDownload } from "./landing-download";
import { LandingFeatures } from "./landing-features";
import { LandingFooter } from "./landing-footer";
import { LandingHeader } from "./landing-header";
import { LandingHero } from "./landing-hero";
import { LandingImmersive } from "./landing-immersive";
import { LandingNetworks } from "./landing-networks";
import { LandingProblem } from "./landing-problem";
import { LandingProCta } from "./landing-pro-cta";
import { LandingSolution } from "./landing-solution";
import { LandingTestimonials } from "./landing-testimonials";

export function LandingPage() {
  return (
    <div className="min-h-screen bg-background">
      <a href="#main-content" className="skip-link">
        Aller au contenu principal
      </a>
      <LandingHeader />
      <main id="main-content">
        <LandingHero />
        <LandingProblem />
        <LandingSolution />
        <LandingFeatures />
        <LandingImmersive />
        <LandingNetworks />
        <LandingProCta />
        <LandingTestimonials />
        <LandingDownload />
      </main>
      <LandingFooter />
    </div>
  );
}
