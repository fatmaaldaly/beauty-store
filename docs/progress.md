# Progress

Current phase: 4, Repository and environments (milestone M1)
Next task: 4.7 (in progress, see "4.7 status")

## Phase 4

| Task | Description | Status | Branch | Tests |
| --- | --- | --- | --- | --- |
| 4.1 | Monorepo skeleton: npm workspaces, Turborepo, three Next.js apps, `packages/shared`, Prettier | Done, 13 Oct 2026 | `main` (no branch, by choice) | lint, typecheck, build pass |
| 4.2 | Tailwind logical classes; next-intl in the dashboard | Done, 14 Oct 2026 | `feat/rtl-and-i18n` | lint, typecheck, build; manual: switch, RTL, keyboard, 360 px, cookie tampering |
| 4.3 | Prisma schema, constraints migration, database test script on local Supabase | Done, 19 Oct 2026 | `feat/database-setup` | lint, typecheck, build; `db:test` 22/22 incl. T-SY-05; manual: public API key gets "permission denied" (TH-12) |
| 4.4 | Mailpit, `.env.example` files, README | Done, 19 Oct 2026 | `feat/env-and-readme` | NFR-28: fresh-clone walkthrough in 10 min; manual: SMTP test email reached Mailpit |
| 4.5 | `/api/*` rewrites and `GET /api/v1/health` | Done, 20 Oct 2026 | `feat/api-proxy-and-health` | lint, typecheck, build; manual: health 200 on :3002 and through both proxies (:3000, :3001); database stopped gives 503 `SERVICE_UNAVAILABLE` through the proxies; recovers without restart; missing `API_INTERNAL_URL` stops the frontend from starting |
| 4.6 | GitHub Actions CI | Done, 20 Oct 2026 | `feat/ci` | CI green on PR #5: format, lint, typecheck, migrations on empty `postgres:17`, `db:test` incl. T-SY-05, build, dependency scan and Gitleaks (T-NF-07) |
| 4.7 | Supabase demo project and private Vercel projects | In progress: Supabase and code done; Vercel not started | `feat/deploy-demo` | so far: `db:test` 22/22 on the demo database incl. T-SY-05; lint, typecheck, build, format:check; manual: proxy forwards path, query and bypass header, secret not in the response |

### 4.7 status (21 Oct 2026)

Done:

1. Decisions D-151 (protected API, bypass header), D-152 (migrations by hand until phase 5), D-153 (Stockholm `eu-north-1`, Vercel `arn1`) recorded.
2. Supabase project `beauty-store-demo`: Data API off, migrations applied, `db:test` 22/22, reset to empty.
3. Code on `feat/deploy-demo`: `apps/api/vercel.json` (`arn1`); `src/proxy.ts` in both frontends replaces `rewrites()`; `API_PROTECTION_BYPASS` in `.env.example`; API build runs `prisma generate`; `DIRECT_URL` passed through to the Turborepo build task.

Next:

1. Push `feat/deploy-demo`, open the PR, CI green, merge to `main` (Vercel builds production from `main`).
2. Vercel API project (root `apps/api`): `DATABASE_URL` (transaction pooler), `DIRECT_URL` (session pooler); All Deployments protection; create the bypass secret; "Only build production"; confirm region `arn1`.
3. Vercel storefront and dashboard projects: `API_INTERNAL_URL` (API production domain), `API_PROTECTION_BYPASS`, storefront `NEXT_PUBLIC_SITE_URL`; All Deployments protection.
4. Deployed checks: each URL asks for Vercel login when signed out; health 200 through both frontends; the API without the bypass header is refused; `x-middleware-rewrite` stripped or not (see notes).
5. Update the README (deployment), `CLAUDE.md` current status and this file in `docs/progress-4.7`; mark 4.7 done.

## Known gaps

- `npm audit`: 5 high, all one issue in `braces`, via `eslint-config-next` 16.4.0 → `@next/eslint-plugin-next` → `fast-glob` → `micromatch`. Lint tooling only, not shipped to users. `npm audit fix --force` would downgrade `eslint-config-next` to 14, so it is not used. Since 4.6 (D-150), CI blocks only on production dependencies (0 issues); the full audit still reports this one on every run.

## Notes

