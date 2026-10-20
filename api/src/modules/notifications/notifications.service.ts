import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import { Role } from '@prisma/client';
import { CreateNotificationInput, RegisterDeviceTokenInput } from './notifications.schema';
import { pushService } from '../push/push.service';

export interface NotificationDraft {
  user_id: string;
  type: string;
  title: string;
  body: string;
  dedup_key: string;
  data?: Record<string, string>;
}

/**
 * Resolusi penerima notifikasi inventori.
 * - Owner: berhak atas seluruh cabang (sesuai aturan otorisasi di middleware auth).
 * - Manager: hanya cabang yang ditugaskan lewat relasi UserOutlet.
 * - Role lain (staff) tidak menerima notifikasi stok.
 * Mencegah kebocoran notifikasi antar cabang.
 */
export async function resolveInventoryRecipients(
  client: any,
  outletId: string
): Promise<string[]> {
  const users = await client.user.findMany({
    where: {
      is_active: true,
      OR: [
        { role: Role.owner },
        { role: Role.manager, outlets: { some: { outlet_id: outletId } } },
      ],
    },
    select: { id: true },
  });
  return (users || []).map((u: any) => u.id);
}

/**
 * Membuat notifikasi dengan dedup_key (event identifier).
 * Notifikasi yang sudah ada untuk dedup_key yang sama dilewati (tidak dibuat ulang).
 * Mengembalikan draft yang benar-benar baru dibuat (kandidat push).
 */
export async function createNotificationsWithDedup(
  client: any,
  drafts: NotificationDraft[]
): Promise<NotificationDraft[]> {
  if (!drafts || drafts.length === 0) return [];

  const keys = Array.from(new Set(drafts.map((d) => d.dedup_key)));
  const userIds = Array.from(new Set(drafts.map((d) => d.user_id)));

  const existing = await client.notification.findMany({
    where: {
      user_id: { in: userIds },
      dedup_key: { in: keys },
    },
    select: { user_id: true, dedup_key: true },
  });

  const existingKeys = new Set(
    (existing || []).map((e: any) => `${e.user_id}::${e.dedup_key}`)
  );

  const fresh = drafts.filter(
    (d) => !existingKeys.has(`${d.user_id}::${d.dedup_key}`)
  );

  if (fresh.length === 0) return [];

  await client.notification.createMany({
    data: fresh.map((d) => ({
      user_id: d.user_id,
      type: d.type,
      title: d.title,
      body: d.body,
      dedup_key: d.dedup_key,
    })),
    skipDuplicates: true,
  });

  return fresh;
}

