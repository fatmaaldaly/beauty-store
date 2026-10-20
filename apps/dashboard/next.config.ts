import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

// Finds src/i18n/request.ts automatically.
const withNextIntl = createNextIntlPlugin();

// Read when the config loads (at build time on Vercel), so changing it needs a
// redeploy. No fallback: a missing value would build a proxy to nowhere.
const apiUrl = process.env.API_INTERNAL_URL;
if (!apiUrl) throw new Error("API_INTERNAL_URL is not set");

const nextConfig: NextConfig = {
  transpilePackages: ["@beauty/shared"],
  // The browser only calls this site's /api/*; the server forwards it to the
  // API app (D-072). No CORS, same-site cookies, API address stays private.
  async rewrites() {
    return [{ source: "/api/:path*", destination: `${apiUrl}/api/:path*` }];
  },
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
};

export default withNextIntl(nextConfig);
