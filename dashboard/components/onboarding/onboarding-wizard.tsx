"use client";

import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  ArrowLeft,
  BadgeCheck,
  Bus,
  Check,
  Eye,
  EyeOff,
  Loader2,
  Lock,
  MapPin,
  Plus,
  QrCode,
  Radio,
  Search,
  ShieldCheck,
  SlidersHorizontal,
  Ticket,
  TramFront,
  User,
  Waypoints,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import type { StaffRole } from "@/lib/types";
import styles from "./onboarding-wizard.module.css";

const STORAGE_KEY = "aulepro-onboarding-v1";
const ACCENT = "#33BFA3";

type ProfileKey = "conducteur" | "controleur" | "regulateur" | "exploitation" | "maitrise";

type ChoiceStep = "profile" | "mode" | "habilitation";
type ListStep = "reseau";
type Step = "welcome" | ChoiceStep | ListStep | "identity" | "account" | "confirmation";

type DataField = "reseau" | "mode" | "habilitation" | "fonction";

type ChoiceItem = {
  key: string;
  label: string;
  desc?: string;
  icon: ReactNode;
};

type ListItem = {
  key: string;
  label: string;
  desc?: string;
};

const PROFILES: ChoiceItem[] = [
  { key: "conducteur", label: "Conducteur", desc: "Conduite d'un bus ou d'un tramway du réseau.", icon: <Bus size={22} /> },
  { key: "controleur", label: "Contrôleur", desc: "Contrôle des titres et intervention sur le réseau.", icon: <Ticket size={22} /> },
  { key: "regulateur", label: "Régulateur", desc: "Régulation du trafic en temps réel.", icon: <Radio size={22} /> },
  { key: "exploitation", label: "Agent d'exploitation", desc: "Exploitation quotidienne du réseau.", icon: <SlidersHorizontal size={22} /> },
  { key: "maitrise", label: "Agent de maîtrise", desc: "Encadrement des équipes terrain.", icon: <BadgeCheck size={22} /> },
];

const MODES: ChoiceItem[] = [
  { key: "bus", label: "Bus", desc: "Lignes de bus urbaines et interurbaines.", icon: <Bus size={22} /> },
  { key: "tram", label: "Tramway", desc: "Lignes de tramway.", icon: <TramFront size={22} /> },
  { key: "bustram", label: "Bus et Tramway", desc: "Les deux modes de transport.", icon: <Waypoints size={22} /> },
];

const HABILITATIONS: ChoiceItem[] = [
  { key: "controle", label: "Contrôle", desc: "Contrôle des titres de transport.", icon: <Ticket size={22} /> },
  { key: "intervention", label: "Contrôle + Intervention", desc: "Contrôle et intervention sur le réseau.", icon: <ShieldCheck size={22} /> },
];

const RESEAUX: ListItem[] = [{ key: "naolib", label: "Naolib", desc: "Nantes Métropole" }];

const CHOICE_CONFIG: Record<ChoiceStep, { title: string; subtitle: string; field: DataField | "profile"; items: ChoiceItem[] }> = {
  profile: { title: "Quel est votre métier ?", subtitle: "L'inscription Aule Pro est réservée aux équipes opérationnelles du réseau.", field: "profile", items: PROFILES },
  mode: { title: "Quels véhicules conduisez-vous ?", subtitle: "Vous pourrez le modifier à tout moment.", field: "mode", items: MODES },
  habilitation: { title: "Quelles sont vos habilitations ?", subtitle: "Sélectionnez votre niveau d'intervention.", field: "habilitation", items: HABILITATIONS },
};

const LIST_CONFIG: Record<ListStep, { title: string; subtitle: string; field: DataField; items: ListItem[]; placeholder: string }> = {
  reseau: { title: "Votre réseau de transport", subtitle: "Sélectionnez le réseau auquel vous êtes rattaché.", field: "reseau", items: RESEAUX, placeholder: "Rechercher un réseau..." },
};

const PROFILE_FLOW: Record<ProfileKey, Step[]> = {
  conducteur: ["reseau", "identity", "mode"],
  controleur: ["reseau", "identity", "habilitation"],
  regulateur: ["reseau", "identity"],
  exploitation: ["reseau", "identity"],
  maitrise: ["reseau", "identity"],
};

function flowFor(profile: ProfileKey | ""): Step[] {
  const cond = profile ? PROFILE_FLOW[profile] : [];
  return ["welcome", "profile", ...cond, "account", "confirmation"];
}