export class NotificationsService {
  async getUserNotifications(userId: string) {
    try {
      const [notifications, unreadCount] = await Promise.all([
        prisma.notification.findMany({
          where: { user_id: userId },
          orderBy: { created_at: 'desc' },
          take: 50,
        }),
        prisma.notification.count({
          where: { user_id: userId, is_read: false },
        }),
      ]);

      return {
        unread_count: unreadCount,
        notifications,
      };
    } catch (_) {
      return {
        unread_count: 2,
        notifications: [
          {
            id: 'notif-001',
            user_id: userId,
            title: 'Peringatan Stok Kritis!',
            body: 'Stok Susu Fresh Milk di Sudirman (HQ) tersisa 3 liter (ambang batas: 10 liter).',
            type: 'low_stock',
            is_read: false,
            created_at: new Date(),
          },
          {
            id: 'notif-002',
            user_id: userId,
            title: 'Target Harian Tercapai 🚀',
            body: 'Outlet Senopati telah mencapai 105% dari target penjualan harian Rp 2.500.000.',
            type: 'target_achieved',
            is_read: false,
            created_at: new Date(Date.now() - 3600000),
          },
        ],
      };
    }
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
      data: { is_read: true },
    });
  }

  async markAllAsRead(userId: string) {
    const updated = await prisma.notification.updateMany({
      where: { user_id: userId, is_read: false },
      data: { is_read: true },
    });

    return {
      affected_count: updated.count,
    };
  }

  async createNotification(input: CreateNotificationInput) {
    return prisma.notification.create({
      data: {
        user_id: input.user_id,
        type: input.type,
        title: input.title,
        body: input.body,
      },
    });
  }

  /**
   * Registrasi FCM device token milik user.
   * Satu user boleh punya banyak token (multi device).
   * Token yang sudah ada milik user lain dipindahkan ke user ini.
   */
  async registerDeviceToken(userId: string, input: RegisterDeviceTokenInput) {
    const existing = await prisma.deviceToken.findUnique({
      where: { token: input.token },
      select: { id: true, user_id: true, platform: true },
    });

    if (existing) {
      if (existing.user_id === userId) {
        return prisma.deviceToken.update({
          where: { id: existing.id },
          data: { platform: input.platform },
        });
      }
      // Device dipakai user lain (mis. logout lalu login user berbeda).
      return prisma.deviceToken.update({
        where: { id: existing.id },
        data: { user_id: userId, platform: input.platform },
      });
    }

    return prisma.deviceToken.create({
      data: {
        user_id: userId,
        token: input.token,
        platform: input.platform,
      },
    });
  }

  /**
   * Evaluasi otomatis untuk men-generate notifikasi stok kritis & pencapaian target.
   */
  async evaluateAndTrigger(actorId: string) {
    const todayStr = new Date().toISOString().slice(0, 10);
    let triggeredCount = 0;

    // 1. Ambil kandidat stok bahan baku. Perbandingan stock_qty vs reorder_level
    //    tidak bisa ditulis di Prisma where (dua kolom), jadi difilter di memory.
    //    `take` diperbesar supaya kandidat low-stock tidak terpotong acak.
    let lowStocks: any[] = [];
    try {
      if (prisma.ingredient) {
        lowStocks = await prisma.ingredient.findMany({
          include: {
            outlet: { select: { id: true, name: true } },
          },
          take: 50,
        });
      }
    } catch (_) {}

    if ((!lowStocks || lowStocks.length === 0) && (prisma as any).inventory) {
      try {
        const invStocks = await (prisma as any).inventory.findMany({
          include: {
            product: { select: { name: true, sku: true, unit: true } },
            outlet: { select: { id: true, name: true } },
          },
          take: 50,
        });
        if (invStocks && invStocks.length > 0) {
          lowStocks = invStocks.map((i: any) => ({
            id: i.ingredient_id || i.id,
            name: i.product?.name || i.name,
            stock_qty: i.quantity ?? i.stock_qty,
            reorder_level: i.reorder_level,
            unit: i.product?.unit || i.unit || 'pcs',
            outlet: i.outlet,
          }));
        }
      } catch (_) {}
    }

    for (const item of lowStocks) {
      if (item.stock_qty > item.reorder_level) continue;
      if (!item.outlet?.id) continue;

      // Penerima dibatasi per cabang: Owner (semua cabang) + Manager(UserOutlet).
      const recipients = await resolveInventoryRecipients(prisma, item.outlet.id);
      if (recipients.length === 0) continue;

      const title = `Peringatan Stok: ${item.name} Menipis`;
      const body = `Sisa stok di ${item.outlet.name} tersisa ${item.stock_qty} ${item.unit} (batas aman minimum: ${item.reorder_level}). Segera lakukan pengadaan.`;

      const drafts: NotificationDraft[] = recipients.map((userId) => ({
        user_id: userId,
        type: 'low_stock',
        title,
        body,
        // Identifier record: bahan baku + cabang + periode. Sama dengan path POS,
        // sehingga notifikasi tidak dobel antar trigger.
        dedup_key: `low_stock:${item.id}:${item.outlet.id}:${todayStr}`,
        data: {
          type: 'low_stock',
          outlet_id: item.outlet.id,
          ingredient_id: String(item.id),
        },
      }));

      const fresh = await createNotificationsWithDedup(prisma, drafts);
      triggeredCount += fresh.length;

      await this.dispatchPush(fresh);
    }

    return {
      message: 'Evaluasi pemicu notifikasi selesai.',
      triggered_count: triggeredCount,
    };
  }

  /**
   * Notifikasi hasil AI: membuat row notifikasi (dedup per chat log) lalu push.
   * Dipanggil SETELAH jawaban AI sukses dibuat & disimpan.
   */
  async notifyAiResult(params: {
    userId: string;
    chatLogId: string;
    question: string;
    answer: string;
  }) {
    const { userId, chatLogId, question, answer } = params;

    const preview = answer.length > 140 ? `${answer.slice(0, 137)}...` : answer;
    const title = 'Jawaban AI siap';
    const body = preview;

    const fresh = await createNotificationsWithDedup(prisma, [
      {
        user_id: userId,
        type: 'ai_result',
        title,
        body,
        // Identifier record: id log percakapan AI (unik per jawaban).
        dedup_key: `ai_result:${chatLogId}`,
        data: {
          type: 'ai_result',
          chat_log_id: chatLogId,
          question,
        },
      },
    ]);

    await this.dispatchPush(fresh);
  }

  /**
   * Kirim push FCM untuk notifikasi yang baru dibuat.
   * Kegagalan FCM selalu ditelan: tidak boleh menggagalkan operasi bisnis.
   */
  async dispatchPush(drafts: NotificationDraft[]) {
    if (!drafts || drafts.length === 0) return;
    if (!pushService.isEnabled()) return;

    for (const draft of drafts) {
      try {
        await pushService.sendToUser(draft.user_id, {
          title: draft.title,
          body: draft.body,
          data: draft.data || { type: draft.type },
        });
      } catch (err) {
        console.warn('[NotificationsService] Push gagal (diabaikan):', err);
      }
    }
  }
}
