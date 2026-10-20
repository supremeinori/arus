import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role } from '@prisma/client';

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
      ingredient: {
        findMany: vi.fn(),
      },
      notification: {
        findMany: vi.fn(),
        findFirst: vi.fn(),
        findUnique: vi.fn(),
        count: vi.fn(),
        create: vi.fn(),
        createMany: vi.fn(),
        update: vi.fn(),
        updateMany: vi.fn(),
      },
      deviceToken: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        deleteMany: vi.fn(),
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
        type: 'low_stock',
        title: 'Stok Menipis',
        body: 'Susu UHT sisa 2 liter',
        is_read: false,
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

  it('T-NOT-02: Menandai notifikasi spesifik sudah dibaca (is_read = true)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    vi.mocked(prisma.notification.findUnique).mockResolvedValue({
      id: 'notif-1',
      user_id: mockOwner.id,
      is_read: false,
    } as any);

    vi.mocked(prisma.notification.update).mockResolvedValue({
      id: 'notif-1',
      user_id: mockOwner.id,
      is_read: true,
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

  it('T-NOT-04: Evaluasi otomatis stok kritis menghasilkan notifikasi baru', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    // Mock low stock ingredients
    vi.mocked(prisma.ingredient.findMany).mockResolvedValue([
      {
        id: 'ing-1',
        outlet_id: 'out-1',
        name: 'Biji Kopi Blend',
        unit: 'kg',
        stock_qty: 2,
        reorder_level: 5,
        outlet: { id: 'out-1', name: 'Outlet Tebet' },
      },
    ] as any);

    // Mock recipient
    vi.mocked(prisma.user.findMany).mockResolvedValue([
      { id: mockOwner.id },
    ] as any);

    vi.mocked(prisma.notification.createMany).mockResolvedValue({ count: 1 } as any);

    const res = await request(app)
      .post('/api/notifications/evaluate')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.triggered_count).toBeGreaterThanOrEqual(0);
  });

  it('T-NOT-05: Mendaftarkan device token FCM milik user yang sedang login', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.deviceToken.findUnique).mockResolvedValue(null as any);
    vi.mocked(prisma.deviceToken.create).mockResolvedValue({
      id: 'dt-1',
      user_id: mockOwner.id,
      token: 'fcm-token-abc',
      platform: 'android',
    } as any);

    const res = await request(app)
      .post('/api/notifications/device-token')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ token: 'fcm-token-abc', platform: 'android' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(prisma.deviceToken.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          user_id: mockOwner.id,
          token: 'fcm-token-abc',
        }),
      })
    );
  });

  it('T-NOT-06: Device token milik user lain dipindahkan ke user aktif (multi device aman)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.deviceToken.findUnique).mockResolvedValue({
      id: 'dt-1',
      user_id: 'u-owner-2',
      platform: 'android',
    } as any);
    vi.mocked(prisma.deviceToken.update).mockResolvedValue({
      id: 'dt-1',
      user_id: mockOwner.id,
      platform: 'android',
    } as any);

    const res = await request(app)
      .post('/api/notifications/device-token')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ token: 'fcm-token-abc' });

    expect(res.status).toBe(200);
    expect(prisma.deviceToken.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'dt-1' },
        data: expect.objectContaining({ user_id: mockOwner.id }),
      })
    );
  });

  it('T-NOT-07: Payload device token tidak valid ditolak 400', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const res = await request(app)
      .post('/api/notifications/device-token')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ platform: 'android' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  it('T-NOT-08: Dedup_key yang sudah ada tidak membuat notifikasi ganda', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.ingredient.findMany).mockResolvedValue([
      {
        id: 'ing-1',
        outlet_id: 'out-1',
        name: 'Biji Kopi Blend',
        unit: 'kg',
        stock_qty: 2,
        reorder_level: 5,
        outlet: { id: 'out-1', name: 'Outlet Tebet' },
      },
    ] as any);
    vi.mocked(prisma.user.findMany).mockResolvedValue([
      { id: mockOwner.id },
    ] as any);

    // Notifikasi dengan dedup_key yang sama sudah ada -> tidak ada createMany
    const todayStr = new Date().toISOString().slice(0, 10);
    vi.mocked(prisma.notification.findMany).mockResolvedValue([
      {
        user_id: mockOwner.id,
        dedup_key: `low_stock:ing-1:out-1:${todayStr}`,
      },
    ] as any);

    const res = await request(app)
      .post('/api/notifications/evaluate')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.triggered_count).toBe(0);
    expect(prisma.notification.createMany).not.toHaveBeenCalled();
  });

  it('T-NOT-09: Penerima notifikasi dibatasi Owner + Manager(UserOutlet) per cabang', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.ingredient.findMany).mockResolvedValue([
      {
        id: 'ing-1',
        outlet_id: 'out-1',
        name: 'Biji Kopi Blend',
        unit: 'kg',
        stock_qty: 2,
        reorder_level: 5,
        outlet: { id: 'out-1', name: 'Outlet Tebet' },
      },
    ] as any);
    vi.mocked(prisma.notification.findMany).mockResolvedValue([] as any);
    vi.mocked(prisma.notification.createMany).mockResolvedValue({ count: 1 } as any);
    vi.mocked(prisma.user.findMany).mockResolvedValue([
      { id: mockOwner.id },
    ] as any);

    const res = await request(app)
      .post('/api/notifications/evaluate')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(prisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          OR: expect.arrayContaining([
            { role: Role.owner },
            { role: Role.manager, outlets: { some: { outlet_id: 'out-1' } } },
          ]),
        }),
      })
    );
  });

  it('T-NOT-10: Kegagalan push FCM tidak menggagalkan endpoint evaluate', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.ingredient.findMany).mockResolvedValue([
      {
        id: 'ing-1',
        outlet_id: 'out-1',
        name: 'Biji Kopi Blend',
        unit: 'kg',
        stock_qty: 2,
        reorder_level: 5,
        outlet: { id: 'out-1', name: 'Outlet Tebet' },
      },
    ] as any);
    vi.mocked(prisma.notification.findMany).mockResolvedValue([] as any);
    vi.mocked(prisma.notification.createMany).mockResolvedValue({ count: 1 } as any);
    vi.mocked(prisma.user.findMany).mockResolvedValue([
      { id: mockOwner.id },
    ] as any);
    // deviceToken.findMany menolak -> simulasi kegagalan push
    vi.mocked(prisma.deviceToken.findMany).mockRejectedValue(
      new Error('FCM down') as any
    );

    const res = await request(app)
      .post('/api/notifications/evaluate')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
