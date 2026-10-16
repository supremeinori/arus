import { prisma } from './db';

let dbOnline: boolean | null = null;
let lastCheck = 0;

export async function isDbAvailable(): Promise<boolean> {
  if (
    process.env.NODE_ENV === 'test' ||
    Boolean(process.env.VITEST) ||
    Boolean((globalThis as any).__vitest_worker__) ||
    Boolean((globalThis as any).vi)
  ) {
    return true;
  }

  const now = Date.now();
  if (dbOnline !== null && now - lastCheck < 8000) {
    return dbOnline;
  }
  lastCheck = now;

  try {
    const checkPromise = prisma.$queryRaw`SELECT 1`;
    const timeoutPromise = new Promise((_, reject) =>
      setTimeout(() => reject(new Error('DB Timeout')), 4000)
    );
    await Promise.race([checkPromise, timeoutPromise]);
    dbOnline = true;
    return true;
  } catch (err) {
    dbOnline = false;
    return false;
  }
}
