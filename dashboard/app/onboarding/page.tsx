import type { Metadata } from "next";
import { OnboardingWizard } from "@/components/onboarding/onboarding-wizard";

export const metadata: Metadata = {
  title: "Configurer votre espace — Aule Pro",
  description: "Configurez votre profil professionnel Aule Pro en quelques instants.",
};

export default function OnboardingPage() {
  return <OnboardingWizard />;
}
