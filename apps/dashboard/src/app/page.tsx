import { getTranslations } from "next-intl/server";
import { LanguageSwitcher } from "@/components/language-switcher";

export default async function Home() {
  const t = await getTranslations("Home");

  return (
    <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col gap-6 px-4 py-16">
      <LanguageSwitcher />
      <h1 className="text-3xl font-semibold">{t("title")}</h1>
      <p className="text-zinc-600 dark:text-zinc-400">{t("description")}</p>
    </main>
  );
}
