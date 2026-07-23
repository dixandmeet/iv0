import type { MetadataRoute } from "next";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/admin/", "/dashboard/", "/api/", "/configuration/"],
    },
    sitemap: "https://www.aule.fr/sitemap.xml",
    host: "https://www.aule.fr",
  };
}
