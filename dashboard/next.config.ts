import path from "node:path";
import type { NextConfig } from "next";

const isDevelopment = process.env.NODE_ENV === "development";

const contentSecurityPolicy = [
  "default-src 'self'",
  "base-uri 'self'",
  "frame-ancestors 'none'",
  "form-action 'self'",
  "object-src 'none'",
  `script-src 'self' 'unsafe-inline'${isDevelopment ? " 'unsafe-eval'" : ""}`,
  "style-src 'self' 'unsafe-inline'",
  "font-src 'self' data:",
  "img-src 'self' data: blob: https://basemaps.cartocdn.com https://tiles.openfreemap.org",
  "connect-src 'self' https://api.open-meteo.com https://*.supabase.co wss://*.supabase.co https://basemaps.cartocdn.com https://tiles.openfreemap.org",
  "worker-src 'self' blob:",
  "manifest-src 'self'",
  // En local, cette directive ferait convertir par Safari les assets HTTP de
  // localhost en HTTPS alors que le serveur de développement n'écoute qu'en HTTP.
  ...(!isDevelopment ? ["upgrade-insecure-requests"] : []),
  "report-uri /api/csp-report",
].join("; ");

const nextConfig: NextConfig = {
  reactStrictMode: true,
  outputFileTracingRoot: path.join(__dirname),
  async redirects() {
    const privatePrototypes = [
      "conducteur",
      "controleur",
      "regulateur",
      "exploitation",
      "vtc",
      "commercant",
      "admin",
      "msr",
    ];

    return [
      ...privatePrototypes.map((prototype) => ({
        source: `/pro/${prototype}`,
        destination: "/pro",
        permanent: false,
      })),
      {
        source: "/:path*",
        has: [{ type: "host", value: "aule.fr" }],
        destination: "https://www.aule.fr/:path*",
        permanent: true,
      },
    ];
  },
  async headers() {
    return [
      {
        source: "/",
        headers: [
          {
            key: "Cache-Control",
            value: "public, s-maxage=3600, stale-while-revalidate=86400",
          },
        ],
      },
      {
        source: "/:path*",
        headers: [
          { key: "Content-Security-Policy", value: contentSecurityPolicy },
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          {
            key: "Permissions-Policy",
            value: "camera=(), microphone=(), geolocation=(self)",
          },
          ...(!isDevelopment
            ? [
                {
                  key: "Strict-Transport-Security",
                  value: "max-age=63072000; includeSubDomains; preload",
                },
              ]
            : []),
        ],
      },
    ];
  },
};

export default nextConfig;
