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
        count: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
      userSettings: {
        findUnique: vi.fn(),
        create: vi.fn(),
        upsert: vi.fn(),
      },
    },
  };
});

describe('User Settings & Sensor Preferences (Milestone 14)', () => {
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

  it('T-SENS-01: GET /api/users/me/settings mengembalikan preferensi pengguna', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userSettings.findUnique).mockResolvedValue({
      user_id: mockOwner.id,
      display_currency: 'IDR',
      display_timezone: 'Asia/Jakarta',
      biometric_enabled: true,
      shake_refresh_enabled: true,
      tilt_enabled: false,
      daily_revenue_target_idr: 5000000,
      notif_prefs: null,
      updated_at: new Date(),
    } as any);

    const res = await request(app)
      .get('/api/users/me/settings')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.biometric_enabled).toBe(true);
    expect(res.body.data.tilt_enabled).toBe(false);
  });

  it('T-SENS-02: PATCH /api/users/me/settings memperbarui preferensi biometrik & sensor', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userSettings.upsert).mockResolvedValue({
      user_id: mockOwner.id,
      display_currency: 'USD',
      display_timezone: 'Asia/Makassar',
      biometric_enabled: true,
      shake_refresh_enabled: false,
      tilt_enabled: true,
      daily_revenue_target_idr: null,
      notif_prefs: null,
      updated_at: new Date(),
    } as any);

    const res = await request(app)
      .patch('/api/users/me/settings')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        biometric_enabled: true,
        shake_refresh_enabled: false,
        tilt_enabled: true,
        display_currency: 'USD',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.biometric_enabled).toBe(true);
    expect(res.body.data.shake_refresh_enabled).toBe(false);
    expect(res.body.data.display_currency).toBe('USD');
  });

  it('T-SENS-03: PATCH /api/users/me/settings menolak mata uang yang tidak valid', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const res = await request(app)
      .patch('/api/users/me/settings')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        display_currency: 'INVALID_CURRENCY',
      });

    expect(res.status).toBe(400);
  });
});
