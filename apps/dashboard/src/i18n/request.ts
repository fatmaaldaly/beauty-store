import { hasLocale } from "next-intl";
import { getRequestConfig } from "next-intl/server";
import { cookies } from "next/headers";
import { defaultLocale, LOCALE_COOKIE, locales } from "./config";

export default getRequestConfig(async () => {
  // Phase 6/10: read the staff member's saved language from the session instead (D-092).
  const cookieStore = await cookies();
  const candidate = cookieStore.get(LOCALE_COOKIE)?.value;
  const locale = hasLocale(locales, candidate) ? candidate : defaultLocale;

  return {
    locale,
    messages: (await import(`../../messages/${locale}.json`)).default,
    // All times are shown in Cairo time, whatever the language (D-045, AD-15).
    timeZone: "Africa/Cairo",
  };
});
