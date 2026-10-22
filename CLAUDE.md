# Beauty Store — project context for Claude Code

Portfolio project: a production-grade B2C beauty & cosmetics store for Egypt (EGP),
built by a junior developer who wants to understand every decision.
All planning is approved. Source of truth is the `docs/` folder.

## Documents (read before working on a task)

| File | Contents |
| --- | --- |
| `docs/prd.md` | Requirements (ST-, AD-, BE-, NFR-), user flows, decision log D-001 to D-154 |
| `docs/architecture.md` | Components, monorepo layout, module layers, environments, free-tier limits |
| `docs/database-design.md` | 41 tables, constraints, transactions and locking (section 5) |
| `docs/api-contracts.md` | Every endpoint, permissions, error codes, idempotency, rate limits |
| `docs/security-and-testing.md` | Threats TH-01..16, security checklist, test cases T-*, traceability matrix |
| `docs/roadmap.md` | Phases 4 to 13, tasks, acceptance criteria, definition of done |
| `docs/progress.md` | Current phase, task status, branches (keep updated) |

If a document and the code disagree, stop and ask; don't silently pick one.
Never change an approved decision without asking; record changes in the decision log.

## How we work (D-139)

The developer writes and runs the code. Claude's role is to:
1. **Explain** the task, the concepts and the approach, citing requirement and test IDs.
2. Let the developer **build** it. For security-critical code (sessions, password hashing,
   webhook verification, the order transaction, refunds) provide a reference implementation
   and walk through it line by line.
3. Help write **tests first for failure cases**.
4. **Review** the branch against the definition of done, explaining each comment.

Explain in plain language. Don't write large amounts of code unasked. Prefer small steps.

## Stack (verified versions)

- npm workspaces + Turborepo 2; Node 22+ (D-143: npm instead of pnpm)
- Next.js 16.4 (App Router) for all three apps; React 19; TypeScript 5 strict
- Tailwind CSS 4 (logical, RTL-safe classes only: `ps-`, `pe-`, `ms-`, `me-`, `start-`, `end-`, `text-start`)
- Prisma 7.10 with the PostgreSQL driver adapter; Supabase (PostgreSQL + Storage)
- Zod schemas in `packages/shared` define every request/response; OpenAPI generated from them
- Paymob (behind `PaymentProvider`), Resend (behind `EmailSender`), Sentry, Vercel Hobby
- Tests: Vitest, Testing Library, Playwright + axe, Lighthouse CI, k6

Next.js 16 changed some APIs: check `node_modules/next/dist/docs/` and each app's `AGENTS.md`
before relying on memory or tutorials.

## Layout

```
apps/storefront   Next.js customer site (port 3000)
apps/dashboard    Next.js admin, English + Arabic RTL (port 3001)
apps/api          Next.js Route Handlers only (port 3002)
  app/api/v1/...    thin route handlers
  src/modules/      business modules: route → service → repository
  src/platform/     db, auth, errors, logging, adapters
  prisma/           schema, migrations, seed
packages/shared   Zod schemas, types, constants
```

Frontends never touch the database or Supabase; they proxy `/api/*` to the API app.
Business logic never lives in route files. Modules call each other's services, never repositories.

## Non-negotiable rules

- **R-001** Payment status changes only through verified, idempotent webhooks or a
  server-side status lookup, never from the browser.
- **R-002** The server recalculates every price and total; clients send IDs and quantities.
- **R-003** Every permission is enforced in the API (named permissions, D-126).
- **R-004** Never store or handle raw card details.
- Money: `numeric(12,2)` in the DB; `{ amount: "350.00", currency: "EGP" }` in the API;
  never JavaScript floating-point arithmetic for money.
- No external calls (payment provider, email) inside database transactions.
- Stock is changed only by the inventory service, under row locks, with a stock movement.
- Every new table needs Row Level Security enabled (Supabase lockdown, D-088).
- Secrets only in environment variables; never with a `NEXT_PUBLIC_` prefix; never logged.

## Definition of done (every task)

- Behavior matches the PRD acceptance criteria
- The task's test cases (T-*) pass, failure cases included
- `npm run lint`, `npm run typecheck`, tests and `npm run build` pass
- No new gaps in the essential security checklist
- New screens: loading, empty and error states; keyboard accessible; works at 360 px
- Shared Zod schemas updated for API changes
- `docs/progress.md` updated; decision log updated if a decision changed

## Git

One short-lived branch per task (`feat/...`, `fix/...`), Conventional Commits,
`main` always deployable, migrations in the same branch as the code that needs them.

## Commands

```bash
npm install                    # from the root, installs every workspace
npm run dev                    # all three apps (Turborepo)
npm run typecheck
npm run lint
npm run build
npm run dev -w @beauty/api     # one app only
npm install zod -w @beauty/api # add a dependency to one workspace
```

Local packages are referenced as `"@beauty/shared": "*"` (npm doesn't support `workspace:*`).

## Current status

Phase 4 (Repository and environments): task 1 (monorepo skeleton) **done** (13 Oct 2026);
task 2 (logical classes, next-intl in the dashboard) **done** (14 Oct 2026);
task 3 (Prisma migrations and database tests on local Supabase) **done** (19 Oct 2026);
task 4 (Mailpit SMTP, `.env.example` files, README) **done** (19 Oct 2026);
task 5 (`/api/*` rewrites, `GET /api/v1/health`, D-149) **done** (20 Oct 2026).
task 6 (GitHub Actions CI, D-150) **done** (20 Oct 2026);
task 7 (Supabase demo project, private Vercel projects in `arn1`, D-151 to D-154) **done** (22 Oct 2026).
Phase 4 is done. Next: phase 5 (Backend foundation), task 1 (route-handler wrapper).
See `docs/progress.md`; setup and deployment steps are in `README.md`.

Task 1 was verified in a sandbox before handover: create-next-app 16.4.0 with
`--ts --tailwind --eslint --app --src-dir --import-alias "@/*" --use-npm --skip-install --disable-git`
for storefront and dashboard, `--api` for the API; root `package.json` has
`"workspaces": ["apps/*", "packages/*"]` and `"packageManager": "npm@<your version>"` (Turborepo needs it);
remove each app's own `.gitignore` and `packageManager`; app names `@beauty/*`; ports 3000/3001/3002;
`"typecheck": "next typegen && tsc --noEmit"`; `transpilePackages: ["@beauty/shared"]`.

Database (task 3): schema, migrations and `test-constraints.mjs` live in `apps/api/prisma/`.
Local database is the Supabase CLI stack (Docker Desktop must be running; `npx supabase start`,
DB on port 54322, Studio 54323, Mailpit 54324). Prisma 7 notes: `.env` is loaded by
`import "dotenv/config"` in `prisma.config.ts`; run `npx prisma generate` yourself (the client in
`src/generated/` is gitignored); extensions are created in SQL, not via Prisma (D-148).
`npm run db:test -w @beauty/api` inserts rows, so reset the local DB before rerunning.
Prisma refuses `migrate reset` from Claude without the user's explicit consent each time.

Dashboard language: cookie `dashboard_locale` until phase 10 (D-147); fonts per D-146.
Deferred to phase 5: shared ESLint config package (D-144), when custom rules are added.
