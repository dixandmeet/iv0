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
    confirmed?: string;
    account?: string;
  }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const params = await searchParams;
  const initialError =
    params.error === "access_pending"
      ? "Votre compte est confirmé, mais votre habilitation au dashboard est encore en attente de validation."
      : params.error === "mobile_only"
        ? "Ce profil Aule Pro s’utilise dans l’application mobile et n’ouvre pas le dashboard web."
      : params.error === "unauthorized"
      ? "Ce compte n'a pas accès au poste de contrôle. Seuls les profils régulateur, superviseur MSR ou administrateur sont autorisés."
      : null;
  const initialMode = params.mode === "pro" ? "pro" : "voyageur";
  const initialSuccess =
    params.reset === "success"
      ? "Votre mot de passe a été mis à jour. Vous pouvez maintenant vous connecter."
      : params.confirmed === "1"
        ? "Votre adresse e-mail a bien été confirmée. Vous pouvez maintenant vous connecter."
      : params.account === "deactivated"
        ? "Votre compte a été désactivé. Contactez votre administrateur pour le réactiver."
      : params.account === "deleted"
        ? "Votre compte et vos données personnelles ont été supprimés."
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
