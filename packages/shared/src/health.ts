import { z } from "zod";

// GET /api/v1/health, success body (api-contracts section 8).
export const HealthResponse = z.object({
  status: z.literal("ok"),
  database: z.literal("ok"),
});
export type HealthResponse = z.infer<typeof HealthResponse>;
