import { NextResponse, type NextRequest } from "next/server";

// Forwards /api/* to the API app (D-072): no CORS, same-site cookies, and the
// API address stays private. On Vercel the API is behind Deployment
// Protection, so the request carries the bypass secret (D-151).
export function proxy(request: NextRequest) {
  const apiUrl = process.env.API_INTERNAL_URL;
  if (!apiUrl) throw new Error("API_INTERNAL_URL is not set");
  const target = new URL(
    request.nextUrl.pathname + request.nextUrl.search,
    apiUrl,
  );

  const headers = new Headers(request.headers);
  const bypass = process.env.API_PROTECTION_BYPASS;
  if (bypass) headers.set("x-vercel-protection-bypass", bypass);

  return NextResponse.rewrite(target, { request: { headers } });
}

export const config = { matcher: "/api/:path*" };
