type AuthErrorLike = {
  code?: string;
  message?: string;
  status?: number;
};

const AUTH_ERROR_MESSAGES: Record<string, string> = {
  email_address_invalid: "Cette adresse e-mail n’est pas valide.",
  email_not_confirmed:
    "Votre adresse e-mail n’a pas encore été confirmée. Consultez votre boîte mail.",
  invalid_credentials: "E-mail ou mot de passe incorrect.",
  over_email_send_rate_limit:
    "Trop de messages ont été envoyés. Patientez quelques minutes avant de réessayer.",
  same_password:
    "Choisissez un mot de passe différent de votre mot de passe actuel.",
  session_not_found:
    "Votre lien n’est plus valide. Demandez un nouveau lien de réinitialisation.",
  weak_password:
    "Ce mot de passe est trop faible. Utilisez au moins 8 caractères.",
};

export function getAuthErrorMessage(
  error: AuthErrorLike | null | undefined,
  fallback = "Une erreur est survenue. Réessayez dans un instant.",
) {
  if (!error) return fallback;

  if (error.code && AUTH_ERROR_MESSAGES[error.code]) {
    return AUTH_ERROR_MESSAGES[error.code];
  }

  if (error.status === 429) {
    return "Trop de tentatives ont été effectuées. Patientez quelques minutes avant de réessayer.";
  }

  return fallback;
}
