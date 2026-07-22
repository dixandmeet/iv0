export const navLinks = [
  { href: "#fonctionnalites", label: "Fonctionnalités" },
  { href: "#comment-ca-marche", label: "Comment ça marche" },
  { href: "#communaute", label: "Communauté" },
  { href: "#reseaux", label: "Réseaux" },
  { href: "/pro", label: "Aule Pro" },
] as const;

export const trustStats = [
  { value: "Temps réel", label: "Suivi véhicules" },
  { value: "Gratuit", label: "Pour les voyageurs" },
  { value: "Naolib", label: "Réseau pilote" },
] as const;

export const productSplit = {
  traveler: {
    eyebrow: "Application mobile",
    title: "Aule Voyageur",
    description:
      "Le GPS intelligent pour vos trajets quotidiens. Itinéraires, suivi temps réel, alertes et favoris — gratuit pour tous les usagers.",
    ctaPrimary: { href: "#telecharger", label: "Télécharger l'application" },
    highlights: [
      "Itinéraires multimodaux",
      "Favoris et trajets récurrents",
      "Plan du réseau interactif",
    ],
  },
  pro: {
    eyebrow: "Plateforme d'exploitation",
    title: "Aule Pro",
    description:
      "Poste de contrôle web, missions MSR, mode conducteur et administration réseau. Unifiez terrain et exploitation.",
    ctaPrimary: { href: "/pro", label: "Découvrir Aule Pro" },
    ctaSecondary: { href: "/login", label: "Espace Pro" },
    highlights: [
      "Supervision flotte et incidents",
      "Missions sécurité réseau",
      "Reporting et info-voyageur",
    ],
  },
} as const;

export const journeySteps = [
  {
    step: 1,
    title: "Rechercher",
    description: "Saisissez votre destination ou choisissez un trajet récurrent.",
    icon: "search",
  },
  {
    step: 2,
    title: "Se rendre à l'arrêt",
    description: "Guidage piéton jusqu'au bon quai.",
    icon: "footprints",
  },
  {
    step: 3,
    title: "Attendre",
    description: "Temps d'attente en direct et alerte avant l'arrivée.",
    icon: "timer",
  },
  {
    step: 4,
    title: "Monter",
    description: "Confirmation visuelle de votre ligne.",
    icon: "bus",
  },
  {
    step: 5,
    title: "Suivre",
    description: "Progression temps réel sur la carte.",
    icon: "route",
  },
  {
    step: 6,
    title: "Descendre",
    description: "Alerte de descente avant votre arrêt.",
    icon: "bell",
  },
] as const;

export type BentoFeature = {
  icon: string;
  title: string;
  description: string;
  size: "lg" | "sm";
};

export const bentoFeatures: BentoFeature[] = [
  {
    icon: "route",
    title: "Itinéraires intelligents",
    description:
      "Multimodal, optimisé temps réel avec correspondances et marche intégrées.",
    size: "lg",
  },
  {
    icon: "radio",
    title: "Suivi temps réel",
    description:
      "Positions opérateur et données disponibles selon le réseau pilote.",
    size: "lg",
  },
  {
    icon: "star",
    title: "Favoris arrêts et lignes",
    description: "Accès rapide à vos arrêts et lignes les plus fréquents.",
    size: "sm",
  },
  {
    icon: "home",
    title: "Trajets récurrents",
    description: "Domicile, Travail, École — un tap pour lancer l'itinéraire.",
    size: "sm",
  },
  {
    icon: "map",
    title: "Plan du réseau",
    description: "Carte interactive des lignes, arrêts et votre position.",
    size: "sm",
  },
  {
    icon: "accessibility",
    title: "Accessibilité PMR",
    description: "Arrêts adaptés avec recherche et tri par proximité.",
    size: "sm",
  },
  {
    icon: "bell-ring",
    title: "Alertes d'arrivée",
    description: "Notifications avant l'arrivée de votre véhicule.",
    size: "sm",
  },
  {
    icon: "compass",
    title: "Navigation immersive",
    description: "Guidage pas à pas avec zoom automatique et repères clairs.",
    size: "sm",
  },
  {
    icon: "alert-triangle",
    title: "Perturbations en direct",
    description: "Retards, déviations et travaux sur votre trajet.",
    size: "sm",
  },
  {
    icon: "map-pin",
    title: "Arrêts à proximité",
    description: "Horaires et lignes desservies autour de vous.",
    size: "sm",
  },
];

