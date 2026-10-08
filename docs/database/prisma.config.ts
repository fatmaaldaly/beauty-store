import { defineConfig, env } from "prisma/config";

// The Prisma CLI (migrations) uses the DIRECT connection (D-083).
// The running app connects through the pooled DATABASE_URL via the pg driver adapter.
export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: { path: "prisma/migrations" },
  datasource: { url: env("DIRECT_URL") },
});
