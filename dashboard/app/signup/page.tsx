import type { Metadata } from "next";
import { SignupForm } from "./signup-form";

export const metadata: Metadata = {
  title: "Créer un compte — Aule",
  description:
    "Créez votre compte Aule pour suivre vos transports en temps réel, ou demandez un accès Aule Pro.",
};

type SignupPageProps = {
  searchParams: Promise<{ mode?: string }>;
};

export default async function SignupPage({ searchParams }: SignupPageProps) {
  const params = await searchParams;
  const initialMode = params.mode === "pro" ? "pro" : "voyageur";

  return <SignupForm initialMode={initialMode} />;
}
