const navItems = [
  ["dashboard", "Dashboard", "layout-dashboard"],
  ["supervision", "Supervision", "radar"],
  ["exploitation", "Exploitation", "route"],
  ["utilisateurs", "Utilisateurs", "users"],
  ["missions", "Missions", "clipboard-check"],
  ["communication", "Communication", "send"],
  ["marketplace", "Marketplace", "store"],
  ["analytics", "Analytics", "chart-no-axes-combined"],
  ["administration", "Administration", "settings"],
];

let kpis = [
  ["Bus en circulation", 184, "+8%"],
  ["Trams en circulation", 46, "+3%"],
  ["VTC actifs", 92, "+14%"],
  ["Taxis actifs", 71, "+6%"],
  ["Voyageurs connectés", "42 819", "+12%"],
  ["Conducteurs connectés", 327, "+4%"],
  ["Contrôleurs connectés", 38, "+2%"],
  ["Commerçants ouverts", 214, "+9%"],
  ["Incidents", 7, "-3"],
  ["Signalements", 63, "+18"],
  ["Commandes en cours", 128, "+11%"],
  ["Livraisons", 42, "+5%"],
  ["Notifications aujourd'hui", "18 450", "+21%"],
  ["Services en cours", 233, "+2%"],
  ["Missions en cours", 31, "+7"],
  ["Utilisateurs actifs", "58 204", "+10%"],
];

let events = [
  ["Retard résorbé", "Ligne C1 · Commerce vers Gare Maritime", "18:44", "ok", "clock"],
  ["Signalement PMR", "Arrêt Duchesse Anne · rampe défectueuse", "18:39", "warn", "accessibility"],
  ["Incident prioritaire", "Tram T2 · intervention équipe Nord", "18:31", "danger", "triangle-alert"],
  ["Notification envoyée", "Perturbation ciblée vers 12 840 voyageurs", "18:25", "ok", "send"],
  ["Mission créée", "Contrôle quai 3 · validation superviseur", "18:18", "ok", "clipboard-check"],
];

let incidents = [
  ["Accident léger", "Boulevard de Doulon · ligne 12", "danger"],
  ["Objet abandonné", "Station Commerce · quai B", "warn"],
  ["Travaux voirie", "Rue Paul Bellamy · déviation bus", "warn"],
  ["Panne SAE", "Bus 4387 · dépôt Dalby", "danger"],
  ["Manifestation", "Centre-ville · périmètre dynamique", "warn"],
];

let missions = [
  { title: "Sécuriser correspondance T1/C3", team: "Équipe Alpha", status: "En cours", progress: 72, meta: "Commerce · 4 agents" },
  { title: "Contrôle billettique secteur Nord", team: "Équipe Delta", status: "Planifiée", progress: 28, meta: "Recteur Schmitt · 6 agents" },
  { title: "Assistance PMR arrêt Duchesse Anne", team: "Équipe Mobile", status: "Validation", progress: 91, meta: "ETA 6 min" },
  { title: "Repositionnement VTC événement", team: "Dispatch Pro", status: "En cours", progress: 58, meta: "Zénith · 18 véhicules" },
];

let users = [
  {
    id: "usr-lina-moreau",
    name: "Lina Moreau",
    profile: "Voyageur",
    role: "Client",
    network: "Naolib",
    depot: "Naolib",
    context: "iPhone 15 · actif",
    status: "Connecté",
    email: "lina.moreau@aule.app",
    phone: "+33 6 18 42 09 51",
    permissions: "Tickets, favoris, PMR",
    device: "iPhone 15",
    lastSeen: "Maintenant",
    history: ["Connexion mobile 19:24", "Achat ticket 18:42", "Favori Commerce mis à jour"],
    img: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=160&q=80",
  },
  {
    id: "usr-mathis-le-guen",
    name: "Mathis Le Guen",
    profile: "Conducteur",
    role: "Agent",
    network: "Dépôt Dalby",
    depot: "Dalby",
    context: "Service 342 · bus 4387",
    status: "Connecté",
    email: "mathis.le.guen@aule.app",
    phone: "+33 6 42 18 73 90",
    permissions: "Bus électrique, nuit",
    device: "Samsung S24",
    lastSeen: "Connecté depuis 06:58",
    history: ["Prise de service 06:58", "Contrôle véhicule validé", "Retard C6 signalé 18:31"],
    img: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=160&q=80",
  },
  {
    id: "usr-nora-benali",
    name: "Nora Benali",
    profile: "Contrôleuse",
    role: "Agent",
    network: "Secteur Centre",
    depot: "Centre",
    context: "Mission M-2049",
    status: "Connecté",
    email: "nora.benali@aule.app",
    phone: "+33 6 77 20 44 13",
    permissions: "Contrôle, PV, assistance",
    device: "iPad Mini",
    lastSeen: "Mission active",
    history: ["Mission M-2049 ouverte", "Contrôle quai 3 terminé", "Signalement PMR transmis"],
    img: "https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=160&q=80",
  },
  {
    id: "usr-adrien-faure",
    name: "Adrien Faure",
    profile: "Commerçant",
    role: "Commerce",
    network: "Marché Talensac",
    depot: "Talensac",
    context: "Boutique ouverte",
    status: "À vérifier",
    email: "adrien.faure@aule.app",
    phone: "+33 2 40 11 83 72",
    permissions: "Catalogue, commandes",
    device: "Chrome · Mac",
    lastSeen: "18:12",
    history: ["KYC demandé", "Catalogue modifié", "Paiement en attente de validation"],
    img: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=160&q=80",
  },
  {
    id: "usr-camille-herve",
    name: "Camille Hervé",
    profile: "Superviseur",
    role: "Superviseur",
    network: "PC Exploitation",
    depot: "PC Exploitation",
    context: "Connectée depuis 07:12",
    status: "Connecté",
    email: "camille.herve@aule.app",
    phone: "+33 6 05 91 42 36",
    permissions: "Supervision, incidents, exports",
    device: "Chrome · Windows",
    lastSeen: "Connectée depuis 07:12",
    history: ["Incident C6 priorisé", "Consigne réseau envoyée", "Export ponctualité généré"],
    img: "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=160&q=80",
  },
];

const utilisateurState = {
  query: "",
  profile: "all",
  role: "all",
  depot: "all",
  status: "all",
  selectedId: "usr-mathis-le-guen",
  imported: false,
  invitedCount: 0,
};

let merchants = [
  ["Maison Arlot", "Boulangerie · Talensac", "98 commandes", "4.9", "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=900&q=80"],
  ["Café Feydeau", "Coffee shop · Commerce", "42 commandes", "4.7", "https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&w=900&q=80"],
  ["Atelier Vélo", "Services · Île de Nantes", "17 livraisons", "4.8", "https://images.unsplash.com/photo-1485965120184-e220f721d03e?auto=format&fit=crop&w=900&q=80"],
];

let vehicles = [
  ["Bus 4387", "Mercedes eCitaro", "Service C6 · +3 min", "82% batterie", "https://images.unsplash.com/photo-1570125909232-eb263c188f7e?auto=format&fit=crop&w=900&q=80"],
  ["Tram 091", "Alstom Citadis", "Ligne T1 · nominal", "Charge 67%", "https://images.unsplash.com/photo-1558346648-9757f2fa4474?auto=format&fit=crop&w=900&q=80"],
  ["VTC Pro 221", "Tesla Model Y", "Course aéroport", "ETA 12 min", "https://images.unsplash.com/photo-1560958089-b8a1929cea89?auto=format&fit=crop&w=900&q=80"],
];

