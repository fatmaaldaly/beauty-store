import type { NextConfig } from "next";

// src/proxy.ts reads this on every request; checked here too so a missing
// value stops the build, not the first request. No localhost fallback.
const apiUrl = process.env.API_INTERNAL_URL;
if (!apiUrl) throw new Error("API_INTERNAL_URL is not set");

const nextConfig: NextConfig = {
  transpilePackages: ["@beauty/shared"],
  // /api/* forwarding lives in src/proxy.ts (D-072, D-151).
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default nextConfig;
