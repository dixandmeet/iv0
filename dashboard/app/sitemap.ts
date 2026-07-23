import type { MetadataRoute } from "next";

const baseUrl = "https://www.aule.fr";

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: `${baseUrl}/`, changeFrequency: "weekly", priority: 1 },
    { url: `${baseUrl}/pro`, changeFrequency: "monthly", priority: 0.8 },
    { url: `${baseUrl}/aide`, changeFrequency: "monthly", priority: 0.5 },
    { url: `${baseUrl}/contact`, changeFrequency: "yearly", priority: 0.4 },
    { url: `${baseUrl}/confidentialite`, changeFrequency: "yearly", priority: 0.3 },
    { url: `${baseUrl}/suppression-compte`, changeFrequency: "yearly", priority: 0.3 },
    { url: `${baseUrl}/conditions`, changeFrequency: "yearly", priority: 0.3 },
    { url: `${baseUrl}/cookies`, changeFrequency: "yearly", priority: 0.3 },
  ];
}