- 4.1: the create-next-app `--api` template has no ESLint config or `lint` script; both were added by hand.
- 4.1: create-next-app reports "not writable" when the parent folder doesn't exist yet.
- 4.1: `.gitattributes` forces LF line endings so Prettier and the Linux CI match Windows checkouts.
- 4.2: candidate ESLint rule for phase 5 (D-144): reject physical direction classes (`pl-`, `mr-`, `text-left`, `left-`, `border-l`, ...).
- 4.2: test for phase 5: `ar.json` has exactly the same keys as `en.json` (TypeScript only checks code against `en.json`).
- 4.2: phase 6: move the locale list (`en`, `ar`) to `packages/shared`, shared with `staff_users.locale` in the API.
- 4.2: all dashboard messages are sent to the browser through `NextIntlClientProvider`; limit per screen in phase 10 if the files grow.
- 4.2: `.vscode/settings.json` sets LF line endings and format-on-save with Prettier.
- 4.3: the verified database files moved from `docs/database/` to `apps/api/` (`prisma.config.ts`, `prisma/schema.prisma`, `prisma/sql/`, `prisma/test-constraints.mjs`).
- 4.3: D-148: `pg_trgm` and `citext` are created in the init migration; Prisma's `postgresqlExtensions` preview reported Supabase's pre-installed extensions as drift.
- 4.3: Prisma 7 doesn't load `.env`; `prisma.config.ts` starts with `import "dotenv/config"` (dev dependency). CI and Vercel set real environment variables instead.
- 4.3: Prisma 7 `migrate dev` no longer generates the client; run `npx prisma generate`. The client (`apps/api/src/generated/`) is gitignored, so CI (4.6) must generate it before typecheck.
- 4.3: `npm run db:test -w @beauty/api` inserts rows; run `npx prisma migrate reset` (local only) before running it again.
- 4.3: local Supabase needs Docker Desktop running before `npx supabase start`; first start downloads the images.
- 4.3: local Supabase includes Mailpit (http://127.0.0.1:54324); check in 4.4 whether a separate Mailpit is still needed.
- 4.4: no separate Mailpit: the one in the Supabase stack is used (D-085 unchanged). `supabase/config.toml` exposes its SMTP port 54325; a test email sent there showed up in the inbox.
- 4.4: phase 5 decides whether the local SMTP host and port become environment variables (architecture section 7 lists none) or defaults in the local email sender.
- 4.4: `.env.example` values: only local, non-secret values filled in; every key is blank, even local Supabase keys, so the CI secret scan (4.6) has nothing to flag.
- 4.4: NFR-28 walkthrough: fresh clone to `npm run dev` in 10 minutes by following the README alone (Docker images were already downloaded; a new machine adds about 10 minutes).
- 4.4: `npm run format:check` fails on `apps/api/prisma/test-constraints.mjs` (sandbox file, never formatted); fix before CI runs format checks in 4.6.
- 4.4: add the health check to the README in 4.5 (done: "Check it's running").
- 4.5: D-149: the health check returns 503 `SERVICE_UNAVAILABLE` when the database is unreachable or slower than 2 seconds. A refused connection fails at once, so the timeout only applies to a slow database.
- 4.5: `API_INTERNAL_URL` is read when `next.config.ts` loads, so on Vercel (4.7) it must be set before the build, and changing it needs a redeploy. The config throws if it's missing; there is no localhost fallback.
- 4.5: when the API app itself is down, the frontends' proxy answers with a plain-text `500 Internal Server Error`, not the D-123 JSON. The frontends' API client (phases 7 and 10) must treat any non-JSON error response as a generic failure.
- 4.5: the frontends must never get their own `app/api` folder; the rewrite (afterFiles) would be shadowed by it.
- 4.5: Windows can reserve the Supabase ports (WinNAT, 54318-54417 on 20 Oct); fix in the README troubleshooting table.
- 4.6: Turborepo 2 strict env mode: a task only sees variables listed in `turbo.json`. Locally `.env` files hide this, because Next reads them from disk. Any new variable a build or `next.config.ts` needs must be added there (`env` if it changes the output, `passThroughEnv` if not).
- 4.6: `next typegen` loads `next.config.ts`, so typecheck needs `API_INTERNAL_URL` too.
- 4.6: the API build needs `DATABASE_URL` to be set (Next imports `db.ts` while collecting routes; no connection is made). Vercel (4.7) needs it at build time.
- 4.6: the "Dependency scan (all, report only)" step shows red with an annotation while the `braces` issue exists; that's expected (D-150) and doesn't fail the job.
- 4.6: phase 5 adds Vitest and the seed-twice check (BE-16) to CI.
- 4.6: GitHub notice: `ubuntu-latest` moves to Ubuntu 26 from 19 Oct 2026; watch the first runs after the switch.
- 4.6: GitHub settings (not in code): ruleset "CI" on the default branch, active, no bypass: no deletion, no force push, pull request required (0 approvals, so a solo developer can merge), required status check `ci` (the job name in `ci.yml`; rename both together). Secret Protection push protection is on (NFR-16). From now on every change to `main` goes through a PR.
- 4.7: Supabase project `beauty-store-demo` created with the "Europe" option, which assigned Stockholm (`eu-north-1`); API functions in `arn1` (D-153). Data API turned off at creation (D-088); "automatic RLS" left off, because the migrations enable RLS and the demo must match local and CI.
- 4.7: migrations applied by hand (D-152); `db:test` 22/22 on the demo database incl. T-SY-05 and SM-3 (`bought=5 soldOut=15 finalStock=0`), then `migrate reset` to leave it empty.
- 4.7: the session pooler (port 5432) allows 15 clients on the Nano compute, so the 20-client concurrency tests fail there with `EMAXCONNSESSION`. Run `db:test` against Supabase with `DB_URL` set to the transaction pooler (port 6543), which queues extra clients instead. Phase 5: keep the app's `pg` pool small per function.
- 4.7: Free-plan direct connections are IPv6-only; Vercel and GitHub Actions use IPv4, so `DIRECT_URL` is the session pooler string and `DATABASE_URL` the transaction pooler.
- 4.7: D-151: `/api/*` forwarding moved from `rewrites()` to `src/proxy.ts` in both frontends, adding `x-vercel-protection-bypass` from `API_PROTECTION_BYPASS` (read at runtime). Verified with `next start` against a fake API: path, query and secret forwarded; the secret is not in the response.
- 4.7: a proxy rewrite to another host makes Next add `x-middleware-rewrite: <API_INTERNAL_URL>/...` to the response, which reveals the API address. Check on Vercel whether the platform strips it.
- 4.7: Next 16 refuses a second `next dev` in the same app folder ("Another next dev server is already running"); use `next build` + `next start -p <port>` for a second instance.
- 4.7: Prisma 7's `env("DIRECT_URL")` makes even `prisma generate` fail without the variable, so the API build (`prisma generate && next build`) needs `DIRECT_URL` (Turborepo `passThroughEnv`, and set in Vercel).
