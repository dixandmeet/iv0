"use client";

import { useCallback, useEffect, useMemo, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import {
  ArrowLeft,
  BadgeCheck,
  Bus,
  Car,
  Check,
  Coffee,
  Eye,
  EyeOff,
  Loader2,
  Lock,
  MapPin,
  MoreHorizontal,
  Network,
  Pill,
  QrCode,
  Radio,
  Route,
  Search,
  ShieldCheck,
  ShoppingCart,
  SlidersHorizontal,
  Smartphone,
  Store,
  Ticket,
  TramFront,
  User,
  UtensilsCrossed,
  Warehouse,
  Waypoints,
  Wheat,
} from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import type { StaffRole } from "@/lib/types";
import styles from "./onboarding-wizard.module.css";

const STORAGE_KEY = "aulepro-onboarding-v1";
const ACCENT = "#33BFA3";

type ProfileKey = "conducteur" | "controleur" | "vtc" | "commercant" | "agent";

type ChoiceStep = "profile" | "genre" | "mode" | "habilitation" | "fonction" | "typeCommerce";
type ListStep = "reseau" | "zone";
type Step = "welcome" | ChoiceStep | ListStep | "etabInfo" | "account" | "confirmation" | "download";

type DataField = "reseau" | "genre" | "mode" | "habilitation" | "fonction" | "zone" | "typeCommerce";

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
  { key: "conducteur", label: "Conducteur", desc: "Conduite de bus ou de tramway.", icon: <Bus size={22} /> },
  { key: "controleur", label: "Contrôleur", desc: "Contrôle des titres et accompagnement des voyageurs.", icon: <Ticket size={22} /> },
  { key: "vtc", label: "Chauffeur VTC", desc: "Professionnel du transport individuel.", icon: <Car size={22} /> },
  { key: "commercant", label: "Commerçant", desc: "Professionnel partenaire présent sur Aule.", icon: <Store size={22} /> },
  { key: "agent", label: "Agent de maîtrise / Exploitation", desc: "Encadrement, régulation ou exploitation du réseau.", icon: <BadgeCheck size={22} /> },
];

