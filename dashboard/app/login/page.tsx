import type { Metadata } from "next";
import { LoginForm } from "./login-form";

export const metadata: Metadata = {
  title: "Connexion",
  description:
    "Connectez-vous ou créez un compte pour accéder au poste de contrôle Aule.",
};

type LoginPageProps = {
  searchParams: Promise<{ error?: string }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const initialError =
    params.error === "unauthorized"
      ? "Ce compte n'a pas accès au poste de contrôle."
      : null;

  return <LoginForm initialError={initialError} />;
}
