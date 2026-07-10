"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Eye, EyeOff, Loader2, Check, CheckCircle2, Smartphone, QrCode, ArrowLeft } from "lucide-react";
import { AuthShell } from "@/components/auth/auth-shell";
import { AuthNetworkPanel } from "@/components/auth/auth-network-panel";
import { createClient } from "@/lib/supabase/client";
import { getAuthErrorMessage } from "@/lib/auth-errors";
import { type StaffRole } from "@/lib/types";
import { isProfile, profilesFromStaffRole, type Profile } from "@/lib/access/profiles";
import styles from "@/components/auth/auth-form.module.css";

type LoginFormProps = {
  initialError?: string | null;
  initialSuccess?: string | null;
  initialMode?: "voyageur" | "pro";
  redirectTo?: string;
};

async function checkWebDashboardAccess(
  supabase: ReturnType<typeof createClient>,
  userId: string,
): Promise<{
  hasAccess: boolean;
  hasAdminAccess: boolean;
  error: string | null;
}> {
  const { data: profile, error: profileErr } = await supabase
    .from("user_profiles")
    .select("role")
    .eq("id", userId)
    .maybeSingle();

  if (profileErr) {
    return { hasAccess: false, hasAdminAccess: false, error: profileErr.message };
  }

  const role = (profile?.role as StaffRole | undefined) ?? "passenger";

  const { data: rows, error: assignmentsErr } = await supabase
    .from("profile_assignments")
    .select("profile_key")
    .eq("user_id", userId)
    .eq("is_active", true);

  let profiles: Profile[] = [];
  if (assignmentsErr || !rows || rows.length === 0) {
    profiles = profilesFromStaffRole(role);
  } else {
    profiles = rows
      .map((r) => r.profile_key)
      .filter((k): k is Profile => typeof k === "string" && isProfile(k));
  }

  const webProfiles: Profile[] = [
    "merchant",
    "operations",
    "supervisor",
    "platform_admin",
    "super_admin",
    "admin",
  ];
  const adminProfiles: Profile[] = ["platform_admin", "super_admin", "admin"];
  const hasAccess = profiles.some((p) => webProfiles.includes(p));
  const hasAdminAccess =
    role === "admin" || profiles.some((p) => adminProfiles.includes(p));

  return { hasAccess, hasAdminAccess, error: null };
}

