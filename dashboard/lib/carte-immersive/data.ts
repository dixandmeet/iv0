import type { LatLng } from "./geo";

export const CITY_CENTER: LatLng = [47.2184, -1.5536]; // Nantes

export type VehicleType = "bus" | "tram" | "vtc" | "taxi";

export const ROUTE_DELTAS: Record<string, LatLng[]> = {
  bus1: [
    [-0.0024, -0.0069],
    [-0.0012, -0.0024],
    [0.0001, 0.0016],
    [0.0021, 0.0046],
    [0.0041, 0.0066],
  ],
  bus2: [
    [0.0046, -0.0074],
    [0.0021, -0.0034],
    [-0.0004, -0.0014],
    [-0.0034, 0.0006],
    [-0.0064, 0.0026],
  ],
  bus3: [
    [-0.0044, 0.0076],
    [-0.0024, 0.0046],
    [0.0001, 0.0016],
    [0.0026, -0.0019],
    [0.0046, -0.0054],
  ],
  tram1: [
    [-0.0034, -0.0114],
    [-0.0014, -0.0054],
    [0, 0],
    [0.0016, 0.0056],
    [0.0036, 0.0116],
  ],
  tram2: [
    [0.0076, -0.0024],
    [0.0036, -0.0009],
    [0, 0],
    [-0.0044, 0.0011],
    [-0.0084, 0.0026],
  ],
  vtc1: [
    [-0.0006, -0.0009],
    [0.0004, 0.0006],
    [0.0011, -0.0009],
    [0.0001, -0.0019],
  ],
  vtc2: [
    [-0.0014, 0.0016],
    [-0.0006, 0.0031],
    [0.0004, 0.0021],
    [-0.0004, 0.0008],
  ],
  taxi1: [
    [0.0011, -0.0034],
    [0.0021, -0.0019],
    [0.0031, -0.0032],
    [0.0021, -0.0044],
  ],
};

export const SHOP_DELTAS: Record<string, LatLng> = {
  s1: [-0.0006, -0.0024],
  s2: [0.0008, 0.0011],
  s3: [-0.0016, -0.0004],
  s4: [0.0021, 0.0026],
  s5: [-0.0024, 0.0021],
  s6: [0.0016, -0.0019],
  s7: [0.0012, -0.0008],
  s8: [-0.001, 0.0035],
  s9: [0.0004, -0.0032],
};

export type Category = { key: string; emoji: string; label: string };

export const CATEGORIES: Category[] = [
  { key: "resto", emoji: "🍔", label: "Restaurants" },
  { key: "cafe", emoji: "☕", label: "Cafés" },
  { key: "boulangerie", emoji: "🥖", label: "Boulangeries" },
  { key: "supermarche", emoji: "🛒", label: "Supermarchés" },
  { key: "pharmacie", emoji: "💊", label: "Pharmacies" },
  { key: "boutique", emoji: "🛍️", label: "Boutiques" },
  { key: "fastfood", emoji: "🍕", label: "Fast-food" },
  { key: "emporter", emoji: "🥡", label: "À emporter" },
  { key: "asiatique", emoji: "🍣", label: "Cuisine asiatique" },
  { key: "patisserie", emoji: "🍰", label: "Pâtisseries" },
  { key: "boucherie", emoji: "🥩", label: "Boucheries" },
  { key: "fleuriste", emoji: "💐", label: "Fleuristes" },
  { key: "epicerie", emoji: "🏪", label: "Épiceries" },
];

export const DEST_DELTA: LatLng = [-0.0011, 0.0112];

export type Place = {
  name: string;
  meta: string;
  icon: string;
  dist: string;
  delta: LatLng;
};

export const PLACES: Place[] = [
  { name: "Gare centrale", meta: "Pôle multimodal", icon: "🚉", dist: "1,4 km", delta: [-0.0011, 0.0112] },
  { name: "Place du Commerce", meta: "Centre-ville", icon: "🏛", dist: "350 m", delta: [-0.0008, 0.0002] },
  { name: "Château des ducs", meta: "Monument", icon: "🏰", dist: "700 m", delta: [0.0006, 0.006] },
  { name: "Jardin des Plantes", meta: "Parc", icon: "🌳", dist: "1,6 km", delta: [0.001, 0.014] },
  { name: "Île de Nantes", meta: "Quartier", icon: "🏙", dist: "1,1 km", delta: [-0.006, 0.002] },
  { name: "Place Graslin", meta: "Théâtre & commerces", icon: "🎭", dist: "600 m", delta: [-0.0004, -0.006] },
  { name: "Les Machines de l'île", meta: "Attraction", icon: "🐘", dist: "1,3 km", delta: [-0.005, -0.002] },
  { name: "Beaulieu", meta: "Centre commercial", icon: "🛍", dist: "1,9 km", delta: [-0.008, 0.009] },
];

