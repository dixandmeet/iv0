"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Eye, EyeOff, Loader2, Check, CheckCircle2 } from "lucide-react";
import { AuthShell } from "@/components/auth/auth-shell";
import { AuthNetworkPanel } from "@/components/auth/auth-network-panel";
import { createClient } from "@/lib/supabase/client";
import { getAuthErrorMessage } from "@/lib/auth-errors";
import { WEB_STAFF_ROLES, type StaffRole } from "@/lib/types";
import styles from "@/components/auth/auth-form.module.css";

type LoginMode = "voyageur" | "pro";

const UNAUTHORIZED_MESSAGE =
  "Ce compte n'a pas accès au poste de contrôle. Seuls les profils régulateur, superviseur MSR ou administrateur sont autorisés.";

type LoginFormProps = {
  initialError?: string | null;
  initialSuccess?: string | null;
  initialMode?: LoginMode;
};

async function assertStaffAccess(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<string | null> {
  const { data: profile } = await supabase
    .from("user_profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  const role = (profile?.role as StaffRole | undefined) ?? "passenger";
  if (WEB_STAFF_ROLES.includes(role)) return null;

  await supabase.auth.signOut();
  return UNAUTHORIZED_MESSAGE;
}

export function LoginForm({
  initialError = null,
  initialSuccess = null,
  initialMode = "voyageur",
}: LoginFormProps) {
  const router = useRouter();

  const [mode, setMode] = useState<LoginMode>(initialMode);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [remember, setRemember] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(initialError);
  const [success, setSuccess] = useState<string | null>(initialSuccess);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(null);

    const supabase = createClient();
    const { data, error: authError } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (authError) {
      setError(getAuthErrorMessage(authError));
      setLoading(false);
      return;
    }

    if (mode === "pro") {
      const accessError = await assertStaffAccess(supabase, data.user.id);
      if (accessError) {
        setError(accessError);
        setLoading(false);
        return;
      }
      router.push("/dashboard");
      router.refresh();
      return;
    }

    router.push("/");
    router.refresh();
  }

  return (
    <AuthShell
      brandPanel={
        <AuthNetworkPanel
          heading={
            <>
              Bon retour parmi
              <br />
              les voyageurs connectés.
            </>
          }
          tagline="Retrouvez vos trajets, vos arrêts favoris et le réseau en temps réel, là où vous vous étiez arrêté."
          footnote="Réseau suivi en direct par la communauté"
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
      <h2 className={styles.title}>Connexion</h2>
      <p className={styles.subtitle}>
        Pas encore de compte ?{" "}
        <Link
          href={mode === "pro" ? "/signup?mode=pro" : "/signup"}
          data-hover
          className={styles.accentLink}
        >
          Créer un compte
        </Link>
      </p>

      <div className={styles.modeSwitch}>
        <button
          type="button"
          data-hover
          onClick={() => setMode("voyageur")}
          className={styles.modeButton}
          style={{
            background: mode === "voyageur" ? "#33BFA3" : "transparent",
            color: mode === "voyageur" ? "#04211c" : "rgba(255,255,255,0.7)",
          }}
        >
          Voyageur
        </button>
        <button
          type="button"
          data-hover
          onClick={() => setMode("pro")}
          className={styles.modeButton}
          style={{
            background: mode === "pro" ? "#33BFA3" : "transparent",
            color: mode === "pro" ? "#04211c" : "rgba(255,255,255,0.7)",
          }}
        >
          Aule Pro
        </button>
      </div>

      <div className={styles.ssoStack}>
        <button type="button" data-hover disabled title="Bientôt disponible" className={styles.ssoButton}>
          <svg width="18" height="18" viewBox="0 0 24 24">
            <path
              fill="#fff"
              d="M21.35 11.1h-9.17v2.98h5.27c-.23 1.4-1.63 4.1-5.27 4.1-3.17 0-5.76-2.62-5.76-5.85s2.59-5.85 5.76-5.85c1.8 0 3.02.77 3.71 1.43l2.53-2.44C16.9 3.6 14.77 2.7 12.18 2.7 7.03 2.7 2.85 6.88 2.85 12.03s4.18 9.33 9.33 9.33c5.39 0 8.96-3.79 8.96-9.13 0-.61-.07-1.08-.16-1.55l-.63.42Z"
            />
          </svg>
          Continuer avec Google
        </button>
        <button type="button" data-hover disabled title="Bientôt disponible" className={styles.ssoButton}>
          <svg width="17" height="17" viewBox="0 0 24 24">
            <path
              fill="#fff"
              d="M16.36 12.9c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.96.9-3.75 2.28-1.6 2.78-.41 6.89 1.15 9.14.76 1.1 1.67 2.34 2.86 2.29 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.12 2.76-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.65l.01-.34ZM14.13 5.9c.64-.77 1.07-1.85.95-2.92-.92.04-2.03.61-2.69 1.38-.59.68-1.11 1.77-.97 2.82 1.02.08 2.07-.52 2.71-1.28Z"
            />
          </svg>
          Continuer avec Apple
        </button>
      </div>

      <div className={styles.divider}>
        <div className={styles.dividerLine} />
        <span className={styles.dividerLabel}>ou par e-mail</span>
        <div className={styles.dividerLine} />
      </div>

      {error && (
        <p className={styles.alertError} role="alert">
          {error}
        </p>
      )}

      {success && (
        <div className={styles.alertSuccess} role="status">
          <CheckCircle2 size={16} />
          <span>{success}</span>
        </div>
      )}

      <form
        onSubmit={handleSubmit}
        className={styles.form}
        style={{ marginTop: error || success ? 16 : 0 }}
      >
        <label className={styles.field}>
          <span className={styles.fieldLabel}>E-mail</span>
          <input
            type="email"
            required
            autoComplete="email"
            placeholder="vous@exemple.com"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className={styles.input}
          />
        </label>

        <label className={styles.field}>
          <div className={styles.fieldHeader}>
            <span className={styles.fieldLabel}>Mot de passe</span>
            <Link
              href={`/forgot-password?mode=${mode}${
                email.trim()
                  ? `&email=${encodeURIComponent(email.trim())}`
                  : ""
              }`}
              data-hover
              className={styles.forgotLink}
            >
              Oublié ?
            </Link>
          </div>
          <div className={styles.inputWrap}>
            <input
              type={showPw ? "text" : "password"}
              required
              autoComplete="current-password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className={`${styles.input} ${styles.inputWithToggle}`}
            />
            <button
              type="button"
              data-hover
              onClick={() => setShowPw(!showPw)}
              className={styles.eyeButton}
              aria-label={showPw ? "Masquer le mot de passe" : "Afficher le mot de passe"}
            >
              {showPw ? <EyeOff size={19} /> : <Eye size={19} />}
            </button>
          </div>
        </label>

        <button type="button" onClick={() => setRemember(!remember)} className={styles.rememberRow}>
          <span className={`${styles.rememberBox} ${remember ? styles.rememberBoxChecked : ""}`}>
            {remember && <Check size={12} color="#04211c" strokeWidth={3.2} />}
          </span>
          <span className={styles.rememberLabel}>Rester connecté</span>
        </button>

        <button type="submit" data-hover disabled={loading} className={styles.submitButton}>
          {loading ? (
            <>
              <Loader2 size={17} className={styles.spinner} />
              Connexion…
            </>
          ) : mode === "pro" ? (
            "Accéder à Aule Pro"
          ) : (
            "Se connecter"
          )}
        </button>
      </form>

      <p className={styles.legal}>
        En continuant, vous acceptez les{" "}
        <a href="#" data-hover className={styles.legalLink}>
          Conditions
        </a>{" "}
        et la{" "}
        <a href="#" data-hover className={styles.legalLink}>
          Politique de confidentialité
        </a>{" "}
        d&apos;Aule.
      </p>
    </AuthShell>
  );
}