function isProfileKey(value: unknown): value is ProfileKey {
  return value === "conducteur" || value === "controleur" || value === "regulateur" || value === "exploitation" || value === "maitrise";
}

function restoreProfile(saved: Record<string, unknown>): ProfileKey | "" {
  if (isProfileKey(saved.profile)) return saved.profile;
  // Migration des brouillons v2 : l'ancien profil générique `agent`
  // demandait sa spécialité dans une quatrième étape désormais supprimée.
  if (saved.profile === "agent" && saved.data && typeof saved.data === "object") {
    const fonction = (saved.data as Partial<DataState>).fonction;
    if (fonction === "regulateur" || fonction === "exploitation" || fonction === "maitrise") {
      return fonction;
    }
  }
  return "";
}

function labelOf(items: { key: string; label: string }[], key: string) {
  return items.find((it) => it.key === key)?.label ?? "";
}

// Rôle attribué à l'inscription (lu par le trigger handle_new_auth_user).
// On n'attribue jamais "admin" automatiquement.
function roleForOnboarding(profile: ProfileKey | ""): StaffRole {
  switch (profile) {
    case "conducteur":
      return "driver";
    case "controleur":
      return "msr_agent";
    case "maitrise":
      return "msr_supervisor";
    case "regulateur":
    case "exploitation":
      return "regulator";
    default:
      return "passenger";
  }
}

type DataState = Record<DataField, string>;
const emptyData: DataState = { reseau: "", mode: "", habilitation: "", fonction: "" };

type IdentityState = { fullName: string; employeeId: string };
const emptyIdentity: IdentityState = { fullName: "", employeeId: "" };

type CustomNetworkState = { name: string; operator: string; territory: string };
const emptyCustomNetwork: CustomNetworkState = { name: "", operator: "", territory: "" };

type AccountState = { email: string; password: string; confirm: string; terms: boolean };
const emptyAccount: AccountState = { email: "", password: "", confirm: "", terms: false };

function passwordScore(password: string) {
  let score = 0;
  if (password.length >= 8) score++;
  if (/[A-Z]/.test(password) && /[0-9]/.test(password)) score++;
  if (password.length >= 12 && /[^A-Za-z0-9]/.test(password)) score++;
  return score;
}

function barColor(password: string, score: number, n: number) {
  if (password.length === 0) return "rgba(255,255,255,0.1)";
  if (score < n) return "rgba(255,255,255,0.1)";
  return score === 1 ? "#E4664D" : score === 2 ? "#FFB74D" : ACCENT;
}

