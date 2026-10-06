import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role, InsightSeverity, InsightStatus } from '@prisma/client';

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
      inventory: {
        findMany: vi.fn(),
        fields: {
          reorder_level: 'reorder_level',
        },
      },
      transactionItem: {
        count: vi.fn(),
      },
      businessInsight: {
        findFirst: vi.fn(),
        findUnique: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
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

  it('T-DS-01: Rule engine menghasilkan LOW_STOCK insight saat stok menipis', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);

    // Mock low stock
    vi.mocked(prisma.inventory.findMany).mockResolvedValueOnce([
      {
        outlet_id: 'out-1',
        product_id: 'prod-1',
        quantity: 2,
        reorder_level: 5,
        avg_lead_time_days: 2,
        product: { id: 'prod-1', name: 'Susu UHT', unit: 'liter', price_idr: 18000 },
        outlet: { id: 'out-1', name: 'Outlet Tebet' },
      },
    ] as any);

    // Mock slow moving (empty)
    vi.mocked(prisma.inventory.findMany).mockResolvedValueOnce([]);

    vi.mocked(prisma.businessInsight.findFirst).mockResolvedValue(null);
    vi.mocked(prisma.businessInsight.create).mockResolvedValue({ id: 'ins-1' } as any);

    const res = await request(app)
      .post('/api/insights/generate')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.evaluated_count).toBe(1);
    expect(res.body.data.new_insights_count).toBe(1);
    expect(prisma.businessInsight.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          rule_code: 'LOW_STOCK',
          severity: InsightSeverity.warning,
        }),
      })
    );
  });

  it('T-DS-02: Memperbarui status insight menjadi acknowledged', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);

    vi.mocked(prisma.businessInsight.findUnique).mockResolvedValue({
      id: 'ins-1',
      status: InsightStatus.new,
    } as any);

    vi.mocked(prisma.businessInsight.update).mockResolvedValue({
      id: 'ins-1',
      status: InsightStatus.acknowledged,
      outlet: { id: 'out-1', name: 'Outlet Tebet' },
      product: { id: 'prod-1', name: 'Susu UHT' },
    } as any);

    const res = await request(app)
      .patch('/api/insights/ins-1/status')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ status: 'acknowledged' });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('acknowledged');
  });
});
