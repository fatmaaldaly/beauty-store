import type { NextConfig } from "next";
import createNextIntlPlugin from "next-intl/plugin";

// Finds src/i18n/request.ts automatically.
const withNextIntl = createNextIntlPlugin();

const nextConfig: NextConfig = {
  transpilePackages: ["@beauty/shared"],
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
