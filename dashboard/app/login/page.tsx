import type { Metadata } from "next";
import { LoginForm } from "./login-form";

export const metadata: Metadata = {
  title: "Connexion — Aule",
  description:
    "Connectez-vous à Aule, en tant que voyageur ou pour accéder au poste de contrôle Aule Pro.",
};

type LoginPageProps = {
  searchParams: Promise<{
    error?: string;
    mode?: string;
    reset?: string;
    next?: string;
  }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const initialError =
    params.error === "unauthorized"
      ? "Ce compte n'a pas accès au poste de contrôle. Seuls les profils régulateur, superviseur MSR ou administrateur sont autorisés."
      : null;
  const initialMode = params.mode === "pro" ? "pro" : "voyageur";
  const initialSuccess =
    params.reset === "success"
      ? "Votre mot de passe a été mis à jour. Vous pouvez maintenant vous connecter."
      : null;
  const redirectTo =
    typeof params.next === "string" && params.next.startsWith("/")
      ? params.next
      : undefined;

  return (
    <LoginForm
      initialError={initialError}
      initialSuccess={initialSuccess}
      initialMode={initialMode}
      redirectTo={redirectTo}
    />
  );
}
