import type { Metadata } from "next";
import { ForgotPasswordForm } from "./forgot-password-form";

export const metadata: Metadata = {
  title: "Mot de passe oublié — Aule",
  description:
    "Recevez un lien sécurisé pour réinitialiser le mot de passe de votre compte Aule.",
};

type ForgotPasswordPageProps = {
  searchParams: Promise<{ email?: string; mode?: string }>;
};

export default async function ForgotPasswordPage({
  searchParams,
}: ForgotPasswordPageProps) {
  const params = await searchParams;

  return (
    <ForgotPasswordForm
      initialEmail={params.email ?? ""}
      mode={params.mode === "pro" ? "pro" : "voyageur"}
    />
  );
}
