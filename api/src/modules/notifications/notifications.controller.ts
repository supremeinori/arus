import { Request, Response, NextFunction } from 'express';
import { NotificationsService } from './notifications.service';
import { registerDeviceTokenSchema } from './notifications.schema';

const notificationsService = new NotificationsService();

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
