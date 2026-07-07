"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  AlertTriangle,
  Check,
  Eye,
  EyeOff,
  Loader2,
  LockKeyhole,
} from "lucide-react";
import { AuthShell } from "@/components/auth/auth-shell";
import { AuthNetworkPanel } from "@/components/auth/auth-network-panel";
import { createClient } from "@/lib/supabase/client";
import { getAuthErrorMessage } from "@/lib/auth-errors";
import styles from "@/components/auth/auth-form.module.css";

type RecoveryState = "checking" | "ready" | "invalid";

export function UpdatePasswordForm() {
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const [recoveryState, setRecoveryState] =
    useState<RecoveryState>("checking");
  const [password, setPassword] = useState("");
  const [confirmation, setConfirmation] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const passwordIsLongEnough = password.length >= 8;
  const passwordsMatch =
    confirmation.length > 0 && password === confirmation;
  const canSubmit = passwordIsLongEnough && passwordsMatch && !loading;

  useEffect(() => {
    let active = true;

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, session) => {
      if (
        active &&
        session &&
        (event === "PASSWORD_RECOVERY" ||
          event === "SIGNED_IN" ||
          event === "INITIAL_SESSION")
      ) {
        setRecoveryState("ready");
      }
    });

    async function verifyRecoverySession() {
      const hash = new URLSearchParams(window.location.hash.slice(1));
      const hashError = hash.get("error_description");

      if (hashError) {
        if (active) setRecoveryState("invalid");
        return;
      }

      const {
        data: { session },
      } = await supabase.auth.getSession();

      if (!active) return;
      setRecoveryState(session ? "ready" : "invalid");
    }

    void verifyRecoverySession();

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, [supabase]);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (!canSubmit) return;

    setLoading(true);
    setError(null);

    const { error: authError } = await supabase.auth.updateUser({ password });

    if (authError) {
      setError(
        getAuthErrorMessage(
          authError,
          "Le mot de passe n’a pas pu être modifié. Demandez un nouveau lien et réessayez.",
        ),
      );
      setLoading(false);
      return;
    }

    await supabase.auth.signOut({ scope: "local" });
    router.replace("/login?reset=success");
    router.refresh();
  }

  return (
    <AuthShell
      brandPanel={
        <AuthNetworkPanel
          heading={
            <>
              Votre compte
              <br />
              reprend la route.
            </>
          }
          tagline="Choisissez un nouveau mot de passe pour retrouver vos trajets, favoris et outils Aule."
          footnote="Lien personnel et vérifié par Aule"
          mainPath="M-20 720 L120 700 L220 560 L300 520 L420 380 L520 300 L640 220"
          secondaryPath="M-20 800 L160 780 L320 640 L640 600"
          accentDot={{ cx: 420, cy: 380 }}
          fadedDots={[
            { cx: 300, cy: 520, opacity: 0.85 },
            { cx: 120, cy: 700, opacity: 0.6 },
          ]}
          vignettePosition="30% 30%"
        />
      }
    >
      {recoveryState === "checking" && (
        <div className={styles.statusHero} role="status">
          <span className={styles.statusIcon}>
            <Loader2 size={24} className={styles.spinner} />
          </span>
          <h2 className={styles.title}>Vérification du lien…</h2>
          <p className={styles.statusText}>
            Nous sécurisons l’accès à votre compte.
          </p>
        </div>
      )}

      {recoveryState === "invalid" && (
        <div className={styles.statusHero}>
          <span className={`${styles.statusIcon} ${styles.statusIconError}`}>
            <AlertTriangle size={24} />
          </span>
          <h2 className={styles.title}>Ce lien n’est plus valide</h2>
          <p className={styles.statusText}>
            Il a peut-être expiré ou déjà été utilisé. Demandez un nouveau lien
            pour reprendre la procédure.
          </p>
          <Link
            href="/forgot-password"
            data-hover
            className={styles.submitLink}
          >
            Demander un nouveau lien
          </Link>
          <Link href="/login" data-hover className={styles.textLink}>
            Retour à la connexion
          </Link>
        </div>
      )}

      {recoveryState === "ready" && (
        <>
          <span className={styles.eyebrow}>
            <LockKeyhole size={15} />
            Accès vérifié
          </span>
          <h2 className={styles.title}>Choisissez un nouveau mot de passe</h2>
          <p className={styles.subtitle}>
            Utilisez au moins 8 caractères et évitez un mot de passe déjà
            employé ailleurs.
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
              <span className={styles.fieldLabel}>Nouveau mot de passe</span>
              <div className={styles.inputWrap}>
                <input
                  type={showPassword ? "text" : "password"}
                  required
                  minLength={8}
                  autoFocus
                  autoComplete="new-password"
                  placeholder="8 caractères minimum"
                  value={password}
                  onChange={(event) => setPassword(event.target.value)}
                  className={`${styles.input} ${styles.inputWithToggle}`}
                />
                <button
                  type="button"
                  data-hover
                  onClick={() => setShowPassword((visible) => !visible)}
                  className={styles.eyeButton}
                  aria-label={
                    showPassword
                      ? "Masquer le nouveau mot de passe"
                      : "Afficher le nouveau mot de passe"
                  }
                >
                  {showPassword ? <EyeOff size={19} /> : <Eye size={19} />}
                </button>
              </div>
            </label>

            <label className={styles.field}>
              <span className={styles.fieldLabel}>
                Confirmer le mot de passe
              </span>
              <div className={styles.inputWrap}>
                <input
                  type={showConfirmation ? "text" : "password"}
                  required
                  minLength={8}
                  autoComplete="new-password"
                  placeholder="Saisissez-le à nouveau"
                  value={confirmation}
                  onChange={(event) => setConfirmation(event.target.value)}
                  className={`${styles.input} ${styles.inputWithToggle}`}
                  aria-invalid={
                    confirmation.length > 0 && !passwordsMatch
                      ? "true"
                      : "false"
                  }
                />
                <button
                  type="button"
                  data-hover
                  onClick={() => setShowConfirmation((visible) => !visible)}
                  className={styles.eyeButton}
                  aria-label={
                    showConfirmation
                      ? "Masquer la confirmation"
                      : "Afficher la confirmation"
                  }
                >
                  {showConfirmation ? (
                    <EyeOff size={19} />
                  ) : (
                    <Eye size={19} />
                  )}
                </button>
              </div>
            </label>

            <div className={styles.passwordRules} aria-live="polite">
              <span className={passwordIsLongEnough ? styles.ruleMet : ""}>
                <Check size={14} />
                8 caractères minimum
              </span>
              <span className={passwordsMatch ? styles.ruleMet : ""}>
                <Check size={14} />
                Les deux mots de passe correspondent
              </span>
            </div>

            <button
              type="submit"
              data-hover
              disabled={!canSubmit}
              className={styles.submitButton}
            >
              {loading ? (
                <>
                  <Loader2 size={17} className={styles.spinner} />
                  Mise à jour…
                </>
              ) : (
                "Mettre à jour le mot de passe"
              )}
            </button>
          </form>
        </>
      )}
    </AuthShell>
  );
}
