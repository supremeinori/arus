import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role } from '@prisma/client';

// File terpisah: instance FxService di-cache 10 menit, jadi skenario
// "API kurs gagal" tidak boleh berbagi cache dengan skenario happy path.
vi.mock('../src/config/db', () => {
  return {
    prisma: {
      user: { findUnique: vi.fn() },
      userOutlet: { findMany: vi.fn() },
      outlet: { findMany: vi.fn() },
    },
  };
});

describe('FX fallback kurs', () => {
  const ownerToken = signAccessToken({
    sub: 'u-owner-1',
    email: 'owner@arus.demo',
    role: Role.owner,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.user.findUnique).mockResolvedValue({
      id: 'u-owner-1',
      role: Role.owner,
      is_active: true,
    } as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.stubGlobal('fetch', vi.fn(async () => {
      throw new Error('network down');
    }));
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('T-CUR-03: GET /api/fx/rates memakai fallback IDR-based bila API kurs gagal', async () => {
    const res = await request(app)
      .get('/api/fx/rates')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.base).toBe('IDR');
    expect(res.body.data.rates.IDR).toBe(1);
    expect(res.body.data.rates.USD).toBeGreaterThan(0);
    expect(res.body.data.rates.EUR).toBeGreaterThan(0);
  });
});
