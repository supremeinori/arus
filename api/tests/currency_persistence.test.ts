import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import * as tokens from '../src/shared/tokens';
import { Role } from '@prisma/client';

/**
 * Persistensi preferensi mata uang:
 * - login harus mengembalikan `display_currency` dari kolom User
 * - refresh harus mengembalikan user + settings (bukan cuma token), supaya
 *   frontend tidak kehilangan preferensi setiap kali token di-refresh
 */
vi.mock('../src/config/db', () => {
  return {
    prisma: {
      user: {
        findUnique: vi.fn(),
        update: vi.fn(),
      },
      refreshToken: {
        create: vi.fn(),
        findUnique: vi.fn(),
        update: vi.fn(),
        updateMany: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
      },
      $transaction: vi.fn((arg: any) => {
        if (typeof arg === 'function') return arg(prisma);
        return Promise.all(arg);
      }),
    },
  };
});

describe('Currency persistence di sesi auth', () => {
  const user = {
    id: 'u-currency-1',
    email: 'owner@arus.demo',
    name: 'Rina Owner',
    password_hash: '$argon2id$v=19$m=19456,t=2,p=1$fakehash',
    role: Role.owner,
    is_active: true,
    avatar_url: null,
    display_currency: 'SGD',
    outlets: [],
  };

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.refreshToken.create).mockResolvedValue({ id: 'rt-1' } as any);
    vi.mocked(prisma.refreshToken.update).mockResolvedValue({ id: 'rt-1' } as any);
  });

  it('T-CUR-AUTH-01: login mengembalikan display_currency dari kolom User', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(user as any);
    vi.spyOn(tokens, 'verifyPassword').mockResolvedValue(true);

    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'owner@arus.demo', password: 'password123' });

    expect(res.status).toBe(200);
    expect(res.body.data.user.settings.display_currency).toBe('SGD');
  });

  it('T-CUR-AUTH-02: refresh mengembalikan user + settings.display_currency', async () => {
    vi.mocked(prisma.refreshToken.findUnique).mockResolvedValue({
      id: 'rt-1',
      token_hash: 'hash',
      family_id: 'fam-1',
      expires_at: new Date(Date.now() + 60 * 60 * 1000),
      revoked_at: null,
      user_id: user.id,
      user: user,
    } as any);

    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refresh_token: 'raw-token' });

    expect(res.status).toBe(200);
    // user wajib ikut dikembalikan, kalau tidak preferensi hilang tiap refresh
    expect(res.body.data.user).toBeDefined();
    expect(res.body.data.user.id).toBe(user.id);
    expect(res.body.data.user.settings.display_currency).toBe('SGD');
    expect(res.body.data.settings.display_currency).toBe('SGD');
  });

  it('T-CUR-AUTH-03: refresh untuk user tanpa display_currency memakai default IDR', async () => {
    vi.mocked(prisma.refreshToken.findUnique).mockResolvedValue({
      id: 'rt-1',
      token_hash: 'hash',
      family_id: 'fam-1',
      expires_at: new Date(Date.now() + 60 * 60 * 1000),
      revoked_at: null,
      user_id: user.id,
      user: { ...user, display_currency: null },
    } as any);

    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refresh_token: 'raw-token' });

    expect(res.status).toBe(200);
    expect(res.body.data.user.settings.display_currency).toBe('IDR');
  });
});
