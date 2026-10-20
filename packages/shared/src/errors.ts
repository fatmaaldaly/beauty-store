import { z } from "zod";

// Standard error body (D-123). Phase 5 adds `details` and `requestId`.
export const ErrorResponse = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
  }),
});
export type ErrorResponse = z.infer<typeof ErrorResponse>;
