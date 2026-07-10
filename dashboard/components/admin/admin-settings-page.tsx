import {
  Archive,
  Bell,
  Bot,
  CreditCard,
  Database,
  HardDrive,
  KeyRound,
  LockKeyhole,
  Mail,
  Network,
  Server,
  Shield,
  ShoppingBag,
  Truck,
} from "lucide-react";

const adminConfigModules = [
  "Plateforme",
  "Réseaux",
  "API",
  "Permissions",
  "Emails",
  "Notifications",
  "Stockage",
  "Paiements",
  "Marketplace",
  "Transport",
  "IA",
  "Sécurité",
  "Logs",
  "Sauvegardes",
] as const;

const icons = [
  Server,
  Network,
  KeyRound,
  Shield,
  Mail,
  Bell,
  HardDrive,
  CreditCard,
  ShoppingBag,
  Truck,
  Bot,
  LockKeyhole,
  Database,
  Archive,
] as const;

export function AdminSettingsPageContent() {
  return (
    <main className="admin-app-content">
      <div>
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-blue-200">
          Paramètres
        </p>
        <h2 className="mt-2 text-3xl font-bold tracking-tight text-white">
          Centre de configuration
        </h2>
        <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-400">
          Configurez les briques critiques de la plateforme Aule: API, réseaux,
          permissions, emails, notifications, stockage, marketplace, IA, sécurité et sauvegardes.
        </p>
      </div>

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {adminConfigModules.map((module, index) => {
          const Icon = icons[index] ?? Server;
          return (
            <article key={module} className="admin-config-card">
              <Icon className="h-5 w-5 text-blue-200" />
              <h3>{module}</h3>
              <p>
                Paramètres, règles, statuts et intégrations liés au module {module.toLowerCase()}.
              </p>
              <button className="admin-secondary-btn h-9 px-3" type="button">
                Configurer
              </button>
            </article>
          );
        })}
      </section>
    </main>
  );
}
