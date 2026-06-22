import Link from "next/link";
import { footerLinks } from "./landing-data";

export function LandingFooter() {
  return (
    <footer
      className="border-t border-border bg-muted/20"
      role="contentinfo"
    >
      <div className="section-container py-12">
        <div className="grid gap-8 sm:grid-cols-2 lg:grid-cols-4">
          <div className="lg:col-span-1">
            <Link href="/" className="flex items-center gap-2">
              <span className="flex h-8 w-8 items-center justify-center rounded-lg bg-primary text-xs font-extrabold text-primary-foreground">
                A
              </span>
              <span className="text-lg font-bold">Aule</span>
            </Link>
            <p className="mt-3 text-sm text-muted-foreground">
              Le GPS intelligent pour vos trajets en transport en commun.
            </p>
          </div>

          <nav aria-label="Liens produit">
            <h3 className="mb-3 text-sm font-semibold">Produit</h3>
            <ul className="space-y-2">
              {footerLinks.product.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>

          <nav aria-label="Liens support">
            <h3 className="mb-3 text-sm font-semibold">Support</h3>
            <ul className="space-y-2">
              {footerLinks.support.map((link) => (
                <li key={link.href}>
                  <Link
                    href={link.href}
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </nav>

          <nav aria-label="Réseaux sociaux">
            <h3 className="mb-3 text-sm font-semibold">Suivez-nous</h3>
            <ul className="space-y-2">
              {footerLinks.social.map((link) => (
                <li key={link.href}>
                  <a
                    href={link.href}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        </div>

        <div className="mt-10 flex flex-col items-center justify-between gap-4 border-t border-border pt-8 sm:flex-row">
          <p className="text-xs text-muted-foreground">
            © {new Date().getFullYear()} Aule. Tous droits
            réservés.
          </p>
          <p className="text-xs text-muted-foreground">
            Naolib · Réseau pilote Nantes
          </p>
        </div>
      </div>
    </footer>
  );
}
