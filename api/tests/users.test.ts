import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { usersService } from '../src/modules/users/users.service';
import { signAccessToken } from '../src/shared/jwt';
import { Role } from '@prisma/client';

vi.mock('../src/config/db', () => {
  return {
    prisma: {
      user: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        count: vi.fn(),
        update: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
    },
  };
});

describe('User Settings & Display Currency', () => {
  const mockOwner = {
    id: 'u-owner-1',
    email: 'owner@arus.demo',
    name: 'Rina Owner',
    role: Role.owner,
    is_active: true,
    display_currency: 'IDR',
  };

  const ownerToken = signAccessToken({
    sub: mockOwner.id,
    email: mockOwner.email,
    role: mockOwner.role,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    // Reset cache in-memory service agar antar test tidak saling memengaruhi
    (usersService as any).inMemorySettings = {};
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
  });

  it('T-SENS-01: GET /api/users/me/settings membaca display_currency dari kolom User', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      ...mockOwner,
      display_currency: 'USD',
    } as any);

    const res = await request(app)
      .get('/api/users/me/settings')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.display_currency).toBe('USD');
  });

  it('T-SENS-01b: GET /api/users/me/settings default ke IDR bila kolom kosong', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      ...mockOwner,
      display_currency: null,
    } as any);

    const res = await request(app)
      .get('/api/users/me/settings')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.display_currency).toBe('IDR');
  });

  it('T-SENS-02: PATCH /api/users/me/settings menyimpan display_currency ke kolom User.display_currency', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.user.update).mockResolvedValue({
      ...mockOwner,
      display_currency: 'USD',
    } as any);

    const res = await request(app)
      .patch('/api/users/me/settings')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        display_currency: 'USD',
        biometric_enabled: true,
        shake_refresh_enabled: false,
        tilt_enabled: true,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.display_currency).toBe('USD');

    // Persistensi harus benar-benar terjadi di kolom User.display_currency
    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: mockOwner.id },
      data: { display_currency: 'USD' },
    });
  });

  it('T-SENS-02b: PATCH tanpa display_currency tidak menulis kolom mata uang', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const res = await request(app)
      .patch('/api/users/me/settings')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ shake_refresh_enabled: false });

    expect(res.status).toBe(200);
    expect(prisma.user.update).not.toHaveBeenCalled();
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
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('T-SENS-04: dua akun punya preferensi mata uang yang terpisah', async () => {
    const otherToken = signAccessToken({
      sub: 'u-staff-2',
      email: 'staff@arus.demo',
      role: Role.staff,
    });

    vi.mocked(prisma.user.findUnique).mockImplementation((args: any) => {
      if (args?.where?.id === 'u-staff-2') {
        return Promise.resolve({
          id: 'u-staff-2',
          email: 'staff@arus.demo',
          name: 'Siti Staff',
          role: Role.staff,
          is_active: true,
          display_currency: 'EUR',
        } as any);
      }
      return Promise.resolve({ ...mockOwner, display_currency: 'USD' } as any);
    });
    vi.mocked(prisma.user.update).mockImplementation((args: any) =>
      Promise.resolve({ id: args.where.id, ...args.data } as any),
    );

    const resOwner = await request(app)
      .get('/api/users/me/settings')
      .set('Authorization', `Bearer ${ownerToken}`);
    const resStaff = await request(app)
      .get('/api/users/me/settings')
      .set('Authorization', `Bearer ${otherToken}`);

    expect(resOwner.body.data.display_currency).toBe('USD');
    expect(resStaff.body.data.display_currency).toBe('EUR');
  });
});
