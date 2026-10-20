import { NextResponse } from "next/server";
import type { ErrorResponse, HealthResponse } from "@beauty/shared";
import { pingDatabase } from "@/platform/db";

// Always run on request: a health check answered from a build-time file is useless.
export const dynamic = "force-dynamic";

const noStore = { "Cache-Control": "no-store" };

export async function GET() {
  if (!(await pingDatabase(2000))) {
    return NextResponse.json<ErrorResponse>(
      {
        error: {
          code: "SERVICE_UNAVAILABLE",
          message: "Service temporarily unavailable.",
        },
      },
      { status: 503, headers: noStore },
    );
  }
  return NextResponse.json<HealthResponse>(
    { status: "ok", database: "ok" },
    { headers: noStore },
  );
}
