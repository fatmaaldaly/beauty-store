# Beauty Store

A B2C beauty and cosmetics store for Egypt (prices in EGP), built as a portfolio project.
One repository holds three Next.js apps and a shared package:

| Folder            | What it is                                         | Local address         |
| ----------------- | -------------------------------------------------- | --------------------- |
| `apps/storefront` | Customer site                                      | http://localhost:3000 |
| `apps/dashboard`  | Staff admin, English and Arabic (RTL)              | http://localhost:3001 |
| `apps/api`        | Backend: Route Handlers, Prisma, business logic    | http://localhost:3002 |
| `packages/shared` | Zod schemas, types and constants used by all three |                       |

Requirements, architecture and decisions are in [`docs/`](docs/); start with
[`docs/architecture.md`](docs/architecture.md) and [`docs/progress.md`](docs/progress.md).

## Prerequisites

- **Node.js 22 or newer** (`node -v`); npm comes with it
- **Git**
- **Docker Desktop**, running. The local database, file storage and email inbox run in Docker
  through the Supabase CLI, which is installed with the project's npm packages.

## First-time setup

Run every command from the repository root unless a step says otherwise.

1. **Clone and install** (installs all apps and packages at once):

   ```bash
   git clone https://github.com/fatmaaldaly/beauty-store.git
   cd beauty-store
   npm install
   ```

2. **Create your environment files** from the templates. The local values are already filled in;
   blank values belong to features built in later phases and can stay empty for now.

   ```bash
   cp apps/api/.env.example apps/api/.env
   cp apps/storefront/.env.example apps/storefront/.env
   cp apps/dashboard/.env.example apps/dashboard/.env
   ```

   `.env` files are ignored by Git. Never commit one, and never give a secret a `NEXT_PUBLIC_` name
   (those values are sent to the browser).

3. **Start the local Supabase stack.** Open Docker Desktop first and wait until it says it is running.

   ```bash
   npx supabase start
   ```

   The first run downloads the Docker images and can take 10 minutes or more; later starts take
   seconds. It ends by printing the local addresses and keys.

4. **Create the database tables** and generate the Prisma client:

   ```bash
   cd apps/api
   npx prisma migrate deploy
   npx prisma generate
   cd ../..
   ```

   `migrate deploy` only applies the migrations already in the repository; it never creates new ones
   or deletes data. The generated client (`apps/api/src/generated/`) is not committed, so run
   `prisma generate` after every clone and every schema change.

5. **Check the database** (optional, about 10 seconds):

   ```bash
   npm run db:test -w @beauty/api
   ```

   It should end with `0 failed`. See [Database test data](#database-test-data) before running it again.

## Running the apps

```bash
npm run dev
```

This starts all three apps. To start one app only: `npm run dev -w @beauty/api`
(or `@beauty/storefront`, `@beauty/dashboard`).

| Service                                     | Address                                                 |
| ------------------------------------------- | ------------------------------------------------------- |
| Storefront                                  | http://localhost:3000                                   |
| Dashboard                                   | http://localhost:3001                                   |
| API                                         | http://localhost:3002                                   |
| Supabase Studio (browse the database)       | http://127.0.0.1:54323                                  |
| Mailpit (every email the app sends locally) | http://127.0.0.1:54324                                  |
| PostgreSQL                                  | `127.0.0.1:54322`, user `postgres`, password `postgres` |

When you're done, stop Supabase with `npx supabase stop`. Your data is kept for the next start.

## Everyday commands

| Command                                | What it does                                                         |
| -------------------------------------- | -------------------------------------------------------------------- |
| `npm run lint`                         | ESLint in every app                                                  |
| `npm run typecheck`                    | TypeScript checks in every app                                       |
| `npm run build`                        | Production build of every app                                        |
| `npm run format`                       | Format all files with Prettier                                       |
| `npm run db:test -w @beauty/api`       | Check the database rules (constraints, triggers, Row Level Security) |
| `npm install <package> -w @beauty/api` | Add a dependency to one app                                          |

Local packages are referenced as `"@beauty/shared": "*"`; npm doesn't support `workspace:*`.

### Database test data

`db:test` inserts test rows and doesn't remove them, so a second run fails on duplicate data.
Reset the **local** database first (in `apps/api`):

```bash
npx prisma migrate reset --force
```

This deletes all data and reapplies the migrations. Only ever run it against the local database.

## Troubleshooting

| Problem                                                                             | Cause and fix                                                                                                        |
| ----------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified` | Docker Desktop isn't running. Start it, wait until it's ready, then run `npx supabase start` again.                  |
| `DockerLifecycleInspectError` right after starting Docker                           | Docker wasn't fully started yet. Wait a minute and run the command again.                                            |
| `Cannot resolve environment variable: DIRECT_URL`                                   | `apps/api/.env` is missing or you're not in `apps/api`. Repeat setup step 2 and run Prisma commands from `apps/api`. |
| `Can't reach database server at 127.0.0.1:54322`                                    | Supabase isn't running. Run `npx supabase start`.                                                                    |
| Imports from `src/generated/prisma` not found                                       | Run `npx prisma generate` in `apps/api`.                                                                             |
| `db:test` fails with `duplicate key value`                                          | Test data from a previous run. Reset as shown in [Database test data](#database-test-data).                          |
| Image pulls fail with `429 Too Many Requests` or `TLS handshake timeout`            | Network or registry hiccup during the first start. Run `npx supabase start` again; it continues where it stopped.    |

## Working on the project

- One short-lived branch per task (`feat/...`, `fix/...`), Conventional Commits, `main` always deployable.
- Project rules (money handling, security, permissions) and the definition of done are in
  [`CLAUDE.md`](CLAUDE.md); task status is in [`docs/progress.md`](docs/progress.md).
