import app from './app';
import { env } from './config/env';
import { logger } from './config/logger';
import { prisma } from './config/db';
import { NotificationsService } from './modules/notifications/notifications.service';

const notificationsService = new NotificationsService();

const server = app.listen(env.PORT, () => {
  logger.info(`🚀 ARUS API server running on port ${env.PORT} in ${env.NODE_ENV} mode`);
  logger.info(`Health check available at http://localhost:${env.PORT}/api/health`);

  // Background job: evaluasi stok tiap 15 menit untuk push notifikasi otomatis
  // (low_stock & out_of_stock) walau tidak ada user buka aplikasi.
  const EVAL_INTERVAL_MS = 15 * 60 * 1000; // 15 menit
  setInterval(async () => {
    try {
      // Cari owner pertama sebagai actor untuk job background
      const owner = await prisma.user.findFirst({ where: { role: 'owner' }, select: { id: true } });
      const actorId = owner?.id;
      const result = await notificationsService.evaluateAndTrigger(actorId);
      if (result.triggered_count > 0) {
        logger.info(`[Scheduler] Notifikasi stok terpicu: ${result.triggered_count}`);
      }
    } catch (err) {
      logger.warn({ err }, '[Scheduler] Evaluasi notifikasi stok gagal');
    }
  }, EVAL_INTERVAL_MS);

  // Jalankan sekali saat startup (setelah server siap)
  setTimeout(async () => {
    try {
      const owner = await prisma.user.findFirst({ where: { role: 'owner' }, select: { id: true } });
      const actorId = owner?.id;
      const result = await notificationsService.evaluateAndTrigger(actorId);
      if (result.triggered_count > 0) {
        logger.info(`[Startup] Notifikasi stok terpicu: ${result.triggered_count}`);
      }
    } catch (err) {
      logger.warn({ err }, '[Startup] Evaluasi notifikasi stok gagal');
    }
  }, 5000);
});

process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  server.close(() => {
    logger.info('Process terminated');
  });
});
