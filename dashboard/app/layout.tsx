import "./globals.css";
import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import { ThemeProvider } from "@/components/theme-provider";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-sans",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "Aule — GPS intelligent pour les transports en commun",
    template: "%s | Aule",
  },
  description:
    "Trouvez le meilleur itinéraire, suivez votre bus ou tram en temps réel et recevez des alertes avant son arrivée. Application mobile gratuite pour les voyageurs.",
  keywords: [
    "transport en commun",
    "bus",
    "tramway",
    "métro",
    "temps réel",
    "itinéraire",
    "Nantes",
    "Naolib",
    "GPS",
    "application mobile",
  ],
  authors: [{ name: "Aule" }],
  openGraph: {
    type: "website",
    locale: "fr_FR",
    siteName: "Aule",
    title: "Aule — GPS intelligent pour les transports en commun",
    description:
      "Trouvez le meilleur itinéraire, suivez votre bus ou tram en temps réel et recevez des alertes avant son arrivée.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Aule — GPS intelligent pour les transports en commun",
    description:
      "Trouvez le meilleur itinéraire, suivez votre bus ou tram en temps réel.",
  },
  robots: {
    index: true,
    follow: true,
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#E8F1FF" },
    { media: "(prefers-color-scheme: dark)", color: "#0B3D91" },
  ],
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="fr" suppressHydrationWarning className={inter.variable}>
      <body className="min-h-screen font-sans antialiased">
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