export type VehicleDef = {
  id: string;
  type: VehicleType;
  path: string;
  speed: number;
  phase: number;
  line?: string;
  dest?: string;
  nextStop?: string;
  eta: string;
  status?: string;
  occ?: string;
  driver?: string;
  rating?: string;
  price?: string;
  dist?: string;
  station?: string;
};

export const VEHICLE_DEFS: VehicleDef[] = [
  { id: "b1", type: "bus", path: "bus1", speed: 0.05, phase: 0, line: "Bus 12", dest: "Beaulieu", nextStop: "Hôtel de Ville", eta: "3 min", status: "À l'heure", occ: "Modérée" },
  { id: "b2", type: "bus", path: "bus2", speed: 0.045, phase: 0.011, line: "Bus 4", dest: "Ranzay", nextStop: "Place Viarme", eta: "6 min", status: "Retard 2 min", occ: "Faible" },
  { id: "b3", type: "bus", path: "bus3", speed: 0.048, phase: 0.023, line: "Bus 30", dest: "Bellevue", nextStop: "Cours des 50 Otages", eta: "9 min", status: "À l'heure", occ: "Élevée" },
  { id: "t1", type: "tram", path: "tram1", speed: 0.06, phase: 0.006, line: "Tram 3", dest: "Gare de Nantes", nextStop: "Hôtel de Ville", eta: "2 min", status: "À l'heure" },
  { id: "t2", type: "tram", path: "tram2", speed: 0.058, phase: 0.017, line: "Tram 1", dest: "Vertou", nextStop: "Commerce", eta: "5 min", status: "À l'heure" },
  { id: "v1", type: "vtc", path: "vtc1", speed: 0.03, phase: 0.003, driver: "Yanis", rating: "4.9", price: "8–11 €", eta: "3 min", dist: "0,8 km" },
  { id: "v2", type: "vtc", path: "vtc2", speed: 0.026, phase: 0.008, driver: "Sofia", rating: "4.8", price: "9–12 €", eta: "5 min", dist: "1,2 km" },
  { id: "x1", type: "taxi", path: "taxi1", speed: 0.024, phase: 0.005, station: "Station Commerce", dist: "0,5 km", eta: "4 min" },
];

export type ShopDef = {
  id: string;
  emoji: string;
  catKey: string;
  cat: string;
  name: string;
  dist: string;
  distM: number;
  walk: string;
  hours: string;
  rating: string;
  price: string;
  popularity: number;
  delivery: string;
  open: boolean;
};

export const SHOP_DEFS: ShopDef[] = [
  { id: "s1", emoji: "🍔", catKey: "resto", cat: "Restaurant", name: "Le Petit Nantais", dist: "220 m", distM: 220, walk: "3 min", hours: "12h–14h30 · 19h–22h30", rating: "4.6", price: "€€", popularity: 420, delivery: "18-25 min", open: true },
  { id: "s2", emoji: "☕", catKey: "cafe", cat: "Café", name: "Café Louna", dist: "140 m", distM: 140, walk: "2 min", hours: "7h–19h", rating: "4.7", price: "€", popularity: 610, delivery: "10-15 min", open: true },
  { id: "s3", emoji: "🥖", catKey: "boulangerie", cat: "Boulangerie", name: "Boulangerie Ferré", dist: "180 m", distM: 180, walk: "2 min", hours: "6h30–20h", rating: "4.8", price: "€", popularity: 540, delivery: "12-18 min", open: true },
  { id: "s4", emoji: "🛒", catKey: "supermarche", cat: "Supermarché", name: "Marché Frais", dist: "410 m", distM: 410, walk: "5 min", hours: "8h30–20h30", rating: "4.3", price: "€€", popularity: 260, delivery: "25-35 min", open: true },
  { id: "s5", emoji: "💊", catKey: "pharmacie", cat: "Pharmacie", name: "Pharmacie du Centre", dist: "260 m", distM: 260, walk: "3 min", hours: "8h30–19h30", rating: "4.5", price: "€", popularity: 180, delivery: "15-20 min", open: false },
  { id: "s6", emoji: "🛍️", catKey: "boutique", cat: "Boutique", name: "Maison Kali", dist: "300 m", distM: 300, walk: "4 min", hours: "10h–19h", rating: "4.4", price: "€€€", popularity: 150, delivery: "—", open: false },
  { id: "s7", emoji: "🍕", catKey: "fastfood", cat: "Fast-food", name: "Pizza Bella", dist: "350 m", distM: 350, walk: "4 min", hours: "11h30–23h", rating: "4.2", price: "€", popularity: 380, delivery: "15-22 min", open: true },
  { id: "s8", emoji: "🍣", catKey: "asiatique", cat: "Cuisine asiatique", name: "Sushi Machi", dist: "480 m", distM: 480, walk: "6 min", hours: "11h45–14h30 · 18h30–22h", rating: "4.6", price: "€€", popularity: 310, delivery: "20-28 min", open: true },
  { id: "s9", emoji: "🍰", catKey: "patisserie", cat: "Pâtisserie", name: "Douceurs de Nantes", dist: "300 m", distM: 300, walk: "4 min", hours: "8h–19h30", rating: "4.9", price: "€€", popularity: 470, delivery: "15-20 min", open: true },
];

