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
  metadataBase: new URL("https://www.aule.fr"),
  title: {
    default: "Aule — SAEIV pour voyageurs et professionnels",
    template: "%s | Aule",
  },
  description:
    "Aule est un SAEIV qui centralise l'information voyageurs en temps réel et fournit aux professionnels et partenaires les outils pour piloter le réseau.",
  keywords: [
    "SAEIV",
    "système d'aide à l'exploitation et à l'information voyageurs",
    "information voyageurs",
    "aide à l'exploitation",
    "supervision réseau",
    "Aule Pro",
    "partenaires de mobilité",
    "transport en commun",
    "transport public",
    "bus",
    "tramway",
    "métro",
    "temps réel",
    "itinéraire",
    "Nantes",
    "Naolib",
  ],
  authors: [{ name: "Aule" }],
  creator: "Aule",
  publisher: "Aule",
  openGraph: {
    type: "website",
    locale: "fr_FR",
    siteName: "Aule",
    url: "/",
    title: "Aule — SAEIV pour voyageurs et professionnels",
    description:
      "Information voyageurs en temps réel et outils d'exploitation pour les professionnels du transport et leurs partenaires.",
    images: [
      {
        url: "/uploads/logo-1783189856190.png",
        width: 1024,
        height: 1024,
        alt: "Logo Aule",
      },
    ],
  },
  twitter: {
    card: "summary",
    title: "Aule — SAEIV pour voyageurs et professionnels",
    description:
      "Information voyageurs en temps réel et outils d'exploitation pour les professionnels et partenaires.",
    images: ["/uploads/logo-1783189856190.png"],
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
