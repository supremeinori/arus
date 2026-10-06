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
      },
      userOutlet: {
        findMany: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
      exchangeRate: {
        findMany: vi.fn(),
      },
    },
  };
});

describe('Currency & FX Module (Milestone 13)', () => {
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

  it('T-CUR-01: GET /api/fx/rates mengembalikan kurs IDR, USD, dan EUR', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    vi.mocked(prisma.exchangeRate.findMany).mockResolvedValue([
      { base: 'IDR', quote: 'USD', rate: 0.000062, as_of: new Date('2026-10-06') },
      { base: 'IDR', quote: 'EUR', rate: 0.000058, as_of: new Date('2026-10-06') },
    ] as any);

    const res = await request(app)
      .get('/api/fx/rates')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.rates.USD).toBe(0.000062);
    expect(res.body.data.rates.EUR).toBe(0.000058);
  });

  it('T-CUR-02: GET /api/fx/convert mengonversi IDR ke USD dengan akurat', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    vi.mocked(prisma.exchangeRate.findMany).mockResolvedValue([
      { base: 'IDR', quote: 'USD', rate: 0.000062, as_of: new Date('2026-10-06') },
    ] as any);

    const res = await request(app)
      .get('/api/fx/convert?amount=100000&from=IDR&to=USD')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.converted_amount).toBe(6.2); // 100,000 * 0.000062 = 6.2 USD
    expect(res.body.data.to_currency).toBe('USD');
  });
});
