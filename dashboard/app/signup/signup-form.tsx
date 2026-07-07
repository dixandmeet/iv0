"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Eye, EyeOff, Loader2, Check, MailCheck } from "lucide-react";
import { AuthShell } from "@/components/auth/auth-shell";
import { AuthNetworkPanel } from "@/components/auth/auth-network-panel";
import { createClient } from "@/lib/supabase/client";
import styles from "@/components/auth/auth-form.module.css";

type SignupMode = "voyageur" | "pro";

const NAME_LABEL: Record<SignupMode, string> = {
  voyageur: "Nom complet",
  pro: "Nom complet ou commerce",
};

const NAME_PLACEHOLDER: Record<SignupMode, string> = {
  voyageur: "Camille Dubois",
  pro: "Camille Dubois ou Café Louna",
};

const SUBMIT_LABEL: Record<SignupMode, string> = {
  voyageur: "Créer mon compte",
  pro: "Demander un accès Aule Pro",
};

function passwordStrength(password: string) {
  let score = 0;
  if (password.length >= 8) score++;
  if (/[A-Z]/.test(password) && /[0-9]/.test(password)) score++;
  if (password.length >= 12 && /[^A-Za-z0-9]/.test(password)) score++;

  const barColor = (n: number) => {
    if (password.length === 0) return "rgba(255,255,255,0.1)";
    if (score < n) return "rgba(255,255,255,0.1)";
    return score === 1 ? "#E4664D" : score === 2 ? "#FFB74D" : "#33BFA3";
  };

  return [barColor(1), barColor(2), barColor(3)];
}

type SignupFormProps = {
  initialMode?: SignupMode;
};

export function SignupForm({ initialMode = "voyageur" }: SignupFormProps) {
  const router = useRouter();

  const [mode, setMode] = useState<SignupMode>(initialMode);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [terms, setTerms] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  const canSubmit = name.trim() !== "" && email.trim() !== "" && password.length >= 8 && terms;
  const [bar1, bar2, bar3] = passwordStrength(password);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!canSubmit) return;
    setLoading(true);
    setError(null);
    setSuccess(null);

    const supabase = createClient();
    const { data, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          display_name: name.trim(),
          requested_access: mode === "pro" ? "pro" : null,
        },
        emailRedirectTo: `${window.location.origin}/login`,
      },
    });

    if (authError) {
      setError(authError.message);
      setLoading(false);
      return;
    }

    if (data.session) {
      if (mode === "pro") {
        setSuccess(
          "Compte créé. Votre demande d'accès Aule Pro a été enregistrée — un administrateur activera votre rôle prochainement.",
        );
        setLoading(false);
        return;
      }
      router.push("/");
      router.refresh();
      return;
    }

    setSuccess(
      mode === "pro"
        ? "Vérifiez votre boîte mail pour confirmer votre adresse. Votre demande d'accès Aule Pro sera ensuite examinée par un administrateur."
        : "Compte créé. Vérifiez votre boîte mail pour confirmer votre adresse, puis connectez-vous.",
    );
    setPassword("");
    setLoading(false);
  }

  return (
    <AuthShell
      brandPanel={
        <AuthNetworkPanel
          heading="Rejoignez le réseau qui s'améliore à chaque trajet."
          tagline="Créez votre compte pour suivre vos transports en temps réel et contribuer à une cartographie collaborative."
          footnote="Déjà utilisé par des voyageurs, des commerçants et des équipes réseau"
          mainPath="M-20 200 L140 220 L240 340 L340 380 L440 500 L540 560 L640 640"
          secondaryPath="M-20 120 L180 140 L360 260 L640 300"
          accentDot={{ cx: 340, cy: 380 }}
          fadedDots={[
            { cx: 440, cy: 500, opacity: 0.85 },
            { cx: 140, cy: 220, opacity: 0.6 },
          ]}
          vignettePosition="30% 70%"
        />
      }
    >
      <h2 className={styles.title}>Créer un compte</h2>
      <p className={styles.subtitle}>
        Déjà inscrit ?{" "}
        <Link
          href={mode === "pro" ? "/login?mode=pro" : "/login"}
          data-hover
          className={styles.accentLink}
        >
          Se connecter
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
        <div className={styles.alertSuccess} role="status" style={{ display: "flex", gap: 10, alignItems: "flex-start" }}>
          <MailCheck size={16} style={{ flex: "none", marginTop: 2 }} />
          <span>{success}</span>
        </div>
      )}

      {!success && (
        <form
          onSubmit={handleSubmit}
          className={styles.form}
          style={{ marginTop: error ? 16 : 0 }}
        >
          <label className={styles.field}>
            <span className={styles.fieldLabel}>{NAME_LABEL[mode]}</span>
            <input
              type="text"
              required
              autoComplete="name"
              placeholder={NAME_PLACEHOLDER[mode]}
              value={name}
              onChange={(e) => setName(e.target.value)}
              className={styles.input}
            />
          </label>

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
            <span className={styles.fieldLabel}>Mot de passe</span>
            <div className={styles.inputWrap}>
              <input
                type={showPw ? "text" : "password"}
                required
                minLength={8}
                autoComplete="new-password"
                placeholder="8 caractères minimum"
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
            <div className={styles.strengthBars}>
              <span className={styles.strengthBar} style={{ background: bar1 }} />
              <span className={styles.strengthBar} style={{ background: bar2 }} />
              <span className={styles.strengthBar} style={{ background: bar3 }} />
            </div>
          </label>

          <div
            role="checkbox"
            aria-checked={terms}
            tabIndex={0}
            onClick={() => setTerms(!terms)}
            onKeyDown={(e) => {
              if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                setTerms(!terms);
              }
            }}
            className={styles.termsRow}
          >
            <span className={`${styles.termsBox} ${terms ? styles.termsBoxChecked : ""}`}>
              {terms && <Check size={12} color="#04211c" strokeWidth={3.2} />}
            </span>
            <span className={styles.termsLabel}>
              J&apos;accepte les{" "}
              <a
                href="#"
                data-hover
                className={styles.accentLink}
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                }}
              >
                Conditions
              </a>{" "}
              et la{" "}
              <a
                href="#"
                data-hover
                className={styles.accentLink}
                onClick={(e) => {
                  e.preventDefault();
                  e.stopPropagation();
                }}
              >
                Politique de confidentialité
              </a>{" "}
              d&apos;Aule.
            </span>
          </div>

          <button
            type="submit"
            data-hover
            disabled={!canSubmit || loading}
            className={styles.submitButton}
            style={{
              background: canSubmit ? "#33BFA3" : "rgba(255,255,255,0.12)",
              opacity: canSubmit ? 1 : 0.6,
            }}
          >
            {loading ? (
              <>
                <Loader2 size={17} className={styles.spinner} />
                Création…
              </>
            ) : (
              SUBMIT_LABEL[mode]
            )}
          </button>
        </form>
      )}
    </AuthShell>
  );
}
