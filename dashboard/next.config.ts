import path from "node:path";
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  outputFileTracingRoot: path.join(__dirname),
  webpack: (config, { dev }) => {
    if (dev) {
      // Évite les chunks webpack corrompus après hot reload (Next 15)
      config.cache = false;
    }
    return config;
  },
};

export default nextConfig;