let searchIndex = [
  ["Utilisateur", "Lina Moreau", "Voyageur connecté · quartier Graslin", "users"],
  ["Bus", "Bus 4387", "Retard +3 min · prochain arrêt Gare Sud", "bus"],
  ["Tram", "Tram 091", "Ligne T1 · fréquence nominale", "train-front"],
  ["VTC", "VTC Pro 221", "Course aéroport · paiement validé", "car"],
  ["Taxi", "Taxi 74", "Station Commerce · disponible", "car-taxi-front"],
  ["Mission", "M-2049", "Assistance PMR · équipe mobile", "clipboard-check"],
  ["Signalement", "SIG-9831", "Objet abandonné · quai B", "triangle-alert"],
  ["Arrêt", "Duchesse Anne", "Accessibilité perturbée", "map-pin"],
  ["Ligne", "C1", "Commerce vers Gare Maritime", "route"],
  ["Commande", "CMD-7732", "Maison Arlot · livraison en cours", "package"],
  ["Commerce", "Café Feydeau", "Ouvert · temps moyen 8 min", "store"],
  ["Produit", "Formule express", "Stock 37 · promotion active", "shopping-bag"],
  ["Notification", "NOTIF-421", "Perturbation T2 · 12 840 destinataires", "send"],
];

const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
let liveDataMeta = {
  label: "Simulation",
  detail: "Données de démonstration",
  loadedAt: null,
  status: "warn",
};
let liveMapMarkers = null;
let liveRefreshMs = 60000;
let liveSupabase = null;

function icon(name) {
  return `<i data-lucide="${name}"></i>`;
}

function sourceResult(data, key) {
  return data?.sources?.[key]?.ok ? data.sources[key].data : null;
}

function sourceError(data, key) {
  return data?.sources?.[key]?.ok ? null : data?.sources?.[key]?.error;
}

function supabasePayload(data) {
  const result = sourceResult(data, "supabase");
  return result?.configured ? result : null;
}

function supabaseRows(payload, key) {
  const table = payload?.[key];
  return table?.ok && Array.isArray(table.data) ? table.data : [];
}

function numberFormat(value) {
  if (value === null || value === undefined || value === "") return "N/D";
  if (typeof value === "string" && Number.isNaN(Number(value))) return value;
  return new Intl.NumberFormat("fr-FR").format(Number(value));
}

function sum(records, field) {
  return records.reduce((total, record) => total + Number(record[field] || 0), 0);
}

function shortDateTime(value) {
  if (!value) return "maintenant";
  return new Intl.DateTimeFormat("fr-FR", {
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "2-digit",
    timeZone: "Europe/Paris",
  }).format(new Date(value));
}

function truncate(value, length = 92) {
  if (!value) return "";
  return value.length > length ? `${value.slice(0, length - 1)}…` : value;
}