export function LoginForm({
  initialError = null,
  initialSuccess = null,
  redirectTo,
}: LoginFormProps) {
  const router = useRouter();

  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [verificationCode, setVerificationCode] = useState("");
  const [loginMethod, setLoginMethod] = useState<"otp" | "password">("otp");
  const [otpStep, setOtpStep] = useState<"email" | "code">("email");

  const [showPw, setShowPw] = useState(false);
  const [remember, setRemember] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(initialError);
  const [success, setSuccess] = useState<string | null>(initialSuccess);
  const [showMobileInvitation, setShowMobileInvitation] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia("(max-width: 768px)");
    const apply = () => setIsMobile(mq.matches);
    apply();
    mq.addEventListener("change", apply);
    return () => mq.removeEventListener("change", apply);
  }, []);

  async function handleSendOtp(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(null);

    const normalizedEmail = email.trim().toLowerCase();
    const supabase = createClient();

    const { error: otpError } = await supabase.auth.signInWithOtp({
      email: normalizedEmail,
    });

    setLoading(false);

    if (otpError) {
      setError(getAuthErrorMessage(otpError));
      return;
    }

    setSuccess("Code de validation envoyé ! Veuillez vérifier votre boîte mail.");
    setOtpStep("code");
  }

  async function handleVerifyOtp(e: React.FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError(null);
    setSuccess(null);

    const normalizedEmail = email.trim().toLowerCase();
    const supabase = createClient();

    const { data, error: verifyError } = await supabase.auth.verifyOtp({
      email: normalizedEmail,
      token: verificationCode.trim(),
      type: "email",
    });

    if (verifyError) {
      console.error("Verification failed:", verifyError);
      setError(verifyError.message || getAuthErrorMessage(verifyError));
      setLoading(false);
      return;
    }

    const { hasAccess, hasAdminAccess, error: accessCheckError } =
      await checkWebDashboardAccess(supabase, data.user!.id);

    if (accessCheckError) {
      setError(accessCheckError);
      setLoading(false);
      return;
    }

    if (!hasAccess) {
      await supabase.auth.signOut();
      setShowMobileInvitation(true);
      setLoading(false);
      return;
    }

    if (redirectTo?.startsWith("/admin") && !hasAdminAccess) {
      await supabase.auth.signOut();
      setError("Ce compte n'a pas accès à Aule Admin.");
      setLoading(false);
      return;
    }

    router.push(redirectTo ?? "/dashboard");
    router.refresh();
  }

  async function handlePasswordSubmit(e: React.FormEvent) {
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

    const { hasAccess, hasAdminAccess, error: accessCheckError } =
      await checkWebDashboardAccess(supabase, data.user.id);

    if (accessCheckError) {
      setError(accessCheckError);
      setLoading(false);
      return;
    }

    if (!hasAccess) {
      await supabase.auth.signOut();
      setShowMobileInvitation(true);
      setLoading(false);
      return;
    }

    if (redirectTo?.startsWith("/admin") && !hasAdminAccess) {
      await supabase.auth.signOut();
      setError("Ce compte n'a pas accès à Aule Admin.");
      setLoading(false);
      return;
    }

    router.push(redirectTo ?? "/dashboard");
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
          href="/signup"
          data-hover
          className={styles.accentLink}
        >
          Créer un compte
        </Link>
      </p>

      {showMobileInvitation ? (
        <div className={styles.proOnboardingCard}>
          <div className={styles.proFeatureList}>
            <div className={styles.proFeatureItem}>
              <div className={styles.proFeatureIcon}>
                <Smartphone size={18} />
              </div>
              <div>
                <h4 className={styles.proFeatureTitle}>Poursuivez sur mobile</h4>
                <p className={styles.proFeatureDesc}>
                  Votre profil Aule (voyageur, conducteur ou contrôleur) est conçu pour être utilisé exclusivement sur l&apos;application mobile.
                </p>
              </div>
            </div>
          </div>

          {!isMobile ? (
            <div className={styles.qrCard}>
              <span className={styles.qrBox}>
                <QrCode size={34} />
              </span>
              <div>
                <div className={styles.qrTextTitle}>Téléchargez l&apos;application</div>
                <div className={styles.qrTextDesc}>
                  Scannez ce code pour ouvrir Aule sur votre téléphone et vous connecter.
                </div>
              </div>
            </div>
          ) : (
            <p className={styles.mobileHint}>
              Téléchargez l&apos;application Aule ci-dessous pour vous connecter.
            </p>
          )}

          <div className={styles.storeBadges}>
            <a href="#" onClick={(e) => e.preventDefault()} className={styles.storeBadge}>
              <svg width="18" height="18" viewBox="0 0 24 24">
                <path
                  fill="#fff"
                  d="M16.36 12.9c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.96.9-3.75 2.28-1.6 2.78-.41 6.89 1.15 9.14.76 1.1 1.67 2.34 2.86 2.29 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.12 2.76-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.65l.01-.34ZM14.13 5.9c.64-.77 1.07-1.85.95-2.92-.92.04-2.03.61-2.69 1.38-.59.68-1.11 1.77-.97 2.82 1.02.08 2.07-.52 2.71-1.28Z"
                />
              </svg>
              <span className={styles.storeBadgeText}>
                <span className={styles.storeBadgeSmall}>Télécharger sur</span>
                <span className={styles.storeBadgeBig}>App Store</span>
              </span>
            </a>
            <a href="#" onClick={(e) => e.preventDefault()} className={styles.storeBadge}>
              <svg width="17" height="17" viewBox="0 0 24 24">
                <path fill="#33BFA3" d="M3.6 2.4 13 12 3.6 21.6c-.3-.2-.6-.6-.6-1.1V3.5c0-.5.3-.9.6-1.1Z" />
                <path fill="#fff" d="m15.3 9.7 2.9 1.6c.9.5.9 1.9 0 2.4l-2.9 1.6L13 12l2.3-2.3Z" />
                <path fill="#fff" opacity=".8" d="M4.4 2.1 15 8.6 12.7 11 4.4 2.1Z" />
                <path fill="#fff" opacity=".6" d="M4.4 21.9 12.7 13 15 15.4 4.4 21.9Z" />
              </svg>
              <span className={styles.storeBadgeText}>
                <span className={styles.storeBadgeSmall}>Disponible sur</span>
                <span className={styles.storeBadgeBig}>Google Play</span>
              </span>
            </a>
          </div>

          <button
            type="button"
            data-hover
            onClick={() => setShowMobileInvitation(false)}
            className={styles.secondaryButton}
            style={{ marginTop: 20 }}
          >
            Retour à la connexion
          </button>
        </div>
      ) : (
        <>
          {error && (
            <p className={styles.alertError} role="alert" style={{ marginTop: 20 }}>
              {error}
            </p>
          )}

          {success && (
            <div className={styles.alertSuccess} role="status" style={{ marginTop: 20 }}>
              <CheckCircle2 size={16} />
              <span>{success}</span>
            </div>
          )}

          {loginMethod === "otp" ? (
            otpStep === "email" ? (
              <form onSubmit={handleSendOtp} className={styles.form} style={{ marginTop: error || success ? 16 : 20 }}>
                <label className={styles.field}>
                  <span className={styles.fieldLabel}>Adresse e-mail</span>
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

                <button type="submit" data-hover disabled={loading} className={styles.submitButton}>
                  {loading ? (
                    <>
                      <Loader2 size={17} className={styles.spinner} />
                      Envoi du code…
                    </>
                  ) : (
                    "Recevoir un code de validation"
                  )}
                </button>

                <button
                  type="button"
                  onClick={() => {
                    setLoginMethod("password");
                    setError(null);
                    setSuccess(null);
                  }}
                  className={styles.secondaryButton}
                  style={{ marginTop: 8 }}
                >
                  Se connecter avec un mot de passe
                </button>
              </form>
            ) : (
              <form onSubmit={handleVerifyOtp} className={styles.form} style={{ marginTop: error || success ? 16 : 20 }}>
                <div style={{ marginBottom: 4, display: "flex", alignItems: "center", gap: 6 }}>
                  <button
                    type="button"
                    onClick={() => {
                      setOtpStep("email");
                      setError(null);
                      setSuccess(null);
                    }}
                    className={styles.forgotLink}
                    style={{ display: "flex", alignItems: "center", gap: 4, background: "none", border: "none", padding: 0, cursor: "pointer" }}
                  >
                    <ArrowLeft size={14} /> Modifier l&apos;adresse email
                  </button>
                </div>
                <label className={styles.field}>
                  <span className={styles.fieldLabel}>Code de validation</span>
                  <input
                    type="text"
                    required
                    maxLength={6}
                    placeholder="123456"
                    value={verificationCode}
                    onChange={(e) => setVerificationCode(e.target.value)}
                    className={styles.input}
                    style={{ textAlign: "center", fontSize: 18, letterSpacing: 4 }}
                  />
                </label>

                <button type="submit" data-hover disabled={loading} className={styles.submitButton}>
                  {loading ? (
                    <>
                      <Loader2 size={17} className={styles.spinner} />
                      Validation…
                    </>
                  ) : (
                    "Valider et se connecter"
                  )}
                </button>

                <button
                  type="button"
                  onClick={handleSendOtp}
                  disabled={loading}
                  className={styles.secondaryButton}
                  style={{ marginTop: 8 }}
                >
                  Renvoyer le code
                </button>
              </form>
            )
          ) : (
            <form onSubmit={handlePasswordSubmit} className={styles.form} style={{ marginTop: error || success ? 16 : 20 }}>
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
                    href={`/forgot-password?mode=voyageur${
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
                ) : (
                  "Se connecter"
                )}
              </button>

              <button
                type="button"
                onClick={() => {
                  setLoginMethod("otp");
                  setOtpStep("email");
                  setError(null);
                  setSuccess(null);
                }}
                className={styles.secondaryButton}
                style={{ marginTop: 8 }}
              >
                Se connecter avec un code de validation
              </button>
            </form>
          )}

          <p className={styles.legal} style={{ marginTop: 24 }}>
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
        </>
      )}
    </AuthShell>
  );
}
