export const navLinks = [
  { href: "#fonctionnalites", label: "Fonctionnalités" },
  { href: "#comment-ca-marche", label: "Comment ça marche" },
  { href: "#reseaux", label: "Réseaux couverts" },
  { href: "/pro", label: "Aule Pro" },
] as const;

export const problems = [
  {
    icon: "clock",
    title: "Attente incertaine",
    description:
      "Vous ne savez pas quand le prochain bus ou tram va arriver, ni s'il passera vraiment.",
  },
  {
    icon: "shuffle",
    title: "Correspondances stressantes",
    description:
      "Changer de ligne en urgence sans savoir si vous allez rater votre connexion.",
  },
  {
    icon: "alert",
    title: "Retards et perturbations",
    description:
      "Les infos trafic arrivent trop tard ou sont difficiles à comprendre.",
  },
  {
    icon: "map-pin",
    title: "Difficulté à trouver le bon arrêt",
    description:
      "Plusieurs arrêts proches, des noms similaires : difficile de savoir où attendre.",
  },
  {
    icon: "eye-off",
    title: "Manque de visibilité",
    description:
      "Impossible de voir où se trouve réellement votre véhicule sur le réseau.",
  },
] as const;

export const journeySteps = [
  {
    step: 1,
    title: "Trouver un itinéraire",
    description: "Saisissez votre destination, Aule calcule le meilleur trajet.",
    icon: "search",
  },
  {
    step: 2,
    title: "Marcher jusqu'à l'arrêt",
    description: "Guidage piéton jusqu'au bon arrêt, au bon quai.",
    icon: "footprints",
  },
  {
    step: 3,
    title: "Attendre le véhicule",
    description: "Temps d'attente en direct et alerte avant l'arrivée.",
    icon: "timer",
  },
  {
    step: 4,
    title: "Monter à bord",
    description: "Confirmation visuelle que c'est bien votre ligne.",
    icon: "bus",
  },
  {
    step: 5,
    title: "Suivre le trajet",
    description: "Progression en temps réel sur la carte, étape par étape.",
    icon: "route",
  },
  {
    step: 6,
    title: "Descendre au bon arrêt",
    description: "Alerte de descente avant votre arrêt, sans stress.",
    icon: "bell",
  },
] as const;

export const features = [
  {
    icon: "route",
    title: "Itinéraires intelligents",
    description:
      "Multimodal, optimisé temps réel avec correspondances et marche intégrées.",
  },
  {
    icon: "radio",
    title: "Suivi des véhicules en temps réel",
    description:
      "Positions certifiées et communautaires agrégées pour une fiabilité maximale.",
  },
  {
    icon: "bell-ring",
    title: "Alertes d'arrivée",
    description:
      "Notifications avant l'arrivée de votre bus, tram ou navibus.",
  },
  {
    icon: "map-pin",
    title: "Arrêts à proximité",
    description:
      "Découvrez les arrêts autour de vous avec horaires et lignes desservies.",
  },
  {
    icon: "compass",
    title: "Navigation immersive",
    description:
      "Guidage pas à pas avec carte sombre, zoom automatique et repères clairs.",
  },
  {
    icon: "alert-triangle",
    title: "Informations perturbations",
    description:
      "Retards, déviations et travaux remontés en direct sur votre trajet.",
  },
] as const;

export const immersiveHighlights = [
  {
    icon: "navigation",
    title: "Guidage étape par étape",
    description:
      "Chaque segment de trajet est clairement indiqué avec durée et mode de transport.",
    screen: "guidage",
  },
  {
    icon: "bell-ring",
    title: "Notifications contextuelles",
    description:
      "Alertes pertinentes au bon moment — arrivée, correspondance, perturbation — sans surcharge.",
    screen: "notifications",
  },
  {
    icon: "radio",
    title: "Suivi du véhicule en approche",
    description:
      "Visualisez votre bus ou tram avancer sur la carte en direct, jusqu'à l'arrêt.",
    screen: "suivi",
  },
  {
    icon: "log-out",
    title: "Alertes de descente",
    description:
      "Soyez alerté avant votre arrêt pour ne jamais le manquer, même les yeux ailleurs.",
    screen: "descente",
  },
  {
    icon: "arrow-right-left",
    title: "Correspondances simplifiées",
    description:
      "Instructions claires pour changer de ligne, trouver le bon quai et repartir sereinement.",
    screen: "correspondance",
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

export const testimonials = [
  {
    name: "Marie L.",
    role: "Étudiante",
    rating: 5,
    text: "Je ne rate plus jamais mon tram grâce aux alertes. L'app est claire et rassurante, même quand il y a des perturbations.",
    avatar: "ML",
  },
  {
    name: "Thomas K.",
    role: "Actif quotidien",
    rating: 5,
    text: "Le suivi en temps réel change tout. Je sais exactement quand partir de chez moi pour attraper mon bus.",
    avatar: "TK",
  },
  {
    name: "Sophie M.",
    role: "Touriste",
    rating: 4,
    text: "Visiter Nantes sans connaître le réseau était un défi. Aule m'a guidée du début à la fin, c'était fluide.",
    avatar: "SM",
  },
  {
    name: "Ahmed B.",
    role: "Voyageur occasionnel",
    rating: 5,
    text: "Les correspondances ne me stressent plus. L'app me dit exactement où aller et combien de temps j'ai.",
    avatar: "AB",
  },
] as const;

export const proModules = [
  {
    href: "/pro/regulateur",
    title: "Poste de contrôle",
    description:
      "Supervision flotte, incidents et régulation en temps réel pour les régulateurs.",
    icon: "monitor",
  },
  {
    href: "/pro/msr",
    title: "Missions sécurité réseau",
    description:
      "Planification et suivi des patrouilles MSR par secteur et zone de contrôle.",
    icon: "shield",
  },
  {
    href: "/pro/conducteur",
    title: "Mode conducteur",
    description:
      "Prise de service automatique par GPS, détection ligne et sens sans saisie.",
    icon: "steering-wheel",
  },
  {
    href: "/pro/admin",
    title: "Administration réseau",
    description:
      "Configuration réseau, utilisateurs, rôles et paramètres d'exploitation.",
    icon: "settings",
  },
] as const;

export const footerLinks = {
  product: [
    { href: "#fonctionnalites", label: "Fonctionnalités" },
    { href: "/pro", label: "Aule Pro" },
    { href: "#reseaux", label: "Réseaux couverts" },
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

export const appStoreUrl = "https://apps.apple.com/app/aule";
export const playStoreUrl =
  "https://play.google.com/store/apps/details?id=fr.aule.app";
