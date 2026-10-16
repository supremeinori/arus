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
      outlet: {
        findMany: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
      },
      ingredient: {
        findMany: vi.fn(),
      },
      product: {
        findMany: vi.fn(),
      },
      transactionItem: {
        count: vi.fn(),
      },
    },
  };
});

describe('Insights & Decision Support Module (Milestone 8)', () => {
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
  });

  it('T-DS-01: Rule engine menghasilkan LOW_STOCK insight saat stok bahan baku menipis', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([{ id: 'out-1' }] as any);

    // Mock low stock ingredient
    vi.mocked(prisma.ingredient.findMany).mockResolvedValue([
      {
        id: 'ing-1',
        outlet_id: 'out-1',
        name: 'Susu UHT Fresh',
        unit: 'liter',
        stock_qty: 2,
        reorder_level: 5,
        outlet: { id: 'out-1', name: 'Outlet Tebet' },
      },
    ] as any);

    vi.mocked(prisma.product.findMany).mockResolvedValue([]);

    const res = await request(app)
      .post('/api/insights/generate')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.evaluated_count).toBe(1);
    expect(res.body.data.insights[0].rule_code).toBe('LOW_STOCK');
    expect(res.body.data.insights[0].severity).toBe('warning');
  });

  it('T-DS-02: Memperbarui status insight menjadi acknowledged', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([{ id: 'out-1' }] as any);

    const res = await request(app)
      .patch('/api/insights/ins-1/status')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ status: 'acknowledged' });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('acknowledged');
  });
});