export type MenuItemDef = { n: string; d: string; p: number };
export type MenuSectionDef = { name: string; items: MenuItemDef[] };

export const MENUS: Record<string, MenuSectionDef[]> = {
  resto: [
    { name: "Entrées", items: [
      { n: "Velouté du moment", d: "Légumes de saison, crème fraîche", p: 6.5 },
      { n: "Salade nantaise", d: "Mâche, pommes, noix, comté", p: 9.0 },
      { n: "Rillettes maison & pain grillé", d: "Recette traditionnelle", p: 7.5 },
    ] },
    { name: "Plats", items: [
      { n: "Filet de bar, beurre blanc", d: "Légumes glacés, sauce nantaise", p: 18.5 },
      { n: "Burger fermier & frites", d: "Bœuf local, cheddar affiné", p: 15.0 },
      { n: "Risotto crémeux aux légumes", d: "Parmesan, huile de basilic", p: 14.0 },
    ] },
    { name: "Desserts", items: [
      { n: "Gâteau nantais", d: "Amande & rhum", p: 6.5 },
      { n: "Fondant au chocolat", d: "Cœur coulant, glace vanille", p: 6.0 },
    ] },
    { name: "Boissons", items: [
      { n: "Muscadet (verre)", d: "Domaine local", p: 4.5 },
      { n: "Eau minérale 50cl", d: "", p: 2.5 },
      { n: "Café", d: "Torréfaction artisanale", p: 2.0 },
    ] },
  ],
  cafe: [
    { name: "Boissons chaudes", items: [
      { n: "Espresso", d: "Simple ou allongé", p: 2.0 },
      { n: "Cappuccino", d: "Mousse de lait onctueuse", p: 3.2 },
      { n: "Chai latte", d: "Épices, lait mousseux", p: 3.8 },
      { n: "Chocolat chaud", d: "Chocolat noir fondu", p: 3.5 },
    ] },
    { name: "Boissons froides", items: [
      { n: "Cold brew", d: "Infusion à froid 18h", p: 4.0 },
      { n: "Limonade maison", d: "Citron & menthe fraîche", p: 3.5 },
      { n: "Smoothie fruits rouges", d: "Sans sucre ajouté", p: 4.8 },
    ] },
    { name: "Encas", items: [
      { n: "Cookie", d: "Pépites de chocolat", p: 2.5 },
      { n: "Muffin myrtille", d: "", p: 3.0 },
      { n: "Bagel saumon", d: "Cream cheese, aneth", p: 6.5 },
    ] },
  ],
  boulangerie: [
    { name: "Pains", items: [
      { n: "Baguette tradition", d: "Levain naturel", p: 1.3 },
      { n: "Pain complet", d: "Farine bio T110", p: 2.5 },
      { n: "Pain aux céréales", d: "5 graines", p: 2.8 },
    ] },
    { name: "Viennoiseries", items: [
      { n: "Croissant pur beurre", d: "", p: 1.2 },
      { n: "Pain au chocolat", d: "", p: 1.4 },
      { n: "Chausson aux pommes", d: "", p: 2.2 },
    ] },
    { name: "Sandwichs", items: [
      { n: "Jambon-beurre", d: "Baguette tradition", p: 4.5 },
      { n: "Poulet crudités", d: "Sauce fromage blanc", p: 5.5 },
    ] },
  ],
  supermarche: [
    { name: "Produits frais", items: [
      { n: "Lait bio 1L", d: "Demi-écrémé", p: 1.6 },
      { n: "Œufs plein air x6", d: "Calibre moyen", p: 2.9 },
      { n: "Yaourt nature x4", d: "", p: 2.2 },
    ] },
    { name: "Épicerie", items: [
      { n: "Pâtes 500g", d: "Blé complet", p: 1.2 },
      { n: "Riz basmati 1kg", d: "", p: 2.4 },
      { n: "Café moulu 250g", d: "Arabica", p: 3.9 },
    ] },
    { name: "Boissons", items: [
      { n: "Eau pétillante 6x1L", d: "", p: 3.5 },
      { n: "Jus d'orange 1L", d: "100% pressé", p: 2.3 },
    ] },
  ],
  pharmacie: [
    { name: "Santé", items: [
      { n: "Paracétamol 500mg", d: "Boîte de 16", p: 2.2 },
      { n: "Pansements assortis", d: "", p: 3.5 },
      { n: "Sérum physiologique x10", d: "", p: 2.9 },
    ] },
    { name: "Soins", items: [
      { n: "Gel hydroalcoolique 100ml", d: "", p: 3.2 },
      { n: "Crème hydratante", d: "Peaux sensibles", p: 6.9 },
    ] },
    { name: "Hygiène", items: [
      { n: "Brosse à dents souple", d: "", p: 2.5 },
      { n: "Dentifrice", d: "Protection complète", p: 3.4 },
    ] },
  ],
  boutique: [
    { name: "Accessoires", items: [
      { n: "Écharpe en laine", d: "Doux & chaud", p: 24.0 },
      { n: "Bonnet", d: "Maille côtelée", p: 18.0 },
      { n: "Gants en cuir", d: "Doublure polaire", p: 32.0 },
    ] },
    { name: "Sacs", items: [
      { n: "Tote bag toile", d: "Coton bio", p: 15.0 },
      { n: "Pochette", d: "Cuir végétal", p: 22.0 },
    ] },
  ],
  fastfood: [
    { name: "Pizzas", items: [
      { n: "Margherita", d: "Tomate, mozzarella, basilic", p: 9.0 },
      { n: "Reine", d: "Jambon, champignons", p: 11.0 },
      { n: "4 Fromages", d: "Mozza, chèvre, bleu, comté", p: 12.5 },
    ] },
    { name: "À côté", items: [
      { n: "Frites maison", d: "", p: 3.5 },
      { n: "Tiramisu", d: "Fait maison", p: 4.0 },
    ] },
    { name: "Boissons", items: [
      { n: "Soda 33cl", d: "", p: 2.5 },
      { n: "Bière 25cl", d: "Blonde artisanale", p: 3.5 },
    ] },
  ],
  asiatique: [
    { name: "Makis & sushis", items: [
      { n: "California x6", d: "Surimi, avocat", p: 6.5 },
      { n: "Saumon avocat x6", d: "", p: 7.0 },
      { n: "Assortiment 12 pièces", d: "Sélection du chef", p: 13.5 },
    ] },
    { name: "Plats chauds", items: [
      { n: "Ramen au porc", d: "Bouillon 12h, œuf mollet", p: 12.0 },
      { n: "Pad thaï aux crevettes", d: "Cacahuètes, citron vert", p: 13.0 },
    ] },
    { name: "Boissons", items: [
      { n: "Thé vert", d: "", p: 2.5 },
      { n: "Ramune", d: "Soda japonais", p: 3.2 },
    ] },
  ],
  patisserie: [
    { name: "Gâteaux", items: [
      { n: "Éclair chocolat", d: "", p: 3.8 },
      { n: "Tarte au citron meringuée", d: "", p: 4.2 },
      { n: "Paris-Brest", d: "Praliné maison", p: 4.5 },
    ] },
    { name: "Petits plaisirs", items: [
      { n: "Macaron (à la pièce)", d: "Parfums variés", p: 1.8 },
      { n: "Financier", d: "Amande", p: 2.0 },
    ] },
    { name: "Boissons", items: [
      { n: "Café gourmand", d: "3 mignardises", p: 5.5 },
      { n: "Thé", d: "", p: 3.0 },
    ] },
  ],
  _default: [
    { name: "Sélection", items: [
      { n: "Article populaire", d: "", p: 5.0 },
      { n: "Incontournable", d: "", p: 8.0 },
      { n: "Coup de cœur", d: "", p: 12.0 },
    ] },
  ],
};

export function fmt(n: number): string {
  return n.toFixed(2).replace(".", ",") + " €";
}

export type BuiltMenuItem = { id: string; name: string; desc: string; price: number };
export type BuiltMenuSection = { name: string; items: BuiltMenuItem[] };

export function buildMenu(shop: ShopDef): BuiltMenuSection[] {
  const tmpl = MENUS[shop.catKey] || MENUS._default;
  return tmpl.map((sec, sectionIndex) => ({
    name: sec.name,
    items: sec.items.map((it, i) => ({
      id: `${shop.id}_${sectionIndex}_${i}`,
      name: it.n,
      desc: it.d,
      price: it.p,
    })),
  }));
}