export const communityHighlights = [
  {
    icon: "shield",
    title: "Activation progressive",
    description:
      "Les contributions communautaires seront ouvertes réseau par réseau, après validation des règles de confidentialité.",
  },
  {
    icon: "clock",
    title: "Conservation limitée",
    description:
      "Chaque catégorie de donnée est soumise à une durée documentée et à une purge adaptée à son usage.",
  },
  {
    icon: "lock",
    title: "Conforme RGPD",
    description:
      "Consentement explicite, transparence totale. Vous contrôlez le partage depuis les réglages.",
  },
  {
    icon: "users",
    title: "Bientôt selon les réseaux",
    description:
      "Les signalements voyageurs ne sont pas encore généralisés à l'ensemble des réseaux.",
  },
] as const;

export const networks = [
  {
    id: "nantes",
    city: "Nantes",
    operator: "Naolib",
    status: "pilot" as const,
    modes: ["Bus", "Tram", "Navibus", "Chrono"],
    lat: 47.2184,
    lng: -1.5536,
  },
  {
    id: "paris",
    city: "Paris",
    operator: "Île-de-France Mobilités",
    status: "coming" as const,
    modes: ["Métro", "RER", "Bus", "Tram"],
    lat: 48.8566,
    lng: 2.3522,
  },
  {
    id: "lyon",
    city: "Lyon",
    operator: "TCL",
    status: "coming" as const,
    modes: ["Métro", "Tram", "Bus", "Funiculaire"],
    lat: 45.764,
    lng: 4.8357,
  },
  {
    id: "bordeaux",
    city: "Bordeaux",
    operator: "TBM",
    status: "coming" as const,
    modes: ["Tram", "Bus", "Navette"],
    lat: 44.8378,
    lng: -0.5792,
  },
] as const;

export const proModules = [
  {
    href: "/pro/exploitation",
    title: "Centre d'exploitation",
    description:
      "Supervision véhicules, incidents, équipes, missions et information voyageurs.",
    icon: "monitor",
  },
  {
    href: "/pro/controleur",
    title: "Espace contrôleur",
    description:
      "Missions, carte, contrôles, procès-verbaux, équipe et statistiques personnelles.",
    icon: "shield",
  },
  {
    href: "/pro/conducteur",
    title: "Espace conducteur",
    description:
      "Prise de service, planning, véhicule, navigation, messages et échanges.",
    icon: "steering-wheel",
  },
] as const;

export const footerLinks = {
  product: [
    { href: "#fonctionnalites", label: "Fonctionnalités" },
    { href: "#communaute", label: "Communauté" },
    { href: "/pro", label: "Aule Pro" },
    { href: "#reseaux", label: "Réseaux couverts" },
    { href: "/login", label: "Espace Pro" },
  ],
  support: [
    { href: "/aide", label: "Centre d'aide" },
    { href: "/confidentialite", label: "Confidentialité" },
    { href: "/conditions", label: "Conditions d'utilisation" },
    { href: "/contact", label: "Contact" },
  ],
  social: [
    { href: "https://twitter.com", label: "X (Twitter)", icon: "twitter" },
    { href: "https://linkedin.com", label: "LinkedIn", icon: "linkedin" },
    { href: "https://instagram.com", label: "Instagram", icon: "instagram" },
  ],
} as const;