export function OnboardingWizard() {
  const router = useRouter();

  const [hydrated, setHydrated] = useState(false);
  const [step, setStep] = useState<Step>("welcome");
  const [profile, setProfile] = useState<ProfileKey | "">("");
  const [data, setData] = useState<DataState>(emptyData);
  const [identity, setIdentity] = useState<IdentityState>(emptyIdentity);
  const [customNetwork, setCustomNetwork] = useState<CustomNetworkState>(emptyCustomNetwork);
  const [addingNetwork, setAddingNetwork] = useState(false);
  const [account, setAccount] = useState<AccountState>(emptyAccount);
  const [showPw, setShowPw] = useState(false);
  const [search, setSearch] = useState("");
  const [isMobile, setIsMobile] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [resendingConfirmation, setResendingConfirmation] = useState(false);
  const [confirmationNotice, setConfirmationNotice] = useState<string | null>(null);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const saved = JSON.parse(raw) as Record<string, unknown>;
        const savedProfile = restoreProfile(saved);
        const savedFlow = flowFor(savedProfile);
        const savedStep =
          typeof saved.step === "string" && savedFlow.includes(saved.step as Step)
            ? (saved.step as Step)
            : savedProfile
              ? "profile"
              : saved.profile === "agent"
                ? "profile"
                : "welcome";
        // Hydratation ponctuelle d'un brouillon stocké localement.
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setStep(savedStep);
        setProfile(savedProfile);
        if (saved.data && typeof saved.data === "object") {
          setData((current) => ({ ...current, ...(saved.data as Partial<DataState>) }));
        }
        if (saved.identity && typeof saved.identity === "object") {
          setIdentity((current) => ({ ...current, ...(saved.identity as Partial<IdentityState>) }));
        }
        if (saved.customNetwork && typeof saved.customNetwork === "object") {
          setCustomNetwork((current) => ({
            ...current,
            ...(saved.customNetwork as Partial<CustomNetworkState>),
          }));
        }
        if (saved.addingNetwork === true && (saved.data as Partial<DataState> | undefined)?.reseau === "custom") {
          setAddingNetwork(true);
        }
        if (saved.account && typeof saved.account === "object") {
          setAccount((current) => ({
            ...current,
            ...(saved.account as Partial<AccountState>),
            password: "",
            confirm: "",
          }));
        }
      }
    } catch {
      // ignore corrupted storage
    }
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          step,
          profile,
          data,
          identity,
          customNetwork,
          addingNetwork,
          account: { email: account.email, terms: account.terms },
        }),
      );
    } catch {
      // ignore storage failures (private mode, quota, ...)
    }
  }, [hydrated, step, profile, data, identity, customNetwork, addingNetwork, account.email, account.terms]);

  useEffect(() => {
    const mq = window.matchMedia("(max-width: 768px)");
    const apply = () => setIsMobile(mq.matches);
    apply();
    mq.addEventListener("change", apply);
    return () => mq.removeEventListener("change", apply);
  }, []);

  // Avant la sélection, le parcours conducteur sert de longueur de référence.
  // Les métiers d'exploitation passent ensuite à quatre étapes, la fonction
  // étant désormais choisie directement dans la première étape.
  const flow = useMemo(() => flowFor(profile || "conducteur"), [profile]);
  const idx = flow.indexOf(step);
  const actionSteps: Step[] = flow.filter((item) => item !== "welcome" && item !== "confirmation");
  const actionIndex = Math.max(0, actionSteps.indexOf(step));

  const goNext = useCallback(() => {
    const i = flow.indexOf(step);
    if (i >= 0 && i < flow.length - 1) {
      setStep(flow[i + 1]);
      setSearch("");
      setError(null);
    }
  }, [flow, step]);

  const goBack = useCallback(() => {
    if (step === "reseau" && addingNetwork) {
      setAddingNetwork(false);
      setData((current) => ({ ...current, reseau: "" }));
      setError(null);
      return;
    }
    const i = flow.indexOf(step);
    if (i > 0) {
      setStep(flow[i - 1]);
      setSearch("");
      setError(null);
    }
  }, [addingNetwork, flow, step]);

  async function submitAccount() {
    if (!isProfileKey(profile)) {
      setStep("profile");
      setError("Sélectionnez un métier autorisé pour créer un compte Aule Pro.");
      return;
    }
    const requiredSteps = PROFILE_FLOW[profile];
    const professionalDataComplete = requiredSteps.every((requiredStep) => {
      if (requiredStep === "identity") {
        return Boolean(identity.fullName.trim() && identity.employeeId.trim());
      }
      if (requiredStep in CHOICE_CONFIG) {
        const field = CHOICE_CONFIG[requiredStep as ChoiceStep].field;
        return field === "profile" ? Boolean(profile) : Boolean(data[field]);
      }
      if (requiredStep in LIST_CONFIG) {
        const selectedNetwork = data[LIST_CONFIG[requiredStep as ListStep].field];
        if (selectedNetwork === "custom") {
          return Boolean(
            customNetwork.name.trim() &&
              customNetwork.operator.trim() &&
              customNetwork.territory.trim(),
          );
        }
        return Boolean(selectedNetwork);
      }
      return true;
    });
    if (!professionalDataComplete) {
      setError("Certaines informations professionnelles sont manquantes.");
      return;
    }

    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error: authError } = await supabase.auth.signUp({
      email: account.email,
      password: account.password,
      options: {
        data: {
          role: roleForOnboarding(profile),
          display_name: identity.fullName.trim(),
          requested_access: "pro",
          onboarding_profile: profile,
          onboarding_data: data,
          onboarding_identity: {
            full_name: identity.fullName.trim(),
            employee_id: identity.employeeId.trim(),
          },
          onboarding_network_request:
            data.reseau === "custom"
              ? {
                  name: customNetwork.name.trim(),
                  operator: customNetwork.operator.trim(),
                  territory: customNetwork.territory.trim(),
                  status: "active",
                }
              : undefined,
          onboarding_version: 2,
        },
        emailRedirectTo: `${window.location.origin}/auth/callback?mode=pro`,
      },
    });

    setLoading(false);

    if (authError) {
      setError(authError.message);
      return;
    }

    goNext();
  }

  async function resendConfirmation() {
    if (resendingConfirmation || !account.email.trim()) return;

    setResendingConfirmation(true);
    setConfirmationNotice(null);

    const supabase = createClient();
    const { error: resendError } = await supabase.auth.resend({
      type: "signup",
      email: account.email.trim().toLowerCase(),
      options: {
        emailRedirectTo: `${window.location.origin}/auth/callback?mode=pro`,
      },
    });

    setResendingConfirmation(false);

    if (resendError?.status === 429 || resendError?.code === "over_email_send_rate_limit") {
      setConfirmationNotice("Trop de demandes ont été envoyées. Patientez quelques minutes avant de réessayer.");
      return;
    }

    setConfirmationNotice(
      "Si cette adresse attend encore une confirmation, un nouvel e-mail vient d’être envoyé. Si le compte était déjà confirmé, connectez-vous directement.",
    );
  }

  const identityOk = identity.fullName.trim().length >= 3 && identity.employeeId.trim().length >= 2;
  const customNetworkOk =
    customNetwork.name.trim().length >= 2 &&
    customNetwork.operator.trim().length >= 2 &&
    customNetwork.territory.trim().length >= 2;
  const score = passwordScore(account.password);
  const emailOk = /.+@.+\..+/.test(account.email);
  const confirmMismatch = account.confirm.length > 0 && account.confirm !== account.password;
  const accountOk = emailOk && account.password.length >= 8 && account.confirm === account.password && account.terms;

  const showWelcome = step === "welcome";
  const showChoice = step in CHOICE_CONFIG;
  const showList = step in LIST_CONFIG;
  const showIdentity = step === "identity";
  const showAccount = step === "account";
  const showDone = step === "confirmation";
  const shouldOfferMobile = profile === "conducteur" || profile === "controleur";

  let canContinue = true;
  let continueLabel = "Continuer";
  if (showChoice) {
    const cfg = CHOICE_CONFIG[step as ChoiceStep];
    const current = cfg.field === "profile" ? profile : data[cfg.field as DataField];
    canContinue = Boolean(current);
  } else if (showList) {
    const selected = data[LIST_CONFIG[step as ListStep].field];
    canContinue = selected === "custom" ? customNetworkOk : Boolean(selected);
  } else if (showIdentity) {
    canContinue = identityOk;
  } else if (showAccount) {
    canContinue = accountOk;
    continueLabel = "Créer mon compte";
  }

  const recap = useMemo(() => {
    const rows: { label: string; value: string }[] = [];
    if (!profile) return rows;
    // Ne montrer que les champs de la branche du profil courant, dans l'ordre du flux.
    const steps = PROFILE_FLOW[profile];
    rows.push({ label: "Profil", value: labelOf(PROFILES, profile) });
    if (steps.includes("reseau") && data.reseau) {
      rows.push({
        label: "Réseau",
        value: data.reseau === "custom" ? customNetwork.name : labelOf(RESEAUX, data.reseau),
      });
    }
    if (steps.includes("mode") && data.mode) rows.push({ label: "Mode de conduite", value: labelOf(MODES, data.mode) });
    if (steps.includes("habilitation") && data.habilitation) rows.push({ label: "Habilitations", value: labelOf(HABILITATIONS, data.habilitation) });
    if (identity.fullName) rows.push({ label: "Nom", value: identity.fullName });
    if (identity.employeeId) rows.push({ label: "Identifiant professionnel", value: identity.employeeId });
    return rows;
  }, [profile, data, identity, customNetwork.name]);

  function handleContinue() {
    if (!canContinue || loading) return;
    if (showAccount) {
      void submitAccount();
      return;
    }
    goNext();
  }

  function finishOnboarding() {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      // ignore
    }
    router.push("/login?mode=pro");
  }

  return (
    <div className={styles.page}>
      <Link href="/signup" className={styles.travelerCorner}>
        <User size={14} />
        S&apos;inscrire en tant que voyageur
      </Link>

      <svg viewBox="0 0 1200 800" preserveAspectRatio="xMidYMid slice" className={styles.bgSvg}>
        <path
          d="M-40 620 L180 600 L320 460 L470 420 L620 300 L820 240 L1040 180 L1260 150"
          fill="none"
          stroke="rgba(255,255,255,0.05)"
          strokeWidth="26"
          strokeLinecap="round"
        />
        <path
          d="M-40 720 L240 700 L520 560 L820 520 L1260 470"
          fill="none"
          stroke="rgba(255,255,255,0.04)"
          strokeWidth="16"
          strokeLinecap="round"
        />
        <path
          className={styles.bgDrift}
          d="M-40 620 L180 600 L320 460 L470 420 L620 300 L820 240 L1040 180 L1260 150"
          fill="none"
          stroke="#17A08A"
          strokeWidth="2.5"
          strokeDasharray="10 12"
          strokeLinecap="round"
        />
        <circle className={styles.bgPulse} cx="470" cy="420" r="6" fill="#33BFA3" />
        <circle cx="820" cy="240" r="4.5" fill="#fff" opacity="0.7" />
        <circle cx="180" cy="600" r="4.5" fill="#fff" opacity="0.5" />
      </svg>
      <div className={styles.glow} />
      <div className={styles.vignette} />

      <div className={styles.card}>
        {!showWelcome && (
          <div className={styles.progressTrack}>
            <div
              className={styles.progressBar}
              style={{
                width: `${actionSteps.length > 1 ? Math.round((actionIndex / (actionSteps.length - 1)) * 100) : 0}%`,
              }}
            />
          </div>
        )}

        <div className={styles.cardBody}>
          {!showWelcome && !showDone && (
            <div className={styles.header}>
              {idx >= 1 && (
                <button type="button" onClick={goBack} className={styles.backButton}>
                  <ArrowLeft size={15} />
                  Retour
                </button>
              )}
              <div className={styles.counter}>
                Étape {actionIndex + 1} sur {actionSteps.length}
              </div>
            </div>
          )}

          <div key={step} className={styles.stepWrap}>
            {showWelcome && (
              <div className={styles.welcome}>
                <div className={styles.logoRow}>
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src="/aule-logo.png" alt="Aule" width={30} height={30} style={{ objectFit: "contain" }} />
                  <span className={styles.logoName}>
                    Aule <span className={styles.logoAccent}>Pro</span>
                  </span>
                </div>

                <div className={styles.illustrationRow}>
                  {[Bus, Ticket, BadgeCheck].map((Icon, i) => (
                    <div key={i} className={styles.illustrationDot} style={{ animationDelay: `${i * 0.4}s` }}>
                      <div className={styles.illustrationCircle}>
                        <Icon size={22} />
                      </div>
                      <div className={styles.illustrationLine} />
                    </div>
                  ))}
                </div>

                <h1 className={styles.h1}>Bienvenue sur Aule Pro</h1>
                <p className={styles.welcomeSubtitle}>
                  L&apos;espace réservé aux conducteurs, contrôleurs et équipes de maîtrise et d&apos;exploitation.
                </p>

                <button
                  type="button"
                  onClick={() => setStep("profile")}
                  className={`${styles.primaryButton} ${styles.welcomeButton}`}
                >
                  Commencer
                </button>
                <p className={styles.welcomeHint}>Munissez-vous de votre identifiant professionnel</p>
              </div>
            )}

            {showChoice &&
              (() => {
                const cfg = CHOICE_CONFIG[step as ChoiceStep];
                const current = cfg.field === "profile" ? profile : data[cfg.field as DataField];
                return (
                  <div>
                    <h2 className={styles.stepTitle}>{cfg.title}</h2>
                    <p className={styles.stepSubtitle}>{cfg.subtitle}</p>
                    <div className={styles.cardsList}>
                      {cfg.items.map((item, i) => {
                        const selected = current === item.key;
                        return (
                          <button
                            key={item.key}
                            type="button"
                            onClick={() => {
                              if (cfg.field === "profile") {
                                const next = item.key as ProfileKey;
                                if (next !== profile) {
                                  // Changer de profil repart d'un état propre : sinon les
                                  // champs des autres branches (habilitation, mode…)
                                  // restent renseignés et polluent le récap et le payload.
                                  setData(emptyData);
                                  setIdentity(emptyIdentity);
                                  setCustomNetwork(emptyCustomNetwork);
                                  setAddingNetwork(false);
                                }
                                setProfile(next);
                              } else {
                                setData((d) => ({ ...d, [cfg.field as DataField]: item.key }));
                              }
                            }}
                            className={`${styles.choiceCard} ${selected ? styles.choiceCardSelected : ""}`}
                            style={{ animationDelay: `${i * 45}ms` }}
                          >
                            <span className={`${styles.iconWrap} ${selected ? styles.iconWrapSelected : ""}`}>
                              {item.icon}
                            </span>
                            <span className={styles.choiceText}>
                              <span className={styles.choiceLabel}>{item.label}</span>
                              {item.desc && <span className={styles.choiceDesc}>{item.desc}</span>}
                            </span>
                            <span className={`${styles.checkBadge} ${selected ? styles.checkBadgeVisible : ""}`}>
                              <Check size={13} strokeWidth={3.4} />
                            </span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                );
              })()}

            {showList &&
              (() => {
                const cfg = LIST_CONFIG[step as ListStep];
                const current = data[cfg.field];
                if (step === "reseau" && addingNetwork) {
                  return (
                    <div>
                      <h2 className={styles.stepTitle}>Ajouter votre réseau</h2>
                      <p className={styles.stepSubtitle}>
                        Renseignez son identité. Votre espace réseau privé sera créé et prêt à configurer dès la connexion.
                      </p>
                      <div className={styles.fieldsCol}>
                        <label className={styles.field}>
                          <span className={styles.fieldLabel}>Nom du réseau</span>
                          <input
                            type="text"
                            value={customNetwork.name}
                            onChange={(event) =>
                              setCustomNetwork((value) => ({ ...value, name: event.target.value }))
                            }
                            placeholder="Ex. Réseau Astuce"
                            className={styles.input}
                            autoFocus
                          />
                        </label>
                        <label className={styles.field}>
                          <span className={styles.fieldLabel}>Exploitant ou opérateur</span>
                          <input
                            type="text"
                            value={customNetwork.operator}
                            onChange={(event) =>
                              setCustomNetwork((value) => ({ ...value, operator: event.target.value }))
                            }
                            placeholder="Ex. Métropole Mobilités"
                            className={styles.input}
                          />
                        </label>
                        <label className={styles.field}>
                          <span className={styles.fieldLabel}>Territoire desservi</span>
                          <input
                            type="text"
                            value={customNetwork.territory}
                            onChange={(event) =>
                              setCustomNetwork((value) => ({ ...value, territory: event.target.value }))
                            }
                            placeholder="Ville, métropole ou département"
                            className={styles.input}
                          />
                        </label>
                      </div>
                    </div>
                  );
                }
                const q = search.trim().toLowerCase();
                const filtered = cfg.items.filter(
                  (it) => !q || it.label.toLowerCase().includes(q) || (it.desc ?? "").toLowerCase().includes(q),
                );
                return (
                  <div>
                    <h2 className={styles.stepTitle}>{cfg.title}</h2>
                    <p className={styles.stepSubtitle}>{cfg.subtitle}</p>
                    {cfg.items.length > 5 && (
                      <div className={styles.searchWrap}>
                        <span className={styles.searchIcon}>
                          <Search size={18} />
                        </span>
                        <input
                          type="text"
                          value={search}
                          onChange={(e) => setSearch(e.target.value)}
                          placeholder={cfg.placeholder}
                          className={styles.searchInput}
                        />
                      </div>
                    )}
                    <div className={styles.listRows}>
                      {filtered.map((item) => {
                        const selected = current === item.key;
                        return (
                          <button
                            key={item.key}
                            type="button"
                            onClick={() => setData((d) => ({ ...d, [cfg.field]: item.key }))}
                            className={`${styles.listRow} ${selected ? styles.listRowSelected : ""}`}
                          >
                            <span className={`${styles.listIconWrap} ${selected ? styles.listIconWrapSelected : ""}`}>
                              <MapPin size={18} />
                            </span>
                            <span className={styles.listText}>
                              <span className={styles.listLabel}>{item.label}</span>
                              {item.desc && <span className={styles.listDesc}>{item.desc}</span>}
                            </span>
                            <span className={`${styles.listCheck} ${selected ? styles.listCheckVisible : ""}`}>
                              <Check size={12} strokeWidth={3.4} />
                            </span>
                          </button>
                        );
                      })}
                      {filtered.length === 0 && (
                        <div className={styles.listEmpty}>
                          Aucun résultat pour « {search} ».
                          <br />
                          De nouveaux réseaux sont ajoutés régulièrement.
                        </div>
                      )}
                    </div>
                    <button
                      type="button"
                      className={styles.networkAddButton}
                      onClick={() => {
                        setAddingNetwork(true);
                        setData((value) => ({ ...value, reseau: "custom" }));
                        setSearch("");
                        setError(null);
                      }}
                    >
                      <span className={styles.networkAddIcon} aria-hidden="true">
                        <Plus size={18} />
                      </span>
                      <span>
                        <span className={styles.networkAddTitle}>Ajouter un nouveau réseau</span>
                        <span className={styles.networkAddDescription}>Mon réseau n&apos;apparaît pas dans la liste</span>
                      </span>
                    </button>
                  </div>
                );
              })()}

            {showIdentity && (
              <div>
                <h2 className={styles.stepTitle}>Votre identité professionnelle</h2>
                <p className={styles.stepSubtitle}>
                  Ces informations permettent de rattacher votre compte aux équipes du réseau.
                </p>
                <div className={styles.fieldsCol}>
                  <label className={styles.field}>
                    <span className={styles.fieldLabel}>Nom complet</span>
                    <input
                      type="text"
                      value={identity.fullName}
                      onChange={(e) => setIdentity((current) => ({ ...current, fullName: e.target.value }))}
                      placeholder="Prénom Nom"
                      className={styles.input}
                      autoComplete="name"
                    />
                  </label>
                  <label className={styles.field}>
                    <span className={styles.fieldLabel}>Identifiant professionnel ou matricule</span>
                    <input
                      type="text"
                      value={identity.employeeId}
                      onChange={(e) => setIdentity((current) => ({ ...current, employeeId: e.target.value }))}
                      placeholder="Ex. 48271"
                      className={styles.input}
                      autoComplete="off"
                    />
                  </label>
                </div>
              </div>
            )}

            {showAccount && (
              <div>
                <h2 className={styles.stepTitle}>Créez vos accès Aule Pro</h2>
                <p className={styles.stepSubtitle}>
                  Utilisez de préférence l&apos;adresse e-mail fournie par votre employeur.
                </p>

                <div className={styles.fieldsCol} style={{ marginTop: 0 }}>
                  <label className={styles.field}>
                    <span className={styles.fieldLabel}>Adresse e-mail</span>
                    <input
                      type="email"
                      value={account.email}
                      onChange={(e) => setAccount((s) => ({ ...s, email: e.target.value }))}
                      placeholder="vous@exemple.com"
                      className={styles.input}
                    />
                  </label>
                  <label className={styles.field}>
                    <span className={styles.fieldLabel}>Mot de passe</span>
                    <div className={styles.inputWrap}>
                      <input
                        type={showPw ? "text" : "password"}
                        value={account.password}
                        onChange={(e) => setAccount((s) => ({ ...s, password: e.target.value }))}
                        placeholder="8 caractères minimum"
                        className={`${styles.input} ${styles.inputWithToggle}`}
                      />
                      <button
                        type="button"
                        onClick={() => setShowPw((v) => !v)}
                        className={styles.eyeButton}
                        aria-label={showPw ? "Masquer le mot de passe" : "Afficher le mot de passe"}
                      >
                        {showPw ? <EyeOff size={18} /> : <Eye size={18} />}
                      </button>
                    </div>
                    <div className={styles.strengthBars}>
                      <span className={styles.strengthBar} style={{ background: barColor(account.password, score, 1) }} />
                      <span className={styles.strengthBar} style={{ background: barColor(account.password, score, 2) }} />
                      <span className={styles.strengthBar} style={{ background: barColor(account.password, score, 3) }} />
                    </div>
                  </label>
                  <label className={styles.field}>
                    <span className={styles.fieldLabel}>Confirmer le mot de passe</span>
                    <input
                      type={showPw ? "text" : "password"}
                      value={account.confirm}
                      onChange={(e) => setAccount((s) => ({ ...s, confirm: e.target.value }))}
                      placeholder="Retapez votre mot de passe"
                      className={`${styles.input} ${confirmMismatch ? styles.inputError : ""}`}
                    />
                  </label>
                  <div
                    role="checkbox"
                    aria-checked={account.terms}
                    tabIndex={0}
                    onClick={() => setAccount((s) => ({ ...s, terms: !s.terms }))}
                    onKeyDown={(e) => {
                      if (e.key === "Enter" || e.key === " ") {
                        e.preventDefault();
                        setAccount((s) => ({ ...s, terms: !s.terms }));
                      }
                    }}
                    className={styles.termsRow}
                  >
                    <span className={`${styles.termsBox} ${account.terms ? styles.termsBoxChecked : ""}`}>
                      {account.terms && <Check size={12} color="#04211c" strokeWidth={3.2} />}
                    </span>
                    <span className={styles.termsLabel}>
                      J&apos;accepte les{" "}
                      <Link
                        href="/conditions"
                        target="_blank"
                        style={{ color: ACCENT, textDecoration: "none" }}
                        onClick={(e) => {
                          e.stopPropagation();
                        }}
                      >
                        Conditions Générales d&apos;Utilisation
                      </Link>
                      .
                    </span>
                  </div>
                </div>

                {error && (
                  <p className={styles.errorBox} role="alert">
                    {error}
                  </p>
                )}
              </div>
            )}

            {showDone && (
              <div className={styles.done}>
                <div className={styles.doneIconWrap}>
                  <span className={styles.doneRing} />
                  <span className={styles.doneCircle}>
                    <Check size={40} strokeWidth={3} />
                  </span>
                </div>
                <h2 className={styles.doneTitle}>Vérifiez votre boîte mail</h2>
                <p className={styles.doneSubtitle}>
                  Si cette adresse est nouvelle, confirmez-la pour activer votre compte. Les habilitations métier restent soumises à la validation de votre réseau.
                </p>

                <div className={styles.recapCard}>
                  {recap.map((item) => (
                    <div key={item.label} className={styles.recapRow}>
                      <span className={styles.recapLabel}>{item.label}</span>
                      <span className={styles.recapValue}>{item.value}</span>
                    </div>
                  ))}
                </div>

                {shouldOfferMobile && (
                  <>
                    {!isMobile ? (
                      <div className={styles.qrCard}>
                        <span className={styles.qrBox}>
                          <QrCode size={34} />
                        </span>
                        <div>
                          <div className={styles.qrTextTitle}>Application mobile bientôt disponible</div>
                          <div className={styles.qrTextDesc}>
                            Votre profil sera accessible sur mobile à l&apos;ouverture des stores.
                          </div>
                        </div>
                      </div>
                    ) : (
                      <p className={styles.mobileHint}>L&apos;application mobile sera bientôt disponible.</p>
                    )}

                    <div className={styles.storeBadges}>
                      <span aria-disabled="true" className={styles.storeBadge}>
                        <svg width="18" height="18" viewBox="0 0 24 24">
                          <path
                            fill="#fff"
                            d="M16.36 12.9c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.96.9-3.75 2.28-1.6 2.78-.41 6.89 1.15 9.14.76 1.1 1.67 2.34 2.86 2.29 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.12 2.76-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.65l.01-.34ZM14.13 5.9c.64-.77 1.07-1.85.95-2.92-.92.04-2.03.61-2.69 1.38-.59.68-1.11 1.77-.97 2.82 1.02.08 2.07-.52 2.71-1.28Z"
                          />
                        </svg>
                        <span className={styles.storeBadgeText}>
                          <span className={styles.storeBadgeSmall}>App Store</span>
                          <span className={styles.storeBadgeBig}>Bientôt disponible</span>
                        </span>
                      </span>
                      <span aria-disabled="true" className={styles.storeBadge}>
                        <svg width="17" height="17" viewBox="0 0 24 24">
                          <path fill="#33BFA3" d="M3.6 2.4 13 12 3.6 21.6c-.3-.2-.6-.6-.6-1.1V3.5c0-.5.3-.9.6-1.1Z" />
                          <path fill="#fff" d="m15.3 9.7 2.9 1.6c.9.5.9 1.9 0 2.4l-2.9 1.6L13 12l2.3-2.3Z" />
                          <path fill="#fff" opacity=".8" d="M4.4 2.1 15 8.6 12.7 11 4.4 2.1Z" />
                          <path fill="#fff" opacity=".6" d="M4.4 21.9 12.7 13 15 15.4 4.4 21.9Z" />
                        </svg>
                        <span className={styles.storeBadgeText}>
                          <span className={styles.storeBadgeSmall}>Google Play</span>
                          <span className={styles.storeBadgeBig}>Bientôt disponible</span>
                        </span>
                      </span>
                    </div>
                  </>
                )}

                <button
                  type="button"
                  onClick={() => void resendConfirmation()}
                  disabled={resendingConfirmation}
                  className={styles.resendButton}
                >
                  {resendingConfirmation ? (
                    <>
                      <Loader2 size={16} className={styles.spinner} />
                      Envoi…
                    </>
                  ) : (
                    "Renvoyer l’e-mail de confirmation"
                  )}
                </button>

                {confirmationNotice && (
                  <p className={styles.confirmationNotice} role="status">
                    {confirmationNotice}
                  </p>
                )}

                <button type="button" onClick={finishOnboarding} className={styles.primaryButton} style={{ marginTop: 20 }}>
                  Se connecter à Aule Pro
                </button>
              </div>
            )}

          </div>

          {!showWelcome && !showDone && (
            <div className={styles.footer}>
              <button
                type="button"
                onClick={handleContinue}
                disabled={!canContinue || loading}
                className={styles.primaryButton}
              >
                {loading ? (
                  <>
                    <Loader2 size={17} className={styles.spinner} />
                    Création…
                  </>
                ) : (
                  continueLabel
                )}
              </button>
              <div className={styles.saveHint}>
                <Lock size={12} />
                Progression enregistrée automatiquement
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
