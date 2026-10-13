# Progress

Current phase: 4, Repository and environments (milestone M1)
Next task: 4.2

## Phase 4

| Task | Description | Status | Branch | Tests |
| --- | --- | --- | --- | --- |
| 4.1 | Monorepo skeleton: npm workspaces, Turborepo, three Next.js apps, `packages/shared`, Prettier | Done, 13 Oct 2026 | `main` (no branch, by choice) | lint, typecheck, build pass |
| 4.2 | Tailwind logical classes; next-intl in the dashboard | Not started | | |
| 4.3 | Prisma schema, constraints migration, database test script on local Supabase | Not started | | T-SY-05 |
| 4.4 | Mailpit, `.env.example` files, README | Not started | | NFR-28 |
| 4.5 | `/api/*` rewrites and `GET /api/v1/health` | Not started | | |
| 4.6 | GitHub Actions CI | Not started | | T-SY-05, T-NF-07 |
| 4.7 | Supabase demo project and private Vercel projects | Not started | | |

## Known gaps

- `npm audit`: 5 high, all one issue in `braces`, via `eslint-config-next` 16.4.0 → `@next/eslint-plugin-next` → `fast-glob` → `micromatch`. Lint tooling only, not shipped to users. `npm audit fix --force` would downgrade `eslint-config-next` to 14, so it is not used. Audit policy is decided in task 4.6 (T-NF-07, NFR-15).

## Notes

- 4.1: the create-next-app `--api` template has no ESLint config or `lint` script; both were added by hand.
- 4.1: create-next-app reports "not writable" when the parent folder doesn't exist yet.
- 4.1: `.gitattributes` forces LF line endings so Prettier and the Linux CI match Windows checkouts.