function normalizeSearch(value) {
  return String(value || "")
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function dedupeBy(records, getKey) {
  const seen = new Set();
  return records.filter((record) => {
    const key = getKey(record);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function projectNantes(position) {
  if (!position?.lon || !position?.lat) return null;
  const bounds = {
    west: -1.66,
    east: -1.47,
    south: 47.16,
    north: 47.29,
  };
  const left = ((position.lon - bounds.west) / (bounds.east - bounds.west)) * 100;
  const top = ((bounds.north - position.lat) / (bounds.north - bounds.south)) * 100;
  return {
    left: Math.max(3, Math.min(94, left)),
    top: Math.max(7, Math.min(88, top)),
  };
}

function applyRealData(data) {
  liveRefreshMs = Number(data.config?.refreshMs || liveRefreshMs);
  const supabase = supabasePayload(data);
  liveSupabase = supabase;
  const supabaseSources = supabaseRows(supabase, "sources");
  const supabaseServices = supabaseRows(supabase, "services");
  const supabaseSegments = supabaseRows(supabase, "segments");
  const supabaseDrivers = supabaseRows(supabase, "drivers");
  const bikesPayload = sourceResult(data, "bikes");
  const parkRelaysPayload = sourceResult(data, "parkRelays");
  const publicParkingsPayload = sourceResult(data, "publicParkings");
  const trafficPayload = sourceResult(data, "trafficAlerts");
  const carsharePayload = sourceResult(data, "carshareStations");
  const servicesPayload = sourceResult(data, "transportServices");
  const realtimePayload = sourceResult(data, "realtimeCatalog");

  const bikeStations = bikesPayload?.results || [];
  const parkRelays = parkRelaysPayload?.results || [];
  const publicParkings = publicParkingsPayload?.results || [];
  const trafficAlerts = dedupeBy(trafficPayload?.results || [], (alert) => `${alert.nom}|${alert.detail}`);
  const carshareStations = carsharePayload?.results || [];
  const services = servicesPayload?.results || [];
  const realtimeServices = realtimePayload?.results || [];
  const okinaConnected = (data.okinaFeeds || []).filter((feed) => feed.ok).length;
  const okinaTokenRequired = (data.okinaFeeds || []).some((feed) => feed.status === "token requis");

  const totalBikes = sum(bikeStations, "available_bikes");
  const totalBikeStands = sum(bikeStations, "bike_stands");
  const totalParkRelayPlaces = sum(parkRelays, "grp_disponible");
  const totalPublicParkingPlaces = sum(publicParkings, "grp_disponible");
  const openCarshareStations = carshareStations.length;
  const supabaseConnected = Boolean(supabase);
  const supabaseServicesLabel = supabaseConnected ? numberFormat(supabaseServices.length) : "Config";
  const supabaseSegmentsLabel = supabaseConnected ? numberFormat(supabaseSegments.length) : "Config";
  const supabaseDriversLabel = supabaseConnected && supabaseDrivers.length ? numberFormat(supabaseDrivers.length) : "Config";

  kpis = [
    ["Bus en circulation", okinaConnected ? "Flux actif" : "Token", okinaTokenRequired ? "Okina requis" : `${okinaConnected} flux`],
    ["Trams en circulation", okinaConnected ? "Flux actif" : "Token", "GTFS-RT"],
    ["Vélos disponibles", numberFormat(totalBikes), `${numberFormat(bikeStations.length)} stations`],
    ["Places vélos libres", numberFormat(sum(bikeStations, "available_bike_stands")), `${numberFormat(totalBikeStands)} bornes`],
    ["P+R places libres", numberFormat(totalParkRelayPlaces), `${numberFormat(parkRelays.length)} parcs`],
    ["Parkings publics libres", numberFormat(totalPublicParkingPlaces), `${numberFormat(publicParkings.length)} parkings`],
    ["Stations autopartage", numberFormat(openCarshareStations), "Naolib réel"],
    ["Alertes trafic", numberFormat(trafficAlerts.length), "Nantes Métropole"],
    ["Incidents", numberFormat(trafficAlerts.length), trafficAlerts.length ? "source réelle" : "aucun actif"],
    ["Services Supabase", supabaseServicesLabel, supabaseConnected ? "BDD" : "Supabase"],
    ["Segments Supabase", supabaseSegmentsLabel, supabaseConnected ? "BDD" : "Supabase"],
    ["Conducteurs BDD", supabaseDriversLabel, supabaseDrivers.length ? "Supabase" : "table optionnelle"],
    ["Notifications aujourd'hui", "API Aule", "à connecter"],
    ["Sources roulements", supabaseConnected ? numberFormat(supabaseSources.length) : numberFormat(services.length || realtimeServices.length), supabaseConnected ? "Supabase" : "catalogue Naolib"],
    ["Missions en cours", "API Aule", "à connecter"],
    ["Utilisateurs actifs", "API Aule", "à connecter"],
  ];

  if (supabaseDrivers.length) {
    const supabaseUsers = supabaseDrivers.slice(0, 24).map((driver, index) => {
      const firstName = driver.first_name || driver.firstname || driver.prenom || "";
      const lastName = driver.last_name || driver.lastname || driver.nom || "";
      const name = `${firstName} ${lastName}`.trim() || driver.full_name || driver.name || `Conducteur ${driver.employee_id || index + 1}`;
      const depot = driver.default_depot || driver.depot_code || driver.depot || "Dépôt";
      const service = driver.default_service || driver.service || "Service";
      const employeeId = driver.employee_id || driver.id || index + 1;
      return {
        id: `supabase-driver-${employeeId}`,
        name,
        profile: "Conducteur",
        role: "Agent",
        network: depot,
        depot,
        context: `${service} · matricule ${employeeId}`,
        status: "Connecté",
        email: driver.email || `${normalizeSearch(name).replaceAll(" ", ".")}@aule.app`,
        phone: driver.phone || "N/D",
        permissions: driver.license || "Conduite, service",
        device: driver.device || "Terminal conducteur",
        lastSeen: driver.updated_at ? shortDateTime(driver.updated_at) : "BDD Supabase",
        history: [`Import BDD ${shortDateTime(data.loadedAt)}`, `${service} affecté`, `${depot} rattaché`],
        img: `https://api.dicebear.com/8.x/initials/svg?seed=${encodeURIComponent(name)}`,
      };
    });
    users = [...users.filter((user) => !user.id.startsWith("supabase-driver-")), ...supabaseUsers];
  }

  incidents = trafficAlerts.length ? trafficAlerts.slice(0, 8).map((alert) => [
    alert.nom || "Alerte trafic",
    `${alert.secteur || "Nantes Métropole"} · ${truncate(alert.detail, 86)}`,
    "warn",
  ]) : [["Aucune alerte trafic", "Flux Nantes Métropole chargé", "ok"]];

  events = [
    ...supabaseServices.slice(0, 3).map((service) => [
      `Service ${service.service_no || service.service_key}`,
      `${service.depot_code || service.depot_name || "Dépôt"} · ${service.start_time || "N/D"} ${service.start_place || ""} → ${service.end_time || "N/D"} ${service.end_place || ""}`,
      "BDD",
      "ok",
      "database",
    ]),
    ...trafficAlerts.slice(0, 5).map((alert) => [
      alert.nom || "Alerte trafic",
      `${alert.secteur || "Nantes Métropole"} · ${truncate(alert.detail, 90)}`,
      shortDateTime(alert.date_notification),
      "warn",
      "triangle-alert",
    ]),
    ...bikeStations.slice(0, 2).map((station) => [
      `Station vélo ${station.name}`,
      `${station.available_bikes} vélo(s) disponible(s), ${station.available_bike_stands} place(s) libre(s)`,
      shortDateTime(station.last_update),
      "ok",
      "bike",
    ]),
  ].slice(0, 7);

  vehicles = [
    ...realtimeServices.map((service) => [
      service.id,
      service.description,
      data.okinaFeeds?.find((feed) => feed.id === service.id)?.status || "catalogue",
      service.url ? "endpoint référencé" : "documentation",
      "https://images.unsplash.com/photo-1570125909232-eb263c188f7e?auto=format&fit=crop&w=900&q=80",
    ]),
  ].slice(0, 3);

  if (!vehicles.length) {
    vehicles = [["GTFS-RT véhicules", "Positions véhicules Naolib", "Source indisponible", "Token requis", "https://images.unsplash.com/photo-1570125909232-eb263c188f7e?auto=format&fit=crop&w=900&q=80"]];
  }

  searchIndex = [
    ...supabaseServices.slice(0, 80).map((service) => [
      "Service",
      service.service_no || service.service_key,
      `${service.depot_code || service.depot_name || "Dépôt"} · ${service.start_time || "N/D"} ${service.start_place || ""} → ${service.end_time || "N/D"} ${service.end_place || ""}`,
      "route",
    ]),
    ...supabaseSegments.slice(0, 80).map((segment) => [
      "Segment",
      `${segment.service_no || segment.service_key} · ${segment.vehicle || "véhicule"}`,
      `${segment.debut_conduite_heure || "N/D"} ${segment.debut_conduite_lieu || ""} → ${segment.fin_conduite_heure || "N/D"} ${segment.fin_conduite_lieu || ""}`,
      "waypoints",
    ]),
    ...supabaseDrivers.slice(0, 80).map((driver, index) => {
      const firstName = driver.first_name || driver.firstname || driver.prenom || "";
      const lastName = driver.last_name || driver.lastname || driver.nom || "";
      const name = `${firstName} ${lastName}`.trim() || driver.full_name || driver.name || `Conducteur ${driver.employee_id || index + 1}`;
      return ["Conducteur", name, `${driver.default_depot || "Dépôt"} · ${driver.default_service || "Service"}`, "user-round"];
    }),
    ...bikeStations.slice(0, 20).map((station) => ["Station vélo", station.name, `${station.available_bikes} vélos · ${station.address || "Nantes"}`, "bike"]),
    ...parkRelays.slice(0, 12).map((parking) => ["P+R", parking.grp_nom || parking.nom_complet, `${parking.grp_disponible} places · ${parking.adresse || "Nantes Métropole"}`, "square-parking"]),
    ...publicParkings.slice(0, 12).map((parking) => ["Parking", parking.grp_nom, `${parking.grp_disponible} places libres`, "square-parking"]),
    ...carshareStations.slice(0, 12).map((station) => ["Autopartage", station.nom, `${station.commune} · ${station.adresse}`, "car"]),
    ...trafficAlerts.slice(0, 12).map((alert) => ["Alerte trafic", alert.nom, `${alert.secteur} · ${truncate(alert.detail, 72)}`, "triangle-alert"]),
    ...searchIndex,
  ];

  liveMapMarkers = [
    ...bikeStations.slice(0, 28).map((station) => {
      const projected = projectNantes(station.position);
      return projected && ["bike", "bike", projected.left, projected.top, `${station.name} · ${station.available_bikes} vélos`];
    }).filter(Boolean),
    ...parkRelays.slice(0, 16).map((parking) => {
      const projected = projectNantes(parking.location);
      return projected && ["parking", "square-parking", projected.left, projected.top, `${parking.grp_nom} · ${parking.grp_disponible} places`];
    }).filter(Boolean),
    ...carshareStations.slice(0, 16).map((station) => {
      const projected = projectNantes({ lon: station.x_wgs84, lat: station.y_wgs84 });
      return projected && ["vtc", "car", projected.left, projected.top, `${station.nom} · autopartage`];
    }).filter(Boolean),
    ...trafficAlerts.slice(0, 5).map((alert, index) => ["incident", "triangle-alert", 22 + index * 12, 30 + index * 8, alert.nom]),
  ];

  const failedSources = Object.keys(data.sources || {}).filter((key) => !data.sources[key].ok && key !== "auleApi");
  const supabaseStatus = supabaseConnected
    ? ` · Supabase ${numberFormat(supabaseServices.length)} services`
    : " · Supabase non configuré";

  liveDataMeta = {
    label: failedSources.length || okinaTokenRequired ? "Partiel" : "Open data live",
    detail: `${bikeStations.length} stations vélo · ${parkRelays.length + publicParkings.length} parkings · ${trafficAlerts.length} alertes${supabaseStatus}`,
    loadedAt: data.loadedAt,
    status: failedSources.length || okinaTokenRequired ? "warn" : "ok",
    failedSources,
    sourceErrors: failedSources.map((key) => `${key}: ${sourceError(data, key)}`),
  };

  updateDataSourcePill();
}

function updateDataSourcePill() {
  const pill = $("#dataSourcePill");
  if (!pill) return;
  const time = liveDataMeta.loadedAt ? shortDateTime(liveDataMeta.loadedAt) : "simulation";
  pill.classList.toggle("warn", liveDataMeta.status !== "ok");
  pill.innerHTML = `${icon(liveDataMeta.status === "ok" ? "database-zap" : "database-backup")}<span>${liveDataMeta.label} · ${time}</span>`;
  pill.title = liveDataMeta.detail;
}

function initNav() {
  const nav = $("#primaryNav");
  nav.innerHTML = navItems.map(([id, label, iconName], index) => `
    <button class="nav-button ${index === 0 ? "active" : ""}" data-page="${id}" type="button">
      ${icon(iconName)}
      <span>${label}</span>
    </button>
  `).join("");

  nav.addEventListener("click", (event) => {
    const button = event.target.closest(".nav-button");
    if (!button) return;
    setActivePage(button.dataset.page);
  });
}

function setActivePage(id) {
  $$(".nav-button").forEach((button) => button.classList.toggle("active", button.dataset.page === id));
  $$(".page").forEach((page) => page.classList.toggle("active", page.id === id));
  $(".sidebar").classList.remove("open");
  window.scrollTo({ top: 0, behavior: "smooth" });
  refreshIcons();
}

function pageHeader(eyebrow, title, description, actions = "") {
  return `
    <div class="page-header">
      <div>
        <span class="eyebrow">${eyebrow}</span>
        <h1>${title}</h1>
        <p>${description}</p>
      </div>
      <div class="header-actions">${actions}</div>
    </div>
  `;
}

function renderKpis(items = kpis) {
  return `<div class="kpi-grid">${items.map(([label, value, trend]) => `
    <article class="kpi-card">
      <span class="label">${label}</span>
      <strong class="value">${value}</strong>
      <span class="trend">${trend}</span>
    </article>
  `).join("")}</div>`;
}

function renderMap({ supervision = false, dock = false } = {}) {
  const markers = liveMapMarkers || [
    ["bus", "bus", 21, 24], ["tram", "train-front", 56, 31], ["vtc", "car", 73, 42],
    ["taxi", "car-taxi-front", 34, 67], ["incident", "triangle-alert", 64, 58], ["commerce", "store", 47, 48],
    ["team", "shield-check", 29, 52], ["user", "user-round", 82, 70], ["bus", "bus", 16, 78],
    ["tram", "train-front", 68, 24], ["commerce", "store", 39, 35], ["incident", "triangle-alert", 52, 77],
  ];

  return `
    <div class="panel map-panel ${supervision ? "supervision-map" : ""}">
      <div class="map-canvas">
        <div class="map-river"></div>
        <div class="map-road road-a"></div>
        <div class="map-road road-b"></div>
        <div class="map-road road-c"></div>
        <div class="map-line line-green"></div>
        <div class="map-line line-blue"></div>
        <div class="map-line line-yellow"></div>
        ${markers.map(([type, iconName, left, top, title], index) => `
          <button class="marker ${type}" style="left:${left}%;top:${top}%;animation-delay:${index * 110}ms" title="${title || type}">
            ${icon(iconName)}
          </button>
        `).join("")}
      </div>
      <div class="map-toolbar">
        ${["plus", "minus", "scan-search", "waypoints", "ruler", "lasso-select", "history"].map((name) => `
          <button class="icon-button" type="button" title="${name}">${icon(name)}</button>
        `).join("")}
      </div>
      <div class="map-card">
        <strong>${liveDataMeta.label} · Naolib</strong>
        <span>${liveDataMeta.detail}. Les positions véhicules GTFS-RT directes nécessitent un token Okina quand la source répond 401.</span>
        <div class="card-row" style="margin-top:12px">
          <span class="severity ${liveDataMeta.status}">${liveDataMeta.status === "ok" ? "Connecté" : "Partiel"}</span>
          <span class="severity warn">${liveDataMeta.loadedAt ? shortDateTime(liveDataMeta.loadedAt) : "Simulation"}</span>
        </div>
      </div>
      ${dock ? `
        <div class="timeline-dock">
          <div class="timeline-track">
            ${[
              ["18:10", "T1 renforcée", ""], ["18:16", "Incident C6", "warn"], ["18:24", "Mission M-2049", ""],
              ["18:31", "Objet abandonné", "danger"], ["18:37", "Message voyageurs", ""], ["18:44", "Retard résorbé", ""],
              ["18:51", "Contrôle quai 3", "warn"], ["19:00", "Plan soirée", ""],
            ].map(([time, label, tone]) => `<div class="timeline-tick ${tone}"><strong>${time}</strong><span>${label}</span></div>`).join("")}
          </div>
        </div>` : `
        <div class="map-legend">
          ${(liveMapMarkers ? ["bike", "parking", "vtc", "incident"] : ["bus", "tram", "vtc", "taxi", "commerce", "user", "team", "incident"]).map((type) => `
            <span class="legend-item"><span class="legend-dot ${type}"></span>${type}</span>
          `).join("")}
        </div>`}
    </div>
  `;
}

function renderEvents(title = "Timeline des événements") {
  return `
    <article class="panel">
      <div class="panel-header">
        <div><h2>${title}</h2><p>Chronologie consolidée réseau, terrain et marketplace</p></div>
        <button class="ghost-button" type="button">${icon("filter")}Filtrer</button>
      </div>
      <div class="panel-body stack">
        ${events.map(([title, desc, time, severity, iconName]) => `
          <div class="event-item">
            <div class="event-icon">${icon(iconName)}</div>
            <div><strong>${title}</strong><span>${desc}</span></div>
            <span class="event-time">${time}</span>
          </div>
        `).join("")}
      </div>
    </article>
  `;
}

function renderDashboard() {
  $("#dashboard").innerHTML = `
    ${pageHeader("Vue globale", "Dashboard Administrateur", "Pilotage temps réel de l'écosystème Aule : transport, utilisateurs, missions, marketplace et communication depuis une interface unique.", `
      <button class="ghost-button">${icon("download")}Exporter</button>
      <button class="primary-button">${icon("radio-tower")}Ouvrir le live</button>
    `)}
    ${renderKpis()}
    <div class="grid-main">
      ${renderMap()}
      <div class="stack">
        ${renderEvents("Activité récente")}
        <article class="panel">
          <div class="panel-header"><div><h2>Alertes critiques</h2><p>Flux Nantes Métropole et incidents Aule connectables</p></div><span class="severity ${incidents.length ? "warn" : "ok"}">${incidents.length} actives</span></div>
          <div class="panel-body stack">
            ${incidents.slice(0, 3).map(([title, desc, severity]) => `<div class="list-item"><strong>${title}</strong><span>${desc}</span><div style="margin-top:10px"><span class="severity ${severity}">${severity === "danger" ? "Critique" : "À surveiller"}</span></div></div>`).join("")}
          </div>
        </article>
      </div>
    </div>
    <div class="grid-three" style="margin-top:18px">
      <article class="panel"><div class="panel-header"><h2>Derniers signalements</h2></div><div class="panel-body stack">${events.slice(1,4).map(([a,b]) => `<div class="list-item"><strong>${a}</strong><span>${b}</span></div>`).join("")}</div></article>
      <article class="panel"><div class="panel-header"><h2>Sources connectées</h2></div><div class="panel-body stack">${[liveDataMeta.detail, ...(liveDataMeta.sourceErrors || [])].slice(0, 4).map((n) => `<div class="list-item"><strong>${liveDataMeta.label}</strong><span>${n}</span></div>`).join("")}</div></article>
      <article class="panel"><div class="panel-header"><h2>États UX prévus</h2></div><div class="panel-body stack"><div class="loading-state"><div class="skeleton"><span></span><span></span><span></span></div></div><div class="empty-state">Aucun élément vide sans action : chaque écran propose créer, filtrer ou importer.</div></div></article>
    </div>
  `;
}

function renderSupervision() {
  $("#supervision").innerHTML = `
    ${pageHeader("PC Exploitation", "Centre de Supervision", "Une vue opérationnelle plein écran pour comprendre, prioriser et agir sur le réseau en moins de dix secondes.", `
      <button class="ghost-button">${icon("message-square-warning")}Consigne</button>
      <button class="primary-button">${icon("triangle-alert")}Déclarer incident</button>
    `)}
    <div class="supervision-layout">
      <aside class="side-rail">
        ${railPanel("Missions", missions.map((m) => [m.title, `${m.team} · ${m.status}`, "ok"]))}
        ${railPanel("Équipes terrain", [["Alpha", "4 agents · Commerce", "ok"], ["Delta", "6 agents · Nord", "warn"], ["Mobile PMR", "ETA 6 min", "ok"]])}
        ${railPanel("Messages & consignes", [["Consigne 18:30", "Priorité aux correspondances T1/C3", "ok"], ["Historique", "42 actions aujourd'hui", "ok"]])}
      </aside>
      ${renderMap({ supervision: true, dock: true })}
      <aside class="side-rail">
        ${railPanel("Incidents", incidents)}
        ${railPanel("Retards & perturbations", [["T2", "+8 min · matériel roulant", "warn"], ["C6", "+3 min · trafic", "warn"], ["Navette aéroport", "nominal", "ok"]])}
        ${railPanel("Commandes & commerces", [["Maison Arlot", "18 commandes en préparation", "ok"], ["Café Feydeau", "Stock faible formule midi", "warn"], ["Livreurs", "42 actifs", "ok"]])}
      </aside>
    </div>
  `;
}

function railPanel(title, rows) {
  return `
    <article class="rail-panel">
      <div class="panel-header"><h3>${title}</h3><span class="severity ok">${rows.length}</span></div>
      <div class="panel-body dense-list">
        ${rows.map(([a,b,c]) => `<div class="dense-item"><div><strong>${a}</strong><span>${b}</span></div><span class="severity ${c || "ok"}">${c === "danger" ? "P1" : c === "warn" ? "P2" : "OK"}</span></div>`).join("")}
      </div>
    </article>
  `;
}

function renderExploitation() {
  const tabs = ["Réseaux", "Dépôts", "Lignes", "Arrêts", "Véhicules"];
  const supabaseServices = supabaseRows(liveSupabase, "services");
  const supabaseSources = supabaseRows(liveSupabase, "sources");
  const serviceRows = supabaseServices.slice(0, 8);
  $("#exploitation").innerHTML = `
    ${pageHeader("Gestion réseau", "Exploitation", "Configuration multi-réseaux et suivi détaillé des dépôts, lignes, arrêts, véhicules, services et historiques.", `
      <button class="ghost-button">${icon("archive")}Archiver</button>
      <button class="primary-button">${icon("plus")}Créer un réseau</button>
    `)}
    <div class="section-tabs">${tabs.map((tab, i) => `<button class="${i === 0 ? "active" : ""}" data-exploitation-tab="${tab}">${tab}</button>`).join("")}</div>
    <div class="module-grid">
      <div class="stack">
        ${entityCard("Naolib", "Nantes · France", [["Fuseau", "Europe/Paris"], ["Langue", "Français"], ["Exploitant", "Semitan"], ["Dépôts", "7 actifs"], ["Lignes", "92"], ["Véhicules", "618"]])}
        ${entityCard("Dépôt Dalby", "Bus électriques · maintenance légère", [["Agents", "84"], ["Services", "63"], ["Disponibilité", "97%"], ["Historique", "12 804 trajets"]])}
      </div>
      <div class="stack">
        <article class="panel">
          <div class="panel-header">
            <div><h2>Services Supabase</h2><p>${liveSupabase ? `${numberFormat(supabaseServices.length)} services · ${numberFormat(supabaseSources.length)} sources chargées depuis la BDD` : "Renseigner supabase.url et supabase.anonKey dans config.json"}</p></div>
            <span class="severity ${liveSupabase ? "ok" : "warn"}">${liveSupabase ? "BDD" : "Config"}</span>
          </div>
          ${serviceRows.length ? `
            <table class="table">
              <thead><tr><th>Service</th><th>Dépôt</th><th>Début</th><th>Fin</th><th>Segments</th></tr></thead>
              <tbody>${serviceRows.map((service) => `
                <tr>
                  <td><strong>${service.service_no || service.service_key}</strong><br><span class="muted">${service.rlt_code || service.edition || ""}</span></td>
                  <td>${service.depot_code || service.depot_name || "N/D"}</td>
                  <td>${service.start_time || "N/D"} · ${service.start_place || ""}</td>
                  <td>${service.end_time || "N/D"} · ${service.end_place || ""}</td>
                  <td>${service.segment_count || "N/D"}</td>
                </tr>
              `).join("")}</tbody>
            </table>
          ` : `<div class="panel-body"><div class="empty-state">Aucun service Supabase chargé. Vérifie l'URL, la clé anon et les politiques RLS en lecture.</div></div>`}
        </article>
        <article class="panel">
          <div class="panel-header"><div><h2>Plan de ligne C1</h2><p>Carte, arrêts, temps réel, commentaires, fréquentation et perturbations.</p></div><span class="severity ok">Nominal</span></div>
          ${renderMap()}
        </article>
        <article class="panel">
          <div class="panel-header"><h2>Véhicules suivis</h2></div>
          <div class="panel-body grid-three">${vehicles.map(([name, model, service, state, img]) => vehicleCard(name, model, service, state, img)).join("")}</div>
        </article>
      </div>
    </div>
  `;
}

function entityCard(title, subtitle, meta) {
  return `
    <article class="entity-card">
      <div class="entity-top">
        <div><h3>${title}</h3><span class="muted">${subtitle}</span></div>
        <span class="severity ok">Actif</span>
      </div>
      <div class="meta-grid">${meta.map(([label, value]) => `<div class="meta-box"><span>${label}</span><strong>${value}</strong></div>`).join("")}</div>
      <div class="inline-actions">
        <button class="ghost-button">${icon("pencil")}Modifier</button>
        <button class="ghost-button">${icon("settings")}Configurer</button>
      </div>
    </article>
  `;
}

function vehicleCard(name, model, service, state, img) {
  return `
    <article class="vehicle-card">
      <img src="${img}" alt="${name}" />
      <div class="panel-body">
        <div class="entity-top"><div><h3>${name}</h3><span class="muted">${model}</span></div><span class="severity ok">GPS</span></div>
        <div class="meta-grid">
          <div class="meta-box"><span>Service actuel</span><strong>${service}</strong></div>
          <div class="meta-box"><span>État</span><strong>${state}</strong></div>
          <div class="meta-box"><span>Vitesse</span><strong>31 km/h</strong></div>
          <div class="meta-box"><span>Prochain arrêt</span><strong>Commerce</strong></div>
        </div>
      </div>
    </article>
  `;
}

function userStatusClass(status) {
  if (status === "Suspendu") return "danger";
  return status === "À vérifier" || status === "Hors ligne" ? "warn" : "ok";
}

function selectOptions(values, selected, allLabel) {
  return [
    `<option value="all"${selected === "all" ? " selected" : ""}>${allLabel}</option>`,
    ...values.map((value) => `<option value="${escapeHtml(value)}"${selected === value ? " selected" : ""}>${escapeHtml(value)}</option>`),
  ].join("");
}

function uniqueUserValues(key) {
  return [...new Set(users.map((user) => user[key]).filter(Boolean))].sort((a, b) => a.localeCompare(b, "fr"));
}

function filteredUsers() {
  const query = normalizeSearch(utilisateurState.query);
  return users.filter((user) => {
    const haystack = normalizeSearch([
      user.name,
      user.email,
      user.phone,
      user.profile,
      user.role,
      user.network,
      user.depot,
      user.context,
      user.status,
    ].join(" "));
    return (!query || haystack.includes(query))
      && (utilisateurState.profile === "all" || user.profile === utilisateurState.profile)
      && (utilisateurState.role === "all" || user.role === utilisateurState.role)
      && (utilisateurState.depot === "all" || user.depot === utilisateurState.depot || user.network === utilisateurState.depot)
      && (utilisateurState.status === "all" || user.status === utilisateurState.status);
  });
}

function selectedUser(records = filteredUsers()) {
  const user = records.find((item) => item.id === utilisateurState.selectedId) || records[0] || users.find((item) => item.id === utilisateurState.selectedId) || users[0];
  if (user) utilisateurState.selectedId = user.id;
  return user;
}

function renderUserCard(user) {
  if (!user) {
    return `
      <article class="user-card">
        <div class="panel-body">
          <div class="empty-state">Aucun profil sélectionné.</div>
        </div>
      </article>
    `;
  }

  const meta = [
    ["Email", user.email],
    ["Téléphone", user.phone],
    ["Habilitations", user.permissions],
    ["Appareil", user.device],
  ];

  return `
    <article class="user-card" data-selected-user="${escapeHtml(user.id)}">
      <div class="user-cover"></div>
      <div class="panel-body">
        <img class="large-avatar" src="${escapeHtml(user.img)}" alt="${escapeHtml(user.name)}" />
        <div class="profile-title">
          <div>
            <h2>${escapeHtml(user.name)}</h2>
            <p class="muted">${escapeHtml(user.profile)} · ${escapeHtml(user.network)} · ${escapeHtml(user.context)}</p>
          </div>
          <span class="severity ${userStatusClass(user.status)}">${escapeHtml(user.status)}</span>
        </div>
        <div class="meta-grid">${meta.map(([label, value]) => `<div class="meta-box"><span>${label}</span><strong>${escapeHtml(value)}</strong></div>`).join("")}</div>
        <div class="profile-actions">
          <button class="ghost-button" type="button" data-user-action="toggle-status">${icon(user.status === "À vérifier" ? "badge-check" : "shield-alert")}${user.status === "À vérifier" ? "Valider" : "À vérifier"}</button>
          <button class="ghost-button" type="button" data-user-action="suspend">${icon(user.status === "Suspendu" ? "rotate-ccw" : "ban")}${user.status === "Suspendu" ? "Réactiver" : "Suspendre"}</button>
        </div>
        <div class="history-list">
          <div class="compact-title">Historique récent</div>
          ${user.history.map((item) => `<div class="history-item">${icon("history")}<span>${escapeHtml(item)}</span></div>`).join("")}
        </div>
      </div>
    </article>
  `;
}

function renderUsersTable(records) {
  if (!records.length) {
    return `<div class="panel-body"><div class="empty-state">Aucun utilisateur ne correspond aux filtres. Réinitialise la recherche ou invite un nouveau profil.</div></div>`;
  }

  return `
    <table class="table user-table">
      <thead><tr><th>Utilisateur</th><th>Profil</th><th>Réseau / dépôt</th><th>Contexte</th><th>Statut</th></tr></thead>
      <tbody>${records.map((user) => `
        <tr class="user-row ${user.id === utilisateurState.selectedId ? "selected" : ""}" data-user-id="${escapeHtml(user.id)}" tabindex="0">
          <td><div class="identity"><img class="avatar" src="${escapeHtml(user.img)}" alt="${escapeHtml(user.name)}" /><div><strong>${escapeHtml(user.name)}</strong><span>${escapeHtml(user.email)}</span></div></div></td>
          <td>${escapeHtml(user.profile)}<span class="table-subtext">${escapeHtml(user.role)}</span></td>
          <td>${escapeHtml(user.network)}</td>
          <td>${escapeHtml(user.context)}</td>
          <td><span class="severity ${userStatusClass(user.status)}">${escapeHtml(user.status)}</span></td>
        </tr>
      `).join("")}</tbody>
    </table>
  `;
}

function renderUtilisateurs() {
  const records = filteredUsers();
  const activeUser = selectedUser(records);
  $("#utilisateurs").innerHTML = `
    ${pageHeader("Profils & permissions", "Utilisateurs", "Recherche, filtres puissants, rôles, habilitations, appareils, connexions et historique complet sur tous les profils Aule.", `
      <button class="ghost-button" id="importUsers" type="button">${icon("upload")}Importer</button>
      <button class="primary-button" id="inviteUser" type="button">${icon("user-plus")}Inviter</button>
    `)}
    <div class="filters-grid">
      <input id="userSearch" placeholder="Rechercher un nom, email, téléphone..." value="${escapeHtml(utilisateurState.query)}" />
      <select id="profileFilter">${selectOptions(uniqueUserValues("profile"), utilisateurState.profile, "Tous les profils")}</select>
      <select id="roleFilter">${selectOptions(uniqueUserValues("role"), utilisateurState.role, "Tous les rôles")}</select>
      <select id="depotFilter">${selectOptions(uniqueUserValues("depot"), utilisateurState.depot, "Tous les dépôts")}</select>
      <select id="statusFilter">${selectOptions(uniqueUserValues("status"), utilisateurState.status, "État de connexion")}</select>
    </div>
    <div class="profile-drawer">
      ${renderUserCard(activeUser)}
      <article class="panel">
        <div class="panel-header">
          <div><h2>Annuaire opérationnel</h2><p>Voyageurs, conducteurs, contrôleurs, agents, superviseurs, administrateurs, commerçants, livreurs, VTC et taxis.</p></div>
          <div class="directory-actions">
            <span class="severity ok">${records.length}/${users.length}</span>
            <button class="ghost-button" id="resetUserFilters" type="button">${icon("rotate-ccw")}Réinitialiser</button>
          </div>
        </div>
        ${renderUsersTable(records)}
      </article>
    </div>
  `;
  bindUtilisateurEvents();
}

function rerenderUtilisateurs(focusId = null, cursor = null) {
  renderUtilisateurs();
  refreshIcons();
  if (!focusId) return;
  const element = $(`#${focusId}`);
  if (!element) return;
  element.focus();
  if (Number.isInteger(cursor) && "setSelectionRange" in element) {
    element.setSelectionRange(cursor, cursor);
  }
}

function importDemoUsers() {
  if (utilisateurState.imported) return;
  utilisateurState.imported = true;
  users.push(
    {
      id: "usr-import-sarah-roy",
      name: "Sarah Roy",
      profile: "Livreuse",
      role: "Agent",
      network: "Île de Nantes",
      depot: "Île de Nantes",
      context: "Livraison CMD-7740",
      status: "Connecté",
      email: "sarah.roy@aule.app",
      phone: "+33 6 31 44 89 02",
      permissions: "Livraison, géolocalisation",
      device: "Pixel 8",
      lastSeen: "Import CSV",
      history: ["Import CSV validé", "Pièce identité vérifiée", "Course affectée"],
      img: "https://api.dicebear.com/8.x/initials/svg?seed=Sarah%20Roy",
    },
    {
      id: "usr-import-youssef-amari",
      name: "Youssef Amari",
      profile: "Taxi",
      role: "Agent",
      network: "Station Commerce",
      depot: "Commerce",
      context: "Disponible · licence TX-74",
      status: "Hors ligne",
      email: "youssef.amari@aule.app",
      phone: "+33 6 70 18 63 24",
      permissions: "Courses, paiements",
      device: "Android Auto",
      lastSeen: "Hier 22:14",
      history: ["Import CSV validé", "Licence ajoutée", "Dernière course clôturée"],
      img: "https://api.dicebear.com/8.x/initials/svg?seed=Youssef%20Amari",
    },
    {
      id: "usr-import-ines-garnier",
      name: "Inès Garnier",
      profile: "Administratrice",
      role: "Admin",
      network: "Aule HQ",
      depot: "Aule HQ",
      context: "Audit permissions",
      status: "À vérifier",
      email: "ines.garnier@aule.app",
      phone: "+33 6 82 50 77 16",
      permissions: "Administration, audit",
      device: "Safari · Mac",
      lastSeen: "Import CSV",
      history: ["Import CSV validé", "Revue accès demandée", "MFA en attente"],
      img: "https://api.dicebear.com/8.x/initials/svg?seed=Ines%20Garnier",
    },
  );
  utilisateurState.selectedId = "usr-import-sarah-roy";
}

function inviteDemoUser() {
  utilisateurState.invitedCount += 1;
  const index = utilisateurState.invitedCount;
  const id = `usr-invite-${Date.now()}`;
  const name = `Invité ${String(index).padStart(2, "0")}`;
  users.unshift({
    id,
    name,
    profile: "Voyageur",
    role: "Client",
    network: "Naolib",
    depot: "Naolib",
    context: "Invitation envoyée",
    status: "À vérifier",
    email: `invite.${index}@aule.app`,
    phone: "À renseigner",
    permissions: "Profil minimal",
    device: "En attente",
    lastSeen: "Jamais connecté",
    history: ["Invitation générée", "Email envoyé", "MFA à configurer"],
    img: `https://api.dicebear.com/8.x/initials/svg?seed=${encodeURIComponent(name)}`,
  });
  utilisateurState.selectedId = id;
  utilisateurState.query = "";
}

function bindUtilisateurEvents() {
  const searchInput = $("#userSearch");
  searchInput?.addEventListener("input", (event) => {
    utilisateurState.query = event.target.value;
    rerenderUtilisateurs("userSearch", event.target.selectionStart);
  });

  [
    ["profileFilter", "profile"],
    ["roleFilter", "role"],
    ["depotFilter", "depot"],
    ["statusFilter", "status"],
  ].forEach(([id, key]) => {
    $(`#${id}`)?.addEventListener("change", (event) => {
      utilisateurState[key] = event.target.value;
      rerenderUtilisateurs(id);
    });
  });

  $$(".user-row", $("#utilisateurs")).forEach((row) => {
    const select = () => {
      utilisateurState.selectedId = row.dataset.userId;
      rerenderUtilisateurs();
    };
    row.addEventListener("click", select);
    row.addEventListener("keydown", (event) => {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        select();
      }
    });
  });

  $("#resetUserFilters")?.addEventListener("click", () => {
    Object.assign(utilisateurState, { query: "", profile: "all", role: "all", depot: "all", status: "all" });
    rerenderUtilisateurs("userSearch");
  });

  $("#importUsers")?.addEventListener("click", () => {
    importDemoUsers();
    rerenderUtilisateurs();
  });

  $("#inviteUser")?.addEventListener("click", () => {
    inviteDemoUser();
    rerenderUtilisateurs();
  });

  $$("[data-user-action]", $("#utilisateurs")).forEach((button) => {
    button.addEventListener("click", () => {
      const user = users.find((item) => item.id === utilisateurState.selectedId);
      if (!user) return;
      if (button.dataset.userAction === "toggle-status") {
        user.status = user.status === "À vérifier" ? "Connecté" : "À vérifier";
        user.history = [`Statut changé à ${shortDateTime(new Date().toISOString())}`, ...user.history].slice(0, 4);
      }
      if (button.dataset.userAction === "suspend") {
        user.status = user.status === "Suspendu" ? "Connecté" : "Suspendu";
        user.history = [`${user.status === "Suspendu" ? "Suspension" : "Réactivation"} admin`, ...user.history].slice(0, 4);
      }
      rerenderUtilisateurs();
    });
  });
}

function renderMissions() {
  const columns = [
    ["Backlog", missions.slice(1, 2)],
    ["Planifiées", missions.slice(1, 3)],
    ["En cours", [missions[0], missions[3]]],
    ["Validation", missions.slice(2, 3)],
  ];

  $("#missions").innerHTML = `
    ${pageHeader("Opérations terrain", "Missions", "Un espace de travail type Notion pour suivre équipe, carte, discussion, checklist, documents, photos, consignes, validations et signatures.", `
      <button class="ghost-button">${icon("map")}Depuis la carte</button>
      <button class="primary-button">${icon("plus")}Nouvelle mission</button>
    `)}
    <div class="kanban">
      ${columns.map(([title, items]) => `
        <section class="kanban-column">
          <div class="kanban-title"><strong>${title}</strong><span class="severity ok">${items.length}</span></div>
          ${items.map((m) => `
            <article class="mission-card">
              <strong>${m.title}</strong>
              <span>${m.meta}</span>
              <div class="progress"><span style="width:${m.progress}%"></span></div>
              <div class="inline-actions">
                <span class="severity ok">${m.team}</span>
                <span class="severity warn">${m.status}</span>
              </div>
              <div class="meta-grid">
                <div class="meta-box"><span>Checklist</span><strong>7/9</strong></div>
                <div class="meta-box"><span>Documents</span><strong>3 fichiers</strong></div>
                <div class="meta-box"><span>Photos</span><strong>12</strong></div>
                <div class="meta-box"><span>Signature</span><strong>Attendue</strong></div>
              </div>
            </article>
          `).join("")}
        </section>
      `).join("")}
    </div>
  `;
}

function renderCommunication() {
  $("#communication").innerHTML = `
    ${pageHeader("Information voyageurs", "Communication", "Composer, cibler, prévisualiser, programmer et mesurer notifications, perturbations, alertes, déviations, actualités et campagnes.", `
      <button class="ghost-button">${icon("calendar-clock")}Programmer</button>
      <button class="primary-button">${icon("send")}Envoyer test</button>
    `)}
    <div class="message-layout">
      <div class="stack">
        ${["Notification", "Perturbation", "Alerte", "Déviation", "Actualité", "Message ciblé", "Campagne"].map((label, i) => `<button class="message-card" type="button"><strong>${label}</strong><span>${i === 0 ? "Push mobile, email, SMS" : "Modèle prêt avec ciblage avancé"}</span></button>`).join("")}
      </div>
      <article class="panel">
        <div class="panel-header"><div><h2>Composer</h2><p>Destinataires : tous, profils, ligne, arrêt, zone, réseau ou dépôt.</p></div><span class="severity ok">Brouillon auto</span></div>
        <div class="panel-body stack">
          <input placeholder="Titre du message" value="Perturbation ligne T2" />
          <textarea>En raison d'une intervention technique, la ligne T2 circule avec un retard estimé de 8 minutes entre Commerce et Pirmil. Les correspondances sont maintenues.</textarea>
          <div class="filters-grid" style="margin:0">
            <select><option>Ligne T2</option></select>
            <select><option>Voyageurs + conducteurs</option></select>
            <select><option>Zone Commerce</option></select>
            <select><option>Maintenant</option></select>
            <select><option>Push + SMS</option></select>
          </div>
          <div class="inline-actions"><button class="ghost-button">${icon("eye")}Prévisualiser</button><button class="primary-button">${icon("send")}Envoyer</button></div>
        </div>
      </article>
      <article class="panel">
        <div class="panel-header"><h2>Prévisualisation</h2><span class="severity ok">74% ouverture estimée</span></div>
        <div class="phone-preview"><div class="phone-screen"><div class="push-card"><strong>Aule · Perturbation T2</strong><span>Retard estimé de 8 minutes entre Commerce et Pirmil. Correspondances maintenues.</span></div></div></div>
      </article>
    </div>
  `;
}

function renderMarketplace() {
  $("#marketplace").innerHTML = `
    ${pageHeader("Commerce embarqué", "Marketplace", "Superviser commerçants, produits, catégories, commandes, livreurs, paiements, promotions, avis et statistiques.", `
      <button class="ghost-button">${icon("badge-percent")}Promotion</button>
      <button class="primary-button">${icon("store")}Ajouter commerçant</button>
    `)}
    ${renderKpis([["Commerçants", 214, "+9%"], ["Produits", "8 402", "+411"], ["Commandes", 128, "+11%"], ["Livreurs", 42, "+5%"], ["Paiements", "24 890€", "+18%"], ["Avis moyen", "4.8/5", "+0.2"], ["Promotions", 18, "+4"], ["Temps moyen", "8m 12s", "-42s"]])}
    <div class="market-grid">${merchants.map(([name, kind, orders, rating, img]) => `
      <article class="merchant-card">
        <img src="${img}" alt="${name}" />
        <div class="panel-body">
          <div class="entity-top"><div><h3>${name}</h3><span class="muted">${kind}</span></div><span class="severity ok">Ouvert</span></div>
          <div class="meta-grid"><div class="meta-box"><span>Commandes</span><strong>${orders}</strong></div><div class="meta-box"><span>Avis</span><strong>${rating}</strong></div><div class="meta-box"><span>Revenus</span><strong>3 820€</strong></div><div class="meta-box"><span>Temps moyen</span><strong>8 min</strong></div></div>
        </div>
      </article>
    `).join("")}</div>
    <article class="panel" style="margin-top:18px">
      <div class="panel-header"><h2>Commandes en cours</h2><button class="ghost-button">${icon("download")}CSV</button></div>
      <table class="table"><thead><tr><th>Commande</th><th>Commerce</th><th>Livreur</th><th>Paiement</th><th>État</th></tr></thead><tbody>${["CMD-7732", "CMD-7733", "CMD-7734", "CMD-7735"].map((id, i) => `<tr><td>${id}</td><td>${merchants[i % 3][0]}</td><td>Livreur ${i + 12}</td><td>Validé</td><td><span class="severity ${i === 1 ? "warn" : "ok"}">${i === 1 ? "Préparation" : "En livraison"}</span></td></tr>`).join("")}</tbody></table>
    </article>
  `;
}

function renderAnalytics() {
  const analytics = [["Ponctualité", "96.4%", "+2.1"], ["Retards", "312", "-8%"], ["Incidents", "47", "-12%"], ["Utilisateurs actifs", "58 204", "+10%"], ["Croissance", "18.2%", "+4.1"], ["Trajets", "221k", "+6%"], ["Commandes", "8 912", "+13%"], ["Temps d'attente", "3m 24s", "-21s"]];
  $("#analytics").innerHTML = `
    ${pageHeader("Décision", "Analytics", "Graphiques, heatmaps, cartes, comparaisons et exports CSV, Excel ou PDF pour piloter performance réseau et usages.", `
      <button class="ghost-button">${icon("file-spreadsheet")}Excel</button>
      <button class="ghost-button">${icon("file-text")}PDF</button>
      <button class="primary-button">${icon("download")}Exporter CSV</button>
    `)}
    ${renderKpis(analytics)}
    <div class="analytics-grid">
      <article class="panel">
        <div class="panel-header"><div><h2>Ponctualité par heure</h2><p>Comparaison réseau, lignes et dépôts</p></div><span class="severity ok">+2.1 pts</span></div>
        <div class="panel-body"><div class="chart">${[48, 62, 74, 58, 86, 92, 81, 68, 77, 90, 84, 72].map((h, i) => `<div class="bar" data-label="${i + 7}h" style="height:${h}%"></div>`).join("")}</div></div>
      </article>
      <article class="panel">
        <div class="panel-header"><div><h2>Heatmap fréquentation</h2><p>Arrêts, commerces et zones d'influence</p></div></div>
        <div class="panel-body"><div class="heatmap">${Array.from({ length: 96 }, (_, i) => `<div class="heat-cell" style="--heat:${0.12 + ((i * 17) % 80) / 100}"></div>`).join("")}</div></div>
      </article>
    </div>
    <div class="grid-three" style="margin-top:18px">
      ${["Top lignes", "Top arrêts", "Top commerçants"].map((title) => `<article class="panel"><div class="panel-header"><h2>${title}</h2></div><div class="panel-body stack">${["C1 · Commerce", "T1 · Gare Nord", "C6 · Pirmil"].map((row, i) => `<div class="dense-item"><strong>${row}</strong><span>${98 - i * 7}% performance</span></div>`).join("")}</div></article>`).join("")}
    </div>
  `;
}

function renderAdministration() {
  const sections = [
    ["Permissions", "Rôles, profils, habilitations", "shield"],
    ["Rôles", "Matrices d'accès par réseau", "key-round"],
    ["Logs", "Audit, connexions, appareils", "scroll-text"],
    ["API", "Clients, quotas, versions", "braces"],
    ["Clés", "Rotation et secrets", "key"],
    ["Webhooks", "Livraisons, retries, erreurs", "workflow"],
    ["Emails", "Templates et réputation", "mail"],
    ["SMS", "Providers et coûts", "message-square"],
    ["Push", "Certificats et campagnes", "bell"],
    ["Stockage", "Fichiers, médias, rétention", "database"],
    ["IA", "Modération, suggestions, copilote", "sparkles"],
    ["Monitoring", "SLO, alerting, traces", "activity"],
    ["Sauvegardes", "RPO, restaurations", "archive-restore"],
    ["Maintenance", "Fenêtres et bannière statut", "wrench"],
    ["Variables", "Environnements et valeurs", "terminal"],
  ];

  $("#administration").innerHTML = `
    ${pageHeader("Configuration plateforme", "Administration", "Une console complète pour sécuriser, monitorer, connecter et maintenir l'ensemble des réseaux Aule.", `
      <button class="ghost-button">${icon("file-clock")}Logs</button>
      <button class="primary-button">${icon("plus")}Nouvelle clé API</button>
    `)}
    <div class="admin-grid">${sections.map(([title, desc, iconName], index) => `
      <article class="admin-row">
        ${icon(iconName)}
        <div><strong>${title}</strong><span class="muted" style="display:block;margin-top:5px">${desc}</span></div>
        <span class="severity ${index % 5 === 0 ? "warn" : "ok"}">${index % 5 === 0 ? "À revoir" : "OK"}</span>
      </article>
    `).join("")}</div>
    <div class="grid-main" style="margin-top:18px">
      <article class="panel"><div class="panel-header"><h2>Flux de logs</h2><span class="severity ok">Live</span></div><div class="panel-body stack">${events.map(([a,b,t,s]) => `<div class="event-item"><div class="event-icon">${icon("terminal")}</div><div><strong>${a}</strong><span>${b}</span></div><span class="event-time">${t}</span></div>`).join("")}</div></article>
      <article class="panel"><div class="panel-header"><h2>États d'erreur</h2></div><div class="panel-body"><div class="error-state"><div><strong>Incident provider SMS simulé</strong><p class="muted" style="margin-top:8px">Retry automatique, bascule provider secondaire et notification admin prêtes.</p></div></div></div></article>
    </div>
  `;
}

function initSearch() {
  const palette = $("#commandPalette");
  const input = $("#paletteInput");
  const results = $("#paletteResults");

  function renderResults(query = "") {
    const normalized = normalizeSearch(query.trim());
    const filtered = searchIndex.filter((item) => normalizeSearch(item.join(" ")).includes(normalized));
    results.innerHTML = filtered.map(([type, title, desc, iconName]) => `
      <button class="palette-item" type="button">
        ${icon(iconName)}
        <div><strong>${title}</strong><span>${type} · ${desc}</span></div>
        <span class="severity ok">Ouvrir</span>
      </button>
    `).join("") || `<div class="empty-state">Aucun résultat. Créer une alerte, mission ou notification depuis la recherche.</div>`;
    refreshIcons();
  }

  function open() {
    palette.classList.add("open");
    palette.setAttribute("aria-hidden", "false");
    input.value = "";
    renderResults();
    setTimeout(() => input.focus(), 30);
  }

  function close() {
    palette.classList.remove("open");
    palette.setAttribute("aria-hidden", "true");
  }

  $("#searchTrigger").addEventListener("click", open);
  $("#searchTrigger").addEventListener("keydown", (event) => {
    if (event.key === "Enter" || event.key === " ") open();
  });
  $("#closePalette").addEventListener("click", close);
  input.addEventListener("input", () => renderResults(input.value));
  document.addEventListener("keydown", (event) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      open();
    }
    if (event.key === "Escape") close();
  });
}

function initClock() {
  const clock = $("#clock");
  const update = () => {
    clock.textContent = new Intl.DateTimeFormat("fr-FR", {
      hour: "2-digit",
      minute: "2-digit",
      timeZone: "Europe/Paris",
    }).format(new Date());
  };
  update();
  setInterval(update, 10000);
}

function refreshIcons() {
  if (window.lucide) {
    window.lucide.createIcons({ attrs: { "stroke-width": 1.8 } });
  }
}

function renderAll() {
  renderDashboard();
  renderSupervision();
  renderExploitation();
  renderUtilisateurs();
  renderMissions();
  renderCommunication();
  renderMarketplace();
  renderAnalytics();
  renderAdministration();
  refreshIcons();
}

async function refreshRealData({ silent = false } = {}) {
  if (!window.AuleData) {
    liveDataMeta = {
      label: "Simulation",
      detail: "data.js absent",
      loadedAt: null,
      status: "warn",
    };
    updateDataSourcePill();
    return null;
  }

  if (!silent) {
    const pill = $("#dataSourcePill");
    if (pill) {
      pill.classList.add("warn");
      pill.innerHTML = `${icon("loader-circle")}<span>Chargement données...</span>`;
      refreshIcons();
    }
  }

  try {
    const data = await window.AuleData.load();
    applyRealData(data);
    const activePage = $(".page.active")?.id || "dashboard";
    renderAll();
    setActivePage(activePage);
    return data;
  } catch (error) {
    liveDataMeta = {
      label: "Erreur données",
      detail: error.message,
      loadedAt: new Date().toISOString(),
      status: "warn",
    };
    updateDataSourcePill();
    return null;
  }
}

async function init() {
  initNav();
  renderAll();
  initSearch();
  initClock();
  $("#mobileMenu").addEventListener("click", () => $(".sidebar").classList.toggle("open"));
  refreshIcons();
  await refreshRealData();
  setInterval(() => refreshRealData({ silent: true }), liveRefreshMs);
}

document.addEventListener("DOMContentLoaded", init);
