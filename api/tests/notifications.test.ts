import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role, NotificationType, NotificationPriority } from '@prisma/client';

vi.mock('../src/config/db', () => {
  return {
    prisma: {
      user: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
      inventory: {
        findMany: vi.fn(),
        fields: {
          reorder_level: 'reorder_level',
        },
      },
      notification: {
        findMany: vi.fn(),
        findFirst: vi.fn(),
        findUnique: vi.fn(),
        count: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        updateMany: vi.fn(),
      },
    },
  };
});

describe('Notifications Module (Milestone 12)', () => {
  const mockOwner = {
    id: 'u-owner-1',
    email: 'owner@arus.demo',
    name: 'Rina Owner',
    role: Role.owner,
    is_active: true,
  };

  const ownerToken = signAccessToken({
    sub: mockOwner.id,
    email: mockOwner.email,
    role: mockOwner.role,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
  });

  it('T-NOT-01: Mengambil daftar notifikasi pengguna dan menghitung unread_count', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const mockNotifs = [
      {
        id: 'notif-1',
        user_id: mockOwner.id,
        type: NotificationType.low_stock,
        priority: NotificationPriority.high,
        title: 'Stok Menipis',
        body: 'Susu UHT sisa 2 liter',
        read_at: null,
        created_at: new Date(),
      },
    ];

    vi.mocked(prisma.notification.findMany).mockResolvedValue(mockNotifs as any);
    vi.mocked(prisma.notification.count).mockResolvedValue(1);

    const res = await request(app)
      .get('/api/notifications')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.unread_count).toBe(1);
    expect(res.body.data.notifications).toHaveLength(1);
  });

  it('T-NOT-02: Menandai notifikasi spesifik sudah dibaca (read_at terisi)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    vi.mocked(prisma.notification.findUnique).mockResolvedValue({
      id: 'notif-1',
      user_id: mockOwner.id,
      read_at: null,
    } as any);

    vi.mocked(prisma.notification.update).mockResolvedValue({
      id: 'notif-1',
      user_id: mockOwner.id,
      read_at: new Date(),
    } as any);

    const res = await request(app)
      .patch('/api/notifications/notif-1/read')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(prisma.notification.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'notif-1' },
      })
    );
  });

  it('T-NOT-03: Menandai seluruh notifikasi belum dibaca menjadi dibaca sekaligus (read-all)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    vi.mocked(prisma.notification.updateMany).mockResolvedValue({
      count: 4,
    } as any);

    const res = await request(app)
      .post('/api/notifications/read-all')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.affected_count).toBe(4);
  });

  it('T-NOT-04: Evaluasi otomatis stok kritis menghasilkan notifikasi baru dengan dedup key', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    // Mock low stock inventory
    vi.mocked(prisma.inventory.findMany).mockResolvedValue([
      {
        outlet_id: 'out-1',
        product_id: 'prod-1',
        quantity: 2,
        reorder_level: 5,
        product: { name: 'Kopi Blend', sku: 'KOP-01', unit: 'kg' },
        outlet: { name: 'Outlet Tebet' },
      },
    ] as any);

    // Mock recipient
    vi.mocked(prisma.user.findMany).mockResolvedValue([
      { id: mockOwner.id },
    ] as any);

    // Belum pernah dibuat (dedup key tidak ada)
    vi.mocked(prisma.notification.findFirst).mockResolvedValue(null);
    vi.mocked(prisma.notification.create).mockResolvedValue({ id: 'notif-new' } as any);

    const res = await request(app)
      .post('/api/notifications/evaluate')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.triggered_count).toBe(1);
    expect(prisma.notification.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          type: NotificationType.low_stock,
          priority: NotificationPriority.high,
          user_id: mockOwner.id,
        }),
      })
    );
  });
});
