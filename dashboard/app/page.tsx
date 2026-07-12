import { redirect } from "next/navigation";
import type { Metadata } from "next";
import { LandingPage } from "@/components/landing/landing-page";
import { createClient } from "@/lib/supabase/server";
import { WEB_STAFF_ROLES, type StaffRole } from "@/lib/types";

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
      "@id": "https://aule.fr/#organization",
      name: "Aule",
      url: "https://aule.fr/",
      logo: "https://aule.fr/uploads/logo-1783189856190.png",
    },
    {
      "@type": "SoftwareApplication",
      "@id": "https://aule.fr/#application",
      name: "Aule",
      url: "https://aule.fr/",
      description,
      applicationCategory: "TravelApplication",
      operatingSystem: "Web, iOS, Android",
      publisher: {
        "@id": "https://aule.fr/#organization",
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

export default async function HomePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (user) {
    const { data: profile } = await supabase
      .from("user_profiles")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();

    const role = (profile?.role as StaffRole | undefined) ?? "passenger";
    if (WEB_STAFF_ROLES.includes(role)) {
      redirect("/dashboard");
    }
  }

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
