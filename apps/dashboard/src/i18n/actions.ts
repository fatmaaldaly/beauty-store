"use server";

import { hasLocale } from "next-intl";
import { cookies } from "next/headers";
import { LOCALE_COOKIE, locales } from "./config";

// Temporary until phase 10, when the choice is saved with PATCH /admin/me (AD-15).
export async function setLocale(formData: FormData) {
  // Server Actions are public endpoints: validate the input here too.
  const candidate = formData.get("locale");
  if (!hasLocale(locales, candidate)) return;

  const cookieStore = await cookies();
  cookieStore.set(LOCALE_COOKIE, candidate, {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
  });
}
