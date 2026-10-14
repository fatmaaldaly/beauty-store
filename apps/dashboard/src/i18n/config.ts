// Interface languages of the dashboard (D-003, AD-15).
export const locales = ["en", "ar"] as const;
export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = "en";

// Temporary source of the language until staff sign-in exists (phase 6).
export const LOCALE_COOKIE = "dashboard_locale";

export function directionOf(locale: Locale): "ltr" | "rtl" {
  return locale === "ar" ? "rtl" : "ltr";
}
