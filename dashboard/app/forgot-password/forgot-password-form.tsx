"use client";

import { useState } from "react";
import Link from "next/link";
import { ArrowLeft, Loader2, MailCheck } from "lucide-react";
import { AuthShell } from "@/components/auth/auth-shell";
import { AuthNetworkPanel } from "@/components/auth/auth-network-panel";
import { createClient } from "@/lib/supabase/client";
import { getAuthErrorMessage } from "@/lib/auth-errors";
import styles from "@/components/auth/auth-form.module.css";

type ForgotPasswordFormProps = {
  initialEmail?: string;
  mode?: "voyageur" | "pro";
};

export function ForgotPasswordForm({
  initialEmail = "",
  mode = "voyageur",
}: ForgotPasswordFormProps) {
  const [email, setEmail] = useState(initialEmail);
  const [sentTo, setSentTo] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const loginHref = mode === "pro" ? "/login?mode=pro" : "/login";

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    const normalizedEmail = email.trim().toLowerCase();

    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error: authError } = await supabase.auth.resetPasswordForEmail(
      normalizedEmail,
      {
        redirectTo: `${window.location.origin}/update-password`,
      },
    );

    if (authError) {
      setError(
        getAuthErrorMessage(
          authError,
          "Le lien n’a pas pu être envoyé. Vérifiez l’adresse puis réessayez.",
        ),
      );
      setLoading(false);
      return;
    }

    setSentTo(normalizedEmail);
    setLoading(false);
  }

  return (
    <AuthShell
      brandPanel={
        <AuthNetworkPanel
          heading={
            <>
              Un détour,
              <br />
              pas une impasse.
            </>
          }
          tagline="Quelques secondes suffisent pour retrouver votre compte et reprendre votre trajet."
          footnote="Votre accès reste protégé pendant toute la procédure"
          mainPath="M-20 720 L120 700 L220 560 L300 520 L420 380 L520 300 L640 220"
          secondaryPath="M-20 800 L160 780 L320 640 L640 600"
          accentDot={{ cx: 300, cy: 520 }}
          fadedDots={[
            { cx: 420, cy: 380, opacity: 0.85 },
            { cx: 120, cy: 700, opacity: 0.6 },
          ]}
          vignettePosition="30% 30%"
        />
      }
    >
      <Link href={loginHref} data-hover className={styles.backLink}>
        <ArrowLeft size={16} />
        Retour à la connexion
      </Link>

      {sentTo ? (
        <div className={styles.statusHero}>
          <span className={styles.statusIcon}>
            <MailCheck size={24} />
          </span>
          <h2 className={styles.title}>Consultez votre boîte mail</h2>
          <p className={styles.statusText}>
            Si un compte correspond à <strong>{sentTo}</strong>, vous recevrez
            un lien pour choisir un nouveau mot de passe.
          </p>
          <p className={styles.helperText}>
            Le message peut prendre quelques minutes. Pensez aussi à vérifier
            vos courriers indésirables.
          </p>
          <button
            type="button"
            data-hover
            className={styles.secondaryButton}
            onClick={() => {
              setSentTo(null);
              setError(null);
            }}
          >
            Modifier l’adresse
          </button>
        </div>
      ) : (
        <>
          <h2 className={styles.title}>Mot de passe oublié ?</h2>
          <p className={styles.subtitle}>
            Indiquez l’adresse liée à votre compte. Nous vous enverrons un lien
            de réinitialisation sécurisé.
          </p>

          {error && (
            <p className={styles.alertError} role="alert">
              {error}
            </p>
          )}

          <form
            onSubmit={handleSubmit}
            className={`${styles.form} ${styles.recoveryForm}`}
          >
            <label className={styles.field}>
              <span className={styles.fieldLabel}>E-mail</span>
              <input
                type="email"
                required
                autoFocus
                autoComplete="email"
                placeholder="vous@exemple.com"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                className={styles.input}
              />
            </label>

            <button
              type="submit"
              data-hover
              disabled={loading || email.trim() === ""}
              className={styles.submitButton}
            >
              {loading ? (
                <>
                  <Loader2 size={17} className={styles.spinner} />
                  Envoi…
                </>
              ) : (
                "Envoyer le lien"
              )}
            </button>
          </form>

          <p className={styles.privacyNote}>
            Pour votre sécurité, nous affichons la même confirmation que
            l’adresse soit associée ou non à un compte.
          </p>
        </>
      )}
    </AuthShell>
  );
}
