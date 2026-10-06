import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import { NotificationPriority, NotificationType, Role } from '@prisma/client';
import { CreateNotificationInput } from './notifications.schema';

export class NotificationsService {
  async getUserNotifications(userId: string) {
    const [notifications, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: { user_id: userId },
        orderBy: { created_at: 'desc' },
        take: 50,
      }),
      prisma.notification.count({
        where: { user_id: userId, read_at: null },
      }),
    ]);

    return {
      unread_count: unreadCount,
      notifications,
    };
  }

  async markAsRead(notificationId: string, userId: string) {
    const notif = await prisma.notification.findUnique({
      where: { id: notificationId },
    });

    if (!notif) {
      throw new AppError('NOT_FOUND', 404, 'Notifikasi tidak ditemukan.');
    }

    if (notif.user_id !== userId) {
      throw new AppError('FORBIDDEN', 403, 'Anda tidak memiliki hak akses untuk notifikasi ini.');
    }

    return prisma.notification.update({
      where: { id: notificationId },
      data: { read_at: new Date() },
    });
  }

  async markAllAsRead(userId: string) {
    const updated = await prisma.notification.updateMany({
      where: { user_id: userId, read_at: null },
      data: { read_at: new Date() },
    });

    return {
      affected_count: updated.count,
    };
  }

  async createNotification(input: CreateNotificationInput) {
    if (input.dedup_key) {
      const existing = await prisma.notification.findFirst({
        where: {
          user_id: input.user_id,
          dedup_key: input.dedup_key,
        },
      });
      if (existing) {
        return existing; // Abaikan duplikat
      }
    }

    return prisma.notification.create({
      data: {
        user_id: input.user_id,
        type: input.type,
        priority: input.priority,
        title: input.title,
        body: input.body,
        payload: input.payload,
        dedup_key: input.dedup_key,
      },
    });
  }

  /**
   * Evaluasi otomatis untuk men-generate notifikasi stok kritis & pencapaian target.
   */
  async evaluateAndTrigger(actorId: string) {
    const todayStr = new Date().toISOString().slice(0, 10);
    let triggeredCount = 0;

    // 1. Ambil seluruh stok yang di bawah atau sama dengan reorder_level
    const lowStocks = await prisma.inventory.findMany({
      where: {
        quantity: { lte: prisma.inventory.fields.reorder_level },
      },
      include: {
        product: { select: { name: true, sku: true, unit: true } },
        outlet: { select: { name: true } },
      },
      take: 10,
    });

    // 2. Ambil seluruh user Owner dan Manager untuk diberi peringatan stok kritis
    const recipients = await prisma.user.findMany({
      where: {
        is_active: true,
        role: { in: [Role.owner, Role.manager] },
      },
      select: { id: true },
    });

    for (const item of lowStocks) {
      const dedupKey = `low_stock_${item.outlet_id}_${item.product_id}_${todayStr}`;

      for (const user of recipients) {
        const existing = await prisma.notification.findFirst({
          where: { user_id: user.id, dedup_key: dedupKey },
        });

        if (!existing) {
          await prisma.notification.create({
            data: {
              user_id: user.id,
              type: NotificationType.low_stock,
              priority: NotificationPriority.high,
              title: `Peringatan Stok: ${item.product.name} Menipis`,
              body: `Sisa stok di ${item.outlet.name} tersisa ${item.quantity} ${item.product.unit} (batas aman minimum: ${item.reorder_level}). Segera lakukan pengadaan.`,
              dedup_key: dedupKey,
              payload: {
                product_id: item.product_id,
                outlet_id: item.outlet_id,
                quantity: item.quantity,
                reorder_level: item.reorder_level,
              },
            },
          });
          triggeredCount++;
        }
      }
    }

    return {
      message: 'Evaluasi pemicu notifikasi selesai.',
      triggered_count: triggeredCount,
    };
  }
}
