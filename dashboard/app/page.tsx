import type { Metadata } from "next";
import { LandingPage } from "@/components/landing/landing-page";

const title = "Aule — SAEIV pour voyageurs et professionnels";
const description =
  "Aule est un SAEIV qui centralise l'information voyageurs en temps réel et fournit aux professionnels et partenaires les outils pour piloter le réseau.";

export const metadata: Metadata = {
  title: { absolute: title },
  description,
  alternates: {
    canonical: "/",
  },
  keywords: [
    "SAEIV",
    "système d'aide à l'exploitation et à l'information voyageurs",
    "information voyageurs",
    "aide à l'exploitation",
    "transport public",
    "temps réel",
    "supervision réseau",
    "Aule Pro",
    "professionnels du transport",
    "partenaires de mobilité",
  ],
  openGraph: {
    type: "website",
    locale: "fr_FR",
    siteName: "Aule",
    url: "/",
    title,
    description,
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
    title,
    description,
    images: ["/uploads/logo-1783189856190.png"],
  },
};

const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "Organization",
      "@id": "https://www.aule.fr/#organization",
      name: "Aule",
      url: "https://www.aule.fr/",
      logo: "https://www.aule.fr/uploads/logo-1783189856190.png",
    },
    {
      "@type": "SoftwareApplication",
      "@id": "https://www.aule.fr/#application",
      name: "Aule",
      url: "https://www.aule.fr/",
      description,
      applicationCategory: "TravelApplication",
      operatingSystem: "Web",
      publisher: {
        "@id": "https://www.aule.fr/#organization",
      },
      audience: [
        {
          "@type": "Audience",
          audienceType: "Voyageurs",
        },
        {
          "@type": "Audience",
          audienceType: "Professionnels du transport",
        },
        {
          "@type": "Audience",
          audienceType: "Partenaires de mobilité",
        },
      ],
    },
  ],
};

export default function HomePage() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify(structuredData).replace(/</g, "\\u003c"),
        }}
      />
      <LandingPage />
    </>
  );
}
