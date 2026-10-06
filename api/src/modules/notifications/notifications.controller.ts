import { Request, Response, NextFunction } from 'express';
import { NotificationsService } from './notifications.service';

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
}
