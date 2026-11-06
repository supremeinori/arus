import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { NotificationsService } from './notifications.service';
import { registerDeviceTokenSchema } from './notifications.schema';

const notificationsService = new NotificationsService();

/**
 * Verifikasi header Authorization cron dengan perbandingan waktu konstan.
 * Vercel Cron mengirim `Authorization: Bearer <CRON_SECRET>` otomatis bila
 * environment variable CRON_SECRET diset di project.
 */
function isValidCronSecret(req: Request): boolean {
  const secret = process.env.CRON_SECRET;
  if (!secret) return false;

  const header = req.headers.authorization || '';
  const expected = `Bearer ${secret}`;
  if (header.length !== expected.length) return false;

  return crypto.timingSafeEqual(Buffer.from(header), Buffer.from(expected));
}

export class NotificationsController {
  async list(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = (req as any).user.id;
      const result = await notificationsService.getUserNotifications(userId);

      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async markRead(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const userId = (req as any).user.id;
      const updated = await notificationsService.markAsRead(id, userId);

      res.json({
        success: true,
        message: 'Notifikasi ditandai sudah dibaca.',
        data: updated,
      });
    } catch (err) {
      next(err);
    }
  }

  async markAllRead(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = (req as any).user.id;
      const result = await notificationsService.markAllAsRead(userId);

      res.json({
        success: true,
        message: 'Semua notifikasi ditandai sudah dibaca.',
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async evaluate(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = (req as any).user.id;
      const result = await notificationsService.evaluateAndTrigger(userId);

      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Endpoint cron: evaluasi stok kritis tanpa sesi user.
   * Diamankan dengan CRON_SECRET (dikirim Vercel Cron sebagai Bearer token).
   */
  async evaluateCron(req: Request, res: Response, next: NextFunction) {
    try {
      if (!process.env.CRON_SECRET) {
        res.status(503).json({
          success: false,
          message: 'CRON_SECRET belum diset di server. Cron notifikasi tidak aktif.',
        });
        return;
      }

      if (!isValidCronSecret(req)) {
        res.status(401).json({
          success: false,
          message: 'Unauthorized.',
        });
        return;
      }

      const result = await notificationsService.evaluateAndTrigger();

      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  async registerToken(req: Request, res: Response, next: NextFunction) {
    try {
      const userId = (req as any).user.id;
      const parsed = registerDeviceTokenSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({
          success: false,
          message: 'Payload device token tidak valid.',
          errors: parsed.error.flatten(),
        });
        return;
      }

      const result = await notificationsService.registerDeviceToken(
        userId,
        parsed.data
      );

      res.json({
        success: true,
        message: 'Device token terdaftar.',
        data: {
          id: result.id,
          platform: result.platform,
        },
      });
    } catch (err) {
      next(err);
    }
  }
}