const GENRES: ChoiceItem[] = [
  { key: "homme", label: "Homme", icon: <User size={22} /> },
  { key: "femme", label: "Femme", icon: <User size={22} /> },
  { key: "autre", label: "Autre / Ne se prononce pas", icon: <User size={22} /> },
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

const FONCTIONS: ChoiceItem[] = [
  { key: "regulateur", label: "Régulateur", desc: "Régulation du trafic en temps réel.", icon: <Radio size={22} /> },
  { key: "exploitation", label: "Agent d'exploitation", desc: "Exploitation quotidienne du réseau.", icon: <SlidersHorizontal size={22} /> },
  { key: "maitrise", label: "Agent de maîtrise", desc: "Encadrement des équipes terrain.", icon: <BadgeCheck size={22} /> },
  { key: "depot", label: "Responsable de dépôt", desc: "Gestion d'un dépôt.", icon: <Warehouse size={22} /> },
  { key: "ligne", label: "Responsable de ligne", desc: "Supervision d'une ou plusieurs lignes.", icon: <Route size={22} /> },
  { key: "autre", label: "Autre fonction", desc: "Une autre fonction d'encadrement.", icon: <MoreHorizontal size={22} /> },
];

const COMMERCES: ChoiceItem[] = [
  { key: "restaurant", label: "Restaurant", desc: "Restauration sur place.", icon: <UtensilsCrossed size={22} /> },
  { key: "cafe", label: "Café", desc: "Café, bar, salon de thé.", icon: <Coffee size={22} /> },
  { key: "boulangerie", label: "Boulangerie", desc: "Boulangerie, pâtisserie.", icon: <Wheat size={22} /> },
  { key: "supermarche", label: "Supermarché", desc: "Alimentation générale.", icon: <ShoppingCart size={22} /> },
  { key: "pharmacie", label: "Pharmacie", desc: "Officine, parapharmacie.", icon: <Pill size={22} /> },
  { key: "autre", label: "Autre commerce", desc: "Un autre type d'établissement.", icon: <Store size={22} /> },
];

const RESEAUX: ListItem[] = [{ key: "naolib", label: "Naolib", desc: "Nantes Métropole" }];

const ZONES: ListItem[] = [
  { key: "nantes", label: "Nantes", desc: "Loire-Atlantique" },
  { key: "paris", label: "Paris", desc: "Île-de-France" },
  { key: "lyon", label: "Lyon", desc: "Auvergne-Rhône-Alpes" },
  { key: "marseille", label: "Marseille", desc: "Provence-Alpes-Côte d'Azur" },
  { key: "bordeaux", label: "Bordeaux", desc: "Nouvelle-Aquitaine" },
  { key: "toulouse", label: "Toulouse", desc: "Occitanie" },
  { key: "lille", label: "Lille", desc: "Hauts-de-France" },
  { key: "rennes", label: "Rennes", desc: "Bretagne" },
  { key: "strasbourg", label: "Strasbourg", desc: "Grand Est" },
  { key: "nice", label: "Nice", desc: "Provence-Alpes-Côte d'Azur" },
];

const CHOICE_CONFIG: Record<ChoiceStep, { title: string; subtitle: string; field: DataField | "profile"; items: ChoiceItem[] }> = {
  profile: { title: "Qui êtes-vous ?", subtitle: "Sélectionnez le profil qui correspond à votre activité.", field: "profile", items: PROFILES },
  genre: { title: "Comment vous identifiez-vous ?", subtitle: "Cette information reste confidentielle et sert à personnaliser Aule.", field: "genre", items: GENRES },
  mode: { title: "Quels véhicules conduisez-vous ?", subtitle: "Vous pourrez le modifier à tout moment.", field: "mode", items: MODES },
  habilitation: { title: "Quelles sont vos habilitations ?", subtitle: "Sélectionnez votre niveau d'intervention.", field: "habilitation", items: HABILITATIONS },
  fonction: { title: "Quelle est votre fonction ?", subtitle: "Sélectionnez votre rôle sur le réseau.", field: "fonction", items: FONCTIONS },
  typeCommerce: { title: "Quel type de commerce ?", subtitle: "Choisissez la catégorie la plus proche.", field: "typeCommerce", items: COMMERCES },
};

const LIST_CONFIG: Record<ListStep, { title: string; subtitle: string; field: DataField; items: ListItem[]; placeholder: string }> = {
  reseau: { title: "À quel réseau appartenez-vous ?", subtitle: "Recherchez votre réseau de transport.", field: "reseau", items: RESEAUX, placeholder: "Rechercher un réseau..." },
  zone: { title: "Votre zone d'activité principale", subtitle: "Où exercez-vous le plus souvent ?", field: "zone", items: ZONES, placeholder: "Rechercher une ville..." },
};

const PROFILE_FLOW: Record<ProfileKey, Step[]> = {
  conducteur: ["reseau", "genre", "mode"],
  controleur: ["reseau", "genre", "habilitation"],
  agent: ["reseau", "genre", "fonction"],
  vtc: ["genre", "zone"],
  commercant: ["typeCommerce", "etabInfo"],
};

function flowFor(profile: ProfileKey | ""): Step[] {
  if (profile === "conducteur" || profile === "controleur" || profile === "vtc") {
    return ["welcome", "profile", "download"];
  }
  const cond = profile ? PROFILE_FLOW[profile] : [];
  return ["welcome", "profile", ...cond, "account", "confirmation"];
}

function labelOf(items: { key: string; label: string }[], key: string) {
  return items.find((it) => it.key === key)?.label ?? "";
}

// Rôle attribué à l'inscription (lu par le trigger handle_new_auth_user).
// Seuls msr_supervisor / regulator / admin ont accès au dashboard web ; les
// autres profils (conducteur, contrôleur, VTC, commerçant) utilisent l'app
// mobile. On n'attribue jamais "admin" automatiquement.
function roleForOnboarding(profile: ProfileKey | "", fonction: string): StaffRole {
  switch (profile) {
    case "conducteur":
    case "vtc":
      return "driver";
    case "controleur":
      return "msr_agent";
    case "agent":
      switch (fonction) {
        case "maitrise":
        case "depot":
        case "ligne":
          return "msr_supervisor";
        case "regulateur":
        case "exploitation":
        default:
          return "regulator";
      }
    case "commercant":
    default:
      return "passenger";
  }
}

type DataState = Record<DataField, string>;
const emptyData: DataState = { reseau: "", genre: "", mode: "", habilitation: "", fonction: "", zone: "", typeCommerce: "" };

type EtabState = { nom: string; adresse: string; tel: string; site: string };
const emptyEtab: EtabState = { nom: "", adresse: "", tel: "", site: "" };

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
  const [etab, setEtab] = useState<EtabState>(emptyEtab);
  const [account, setAccount] = useState<AccountState>(emptyAccount);
  const [showPw, setShowPw] = useState(false);
  const [search, setSearch] = useState("");
  const [isMobile, setIsMobile] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw) {
        const saved = JSON.parse(raw);
        if (saved.step) setStep(saved.step);
        if (saved.profile) setProfile(saved.profile);
        if (saved.data) setData((d) => ({ ...d, ...saved.data }));
        if (saved.etab) setEtab((e) => ({ ...e, ...saved.etab }));
        if (saved.account) setAccount((a) => ({ ...a, ...saved.account, password: "", confirm: "" }));
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
          etab,
          account: { email: account.email, terms: account.terms },
        }),
      );
    } catch {
      // ignore storage failures (private mode, quota, ...)
    }
  }, [hydrated, step, profile, data, etab, account.email, account.terms]);

  useEffect(() => {
    const mq = window.matchMedia("(max-width: 768px)");
    const apply = () => setIsMobile(mq.matches);
    apply();
    mq.addEventListener("change", apply);
    return () => mq.removeEventListener("change", apply);
  }, []);

  const flow = useMemo(() => flowFor(profile), [profile]);
  const idx = flow.indexOf(step);
  const total = flow.length;

  const goNext = useCallback(() => {
    const i = flow.indexOf(step);
    if (i >= 0 && i < flow.length - 1) {
      setStep(flow[i + 1]);
      setSearch("");
      setError(null);
    }
  }, [flow, step]);

  const goBack = useCallback(() => {
    const i = flow.indexOf(step);
    if (i > 0) {
      setStep(flow[i - 1]);
      setSearch("");
      setError(null);
    }
  }, [flow, step]);

  const restart = useCallback(() => {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      // ignore
    }
    setStep("welcome");
    setProfile("");
    setData(emptyData);
    setEtab(emptyEtab);
    setAccount(emptyAccount);
    setSearch("");
    setError(null);
  }, []);

  async function submitAccount() {
    setLoading(true);
    setError(null);

    const supabase = createClient();
    const { error: authError } = await supabase.auth.signUp({
      email: account.email,
      password: account.password,
      options: {
        data: {
          role: roleForOnboarding(profile, data.fonction),
          requested_access: "pro",
          onboarding_profile: profile,
          onboarding_data: data,
          onboarding_etablissement: profile === "commercant" ? etab : undefined,
        },
        emailRedirectTo: `${window.location.origin}/login?mode=pro`,
      },
    });

    setLoading(false);

    if (authError) {
      setError(authError.message);
      return;
    }

    goNext();
  }

  const etabOk = etab.nom.trim() !== "" && etab.adresse.trim() !== "" && etab.tel.trim() !== "";
  const score = passwordScore(account.password);
  const emailOk = /.+@.+\..+/.test(account.email);
  const confirmMismatch = account.confirm.length > 0 && account.confirm !== account.password;
  const accountOk = emailOk && account.password.length >= 8 && account.confirm === account.password && account.terms;

  const showWelcome = step === "welcome";
  const showChoice = step in CHOICE_CONFIG;
  const showList = step in LIST_CONFIG;
  const showForm = step === "etabInfo";
  const showAccount = step === "account";
  const showDone = step === "confirmation";
  const showDownload = step === "download";

  let canContinue = true;
  let continueLabel = "Continuer";
  if (showChoice) {
    const cfg = CHOICE_CONFIG[step as ChoiceStep];
    const current = cfg.field === "profile" ? profile : data[cfg.field as DataField];
    canContinue = Boolean(current);
  } else if (showList) {
    canContinue = Boolean(data[LIST_CONFIG[step as ListStep].field]);
  } else if (showForm) {
    canContinue = etabOk;
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
    if (steps.includes("reseau") && data.reseau) rows.push({ label: "Réseau", value: labelOf(RESEAUX, data.reseau) });
    if (steps.includes("mode") && data.mode) rows.push({ label: "Mode de conduite", value: labelOf(MODES, data.mode) });
    if (steps.includes("habilitation") && data.habilitation) rows.push({ label: "Habilitations", value: labelOf(HABILITATIONS, data.habilitation) });
    if (steps.includes("fonction") && data.fonction) rows.push({ label: "Fonction", value: labelOf(FONCTIONS, data.fonction) });
    if (steps.includes("zone") && data.zone) rows.push({ label: "Zone d'activité", value: labelOf(ZONES, data.zone) });
    if (steps.includes("typeCommerce") && data.typeCommerce) rows.push({ label: "Type de commerce", value: labelOf(COMMERCES, data.typeCommerce) });
    if (steps.includes("etabInfo") && etab.nom) rows.push({ label: "Établissement", value: etab.nom });
    if (steps.includes("genre") && data.genre) rows.push({ label: "Genre", value: labelOf(GENRES, data.genre) });
    return rows;
  }, [profile, data, etab.nom]);

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
              style={{ width: `${total > 1 ? Math.round((idx / (total - 1)) * 100) : 0}%` }}
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
                Étape {Math.max(idx, 1)} sur {total - 1}
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
                  {[Bus, Ticket, BadgeCheck, Car, Store].map((Icon, i) => (
                    <div key={i} className={styles.illustrationDot} style={{ animationDelay: `${i * 0.4}s` }}>
                      <div className={styles.illustrationCircle}>
                        <Icon size={22} />
                      </div>
                      <div className={styles.illustrationLine} />
                    </div>
                  ))}
                </div>

                <h1 className={styles.h1}>Bienvenue sur Aule Pro</h1>
                <p className={styles.welcomeSubtitle}>Configurez votre espace professionnel en quelques instants.</p>

                <button
                  type="button"
                  onClick={() => setStep("profile")}
                  className={`${styles.primaryButton} ${styles.welcomeButton}`}
                >
                  Commencer
                </button>
                <p className={styles.welcomeHint}>Moins de 30 secondes · Aucune carte requise</p>
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
                                  // champs des autres branches (typeCommerce, fonction, mode…)
                                  // restent renseignés et polluent le récap et le payload.
                                  setData(emptyData);
                                  setEtab(emptyEtab);
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
                const q = search.trim().toLowerCase();
                const filtered = cfg.items.filter(
                  (it) => !q || it.label.toLowerCase().includes(q) || (it.desc ?? "").toLowerCase().includes(q),
                );
                return (
                  <div>
                    <h2 className={styles.stepTitle}>{cfg.title}</h2>
                    <p className={styles.stepSubtitle}>{cfg.subtitle}</p>
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
                          De nouveaux réseaux et villes sont ajoutés régulièrement.
                        </div>
                      )}
                    </div>
                  </div>
                );
              })()}

            {showForm && (
              <div>
                <h2 className={styles.stepTitle}>Votre établissement</h2>
                <p className={styles.stepSubtitle}>Ces informations apparaîtront sur votre fiche Aule.</p>
                <div className={styles.fieldsCol}>
                  <label className={styles.field}>
                    <span className={styles.fieldLabel}>Nom de l&apos;établissement</span>
                    <input
                      type="text"
                      value={etab.nom}
                      onChange={(e) => setEtab((s) => ({ ...s, nom: e.target.value }))}
                      placeholder="Café Louna"
                      className={styles.input}
                    />
                  </label>
                  <label className={styles.field}>
                    <span className={styles.fieldLabel}>Adresse</span>
                    <input
                      type="text"
                      value={etab.adresse}
                      onChange={(e) => setEtab((s) => ({ ...s, adresse: e.target.value }))}
                      placeholder="12 rue de la Fosse, 44000 Nantes"
                      className={styles.input}
                    />
                  </label>
                  <div className={styles.fieldRow}>
                    <label className={styles.field}>
                      <span className={styles.fieldLabel}>Téléphone</span>
                      <input
                        type="tel"
                        value={etab.tel}
                        onChange={(e) => setEtab((s) => ({ ...s, tel: e.target.value }))}
                        placeholder="02 40 00 00 00"
                        className={styles.input}
                      />
                    </label>
                    <label className={styles.field}>
                      <span className={styles.fieldLabel}>
                        Site web <span className={styles.fieldOptional}>(facultatif)</span>
                      </span>
                      <input
                        type="text"
                        value={etab.site}
                        onChange={(e) => setEtab((s) => ({ ...s, site: e.target.value }))}
                        placeholder="cafelouna.fr"
                        className={styles.input}
                      />
                    </label>
                  </div>
                </div>
              </div>
            )}

            {showAccount && (
              <div>
                <h2 className={styles.stepTitle}>Créons votre compte</h2>
                <p className={styles.stepSubtitle}>Dernière étape avant d&apos;accéder à votre espace.</p>

                <div className={styles.ssoRow}>
                  <button type="button" disabled title="Bientôt disponible" className={styles.ssoButton}>
                    <svg width="17" height="17" viewBox="0 0 24 24">
                      <path
                        fill="#fff"
                        d="M21.35 11.1h-9.17v2.98h5.27c-.23 1.4-1.63 4.1-5.27 4.1-3.17 0-5.76-2.62-5.76-5.85s2.59-5.85 5.76-5.85c1.8 0 3.02.77 3.71 1.43l2.53-2.44C16.9 3.6 14.77 2.7 12.18 2.7 7.03 2.7 2.85 6.88 2.85 12.03s4.18 9.33 9.33 9.33c5.39 0 8.96-3.79 8.96-9.13 0-.61-.07-1.08-.16-1.55l-.63.42Z"
                      />
                    </svg>
                    Google
                  </button>
                  <button type="button" disabled title="Bientôt disponible" className={styles.ssoButton}>
                    <svg width="16" height="16" viewBox="0 0 24 24">
                      <path
                        fill="#fff"
                        d="M16.36 12.9c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.96.9-3.75 2.28-1.6 2.78-.41 6.89 1.15 9.14.76 1.1 1.67 2.34 2.86 2.29 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.12 2.76-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.65l.01-.34ZM14.13 5.9c.64-.77 1.07-1.85.95-2.92-.92.04-2.03.61-2.69 1.38-.59.68-1.11 1.77-.97 2.82 1.02.08 2.07-.52 2.71-1.28Z"
                      />
                    </svg>
                    Apple
                  </button>
                </div>

                <div className={styles.divider}>
                  <div className={styles.dividerLine} />
                  <span className={styles.dividerLabel}>ou par e-mail</span>
                  <div className={styles.dividerLine} />
                </div>

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
                      <a
                        href="#"
                        style={{ color: ACCENT, textDecoration: "none" }}
                        onClick={(e) => {
                          e.preventDefault();
                          e.stopPropagation();
                        }}
                      >
                        Conditions Générales d&apos;Utilisation
                      </a>
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
                <h2 className={styles.doneTitle}>Votre profil est prêt !</h2>
                <p className={styles.doneSubtitle}>Aule Pro est déjà configuré pour votre métier. Bienvenue à bord.</p>

                <div className={styles.recapCard}>
                  {recap.map((item) => (
                    <div key={item.label} className={styles.recapRow}>
                      <span className={styles.recapLabel}>{item.label}</span>
                      <span className={styles.recapValue}>{item.value}</span>
                    </div>
                  ))}
                </div>

                {!isMobile ? (
                  <div className={styles.qrCard}>
                    <span className={styles.qrBox}>
                      <QrCode size={34} />
                    </span>
                    <div>
                      <div className={styles.qrTextTitle}>Continuez sur mobile</div>
                      <div className={styles.qrTextDesc}>
                        Scannez ce code pour ouvrir Aule Pro sur votre téléphone. Votre profil vous suit automatiquement.
                      </div>
                    </div>
                  </div>
                ) : (
                  <p className={styles.mobileHint}>Téléchargez l&apos;app pour retrouver votre profil partout.</p>
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

                <button type="button" onClick={finishOnboarding} className={styles.primaryButton} style={{ marginTop: 20 }}>
                  Accéder à Aule Pro
                </button>
              </div>
            )}

            {showDownload && (
              <div className={styles.done}>
                <div className={styles.doneIconWrap}>
                  <span className={styles.doneRing} />
                  <span className={styles.doneCircle}>
                    <Smartphone size={40} strokeWidth={2.2} />
                  </span>
                </div>
                <h2 className={styles.doneTitle}>Poursuivez sur mobile</h2>
                <p className={styles.doneSubtitle}>
                  L&apos;inscription pour les conducteurs, contrôleurs et chauffeurs VTC s&apos;effectue exclusivement sur l&apos;application mobile Aule Pro.
                </p>

                {!isMobile ? (
                  <div className={styles.qrCard}>
                    <span className={styles.qrBox}>
                      <QrCode size={34} />
                    </span>
                    <div>
                      <div className={styles.qrTextTitle}>Téléchargez l&apos;application</div>
                      <div className={styles.qrTextDesc}>
                        Scannez ce code pour ouvrir Aule Pro sur votre téléphone et poursuivre votre inscription.
                      </div>
                    </div>
                  </div>
                ) : (
                  <p className={styles.mobileHint}>
                    Téléchargez l&apos;application Aule Pro ci-dessous pour poursuivre votre inscription.
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
            )}
          </div>

          {!showWelcome && !showDone && !showDownload && (
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
