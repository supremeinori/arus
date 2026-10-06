import net from 'net';

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
  if (dbOnline !== null && now - lastCheck < 5000) {
    return dbOnline;
  }
  lastCheck = now;

  return new Promise<boolean>((resolve) => {
    const socket = new net.Socket();
    let resolved = false;

    const finish = (status: boolean) => {
      if (!resolved) {
        resolved = true;
        dbOnline = status;
        socket.destroy();
        resolve(status);
      }
    };

    socket.setTimeout(120);
    socket.once('connect', () => finish(true));
    socket.once('timeout', () => finish(false));
    socket.once('error', () => finish(false));

    try {
      socket.connect(5432, '127.0.0.1');
    } catch (_) {
      finish(false);
    }
  });
}
