import { getLocale, getTranslations } from "next-intl/server";
import { setLocale } from "@/i18n/actions";
import { locales, type Locale } from "@/i18n/config";

export async function LanguageSwitcher() {
  const t = await getTranslations("LanguageSwitcher");
  const current = await getLocale();

  // Each language is named in its own language, in both interfaces.
  const names: Record<Locale, string> = { en: t("english"), ar: t("arabic") };

  return (
    <form action={setLocale} className="flex items-center gap-3">
      <span id="language-label" className="text-sm font-medium">
        {t("label")}
      </span>
      <div role="group" aria-labelledby="language-label" className="flex gap-2">
        {locales.map((locale) => (
          <button
            key={locale}
            type="submit"
            name="locale"
            value={locale}
            lang={locale}
            aria-pressed={locale === current}
            className="min-h-11 rounded-md border border-zinc-300 px-4 text-sm aria-pressed:bg-zinc-900 aria-pressed:text-white dark:border-zinc-700 dark:aria-pressed:bg-zinc-100 dark:aria-pressed:text-zinc-900"
          >
            {names[locale]}
          </button>
        ))}
      </div>
    </form>
  );
}
