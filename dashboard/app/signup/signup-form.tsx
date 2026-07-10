"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Bus, ShieldCheck, Store, ArrowRight, Smartphone, QrCode } from "lucide-react";
import { AuthShell } from "@/components/auth/auth-shell";
import { AuthNetworkPanel } from "@/components/auth/auth-network-panel";
import styles from "@/components/auth/auth-form.module.css";

export function SignupForm({ initialMode = "voyageur" }: { initialMode?: "voyageur" | "pro" }) {
  const router = useRouter();

  const [mode, setMode] = useState<"voyageur" | "pro">(initialMode);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia("(max-width: 768px)");
    const apply = () => setIsMobile(mq.matches);
    apply();
    mq.addEventListener("change", apply);
    return () => mq.removeEventListener("change", apply);
  }, []);

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
        <Link href="/login" data-hover className={styles.accentLink}>
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
          Professionnel
        </button>
      </div>

      <div className={styles.modeLegend}>
        {mode === "voyageur" ? (
          <p className={styles.legendText}>
            Pour les voyageurs : suivez vos transports en temps réel, calculez vos itinéraires et signalez les perturbations.
          </p>
        ) : (
          <p className={styles.legendText}>
            Pour les professionnels : accédez aux outils d&apos;exploitation réseau (poste de contrôle, mode conducteur, régulation).
          </p>
        )}
      </div>

      {mode === "voyageur" ? (
        <div className={styles.proOnboardingCard}>
          <div className={styles.proFeatureList}>
            <div className={styles.proFeatureItem}>
              <div className={styles.proFeatureIcon}>
                <Smartphone size={18} />
              </div>
              <div>
                <h4 className={styles.proFeatureTitle}>Poursuivez sur mobile</h4>
                <p className={styles.proFeatureDesc}>
                  L&apos;expérience voyageur Aule (itinéraires, suivi temps réel, signalements) est exclusivement disponible sur notre application mobile.
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
                  Scannez ce code pour ouvrir Aule sur votre téléphone et commencer à suivre vos trajets.
                </div>
              </div>
            </div>
          ) : (
            <p className={styles.mobileHint}>
              Téléchargez l&apos;application Aule ci-dessous pour commencer à l&apos;utiliser.
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
        </div>
      ) : (
        <div className={styles.proOnboardingCard}>
          <div className={styles.proFeatureList}>
            <div className={styles.proFeatureItem}>
              <div className={styles.proFeatureIcon}>
                <Bus size={18} />
              </div>
              <div>
                <h4 className={styles.proFeatureTitle}>Conducteurs & Chauffeurs</h4>
                <p className={styles.proFeatureDesc}>Profitez de la prise de service automatique et de la détection de ligne en temps réel.</p>
              </div>
            </div>
            <div className={styles.proFeatureItem}>
              <div className={styles.proFeatureIcon}>
                <ShieldCheck size={18} />
              </div>
              <div>
                <h4 className={styles.proFeatureTitle}>Régulateurs & Exploitation</h4>
                <p className={styles.proFeatureDesc}>Supervisez les flottes, gérez les incidents de parcours et configurez les alertes voyageurs.</p>
              </div>
            </div>
            <div className={styles.proFeatureItem}>
              <div className={styles.proFeatureIcon}>
                <Store size={18} />
              </div>
              <div>
                <h4 className={styles.proFeatureTitle}>Commerces partenaires</h4>
                <p className={styles.proFeatureDesc}>Devenez point de vente ou relais partenaire pour améliorer la vie des usagers du réseau.</p>
              </div>
            </div>
          </div>

          <button
            type="button"
            data-hover
            onClick={() => router.push("/onboarding")}
            className={styles.submitButton}
            style={{ marginTop: 24 }}
          >
            Commencer l&apos;onboarding pro
            <ArrowRight size={16} style={{ marginLeft: 6 }} />
          </button>
        </div>
      )}
    </AuthShell>
  );
}
