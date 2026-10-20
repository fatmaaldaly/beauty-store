import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "@/generated/prisma/client";

function createClient() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) throw new Error("DATABASE_URL is not set");
  return new PrismaClient({ adapter: new PrismaPg({ connectionString }) });
}

// `next dev` reloads modules on every save. Keeping the client on globalThis
// stops each reload from opening another connection pool.
const globalForDb = globalThis as unknown as { db?: PrismaClient };
export const db = globalForDb.db ?? createClient();
if (process.env.NODE_ENV !== "production") globalForDb.db = db;

// Health check (D-149): true if the database answers within `timeoutMs`.
export async function pingDatabase(timeoutMs: number): Promise<boolean> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () => reject(new Error(`timed out after ${timeoutMs} ms`)),
      timeoutMs,
    );
  });
  try {
    await Promise.race([db.$queryRaw`SELECT 1`, timeout]);
    return true;
  } catch (error) {
    // Logged on the server only; the response never says why (D-149).
    console.error("Database ping failed:", error);
    return false;
  } finally {
    clearTimeout(timer);
  }
}
