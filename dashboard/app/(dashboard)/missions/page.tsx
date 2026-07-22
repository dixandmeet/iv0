import { MissionsPageContent } from "@/components/missions/missions-page-content";
import { demoDataEnabled } from "@/lib/demo-mode";

export default function MissionsPage() {
  if (!demoDataEnabled) {
    return (
      <main className="dashboard-main-column msr-page">
        <header className="msr-header">
          <div>
            <h1 className="msr-title">Missions MSR</h1>
            <p className="msr-subtitle">
              Ce module est désactivé tant que sa source de données opérationnelle
              n’est pas raccordée. Aucune donnée fictive n’est affichée en production.
            </p>
          </div>
        </header>
      </main>
    );
  }
  return <MissionsPageContent />;
}
