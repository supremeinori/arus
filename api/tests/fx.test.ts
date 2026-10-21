import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
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
    },
  };
});

// Payload Frankfurter (base EUR). ARUS menyimpan nominal dalam IDR, sehingga
// service wajib menormalkan kurs EUR -> IDR.
const frankfurterPayload = {
  amount: 1,
  base: 'EUR',
  date: '2026-10-20',
  rates: {
    IDR: 17885.0,
    USD: 1.0871,
    EUR: 1.0,
    SGD: 1.45,
    JPY: 170.5,
    MYR: 4.8,
    GBP: 0.835,
  },
};

describe('Currency & FX Module', () => {
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
    vi.stubGlobal('fetch', vi.fn(async () => ({
      ok: true,
      json: async () => frankfurterPayload,
    })));
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('T-CUR-01: GET /api/fx/rates menormalkan kurs live ke basis IDR', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const res = await request(app)
      .get('/api/fx/rates')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.base).toBe('IDR');
    expect(res.body.data.rates.IDR).toBe(1);
    // 1 USD = 1.0871 EUR, 1 EUR = 17885 IDR  =>  1 USD = 1.0871/17885 IDR
    expect(res.body.data.rates.USD).toBeCloseTo(1.0871 / 17885, 12);
    expect(res.body.data.rates.EUR).toBeCloseTo(1 / 17885, 12);
    expect(res.body.data.rates.USD).toBeLessThan(1);
  });

  it('T-CUR-02: GET /api/fx/convert mengonversi IDR ke USD dengan kurs valid', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const res = await request(app)
      .get('/api/fx/convert?amount=100000&from=IDR&to=USD')
      .set('Authorization', `Bearer ${ownerToken}`);

    const expected = 100000 * (1.0871 / 17885);
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.converted_amount).toBeCloseTo(Number(expected.toFixed(2)), 6);
    expect(res.body.data.from_currency).toBe('IDR');
    expect(res.body.data.to_currency).toBe('USD');
  });

});
