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
      transaction: {
        aggregate: vi.fn(),
        count: vi.fn(),
        findMany: vi.fn(),
      },
      transactionItem: {
        findMany: vi.fn(),
      },
    },
  };
});

describe('Analytics Module (Milestone 7)', () => {
  const mockOwner = {
    id: 'u-owner-1',
    email: 'owner@arus.demo',
    name: 'Rina Owner',
    role: Role.owner,
    is_active: true,
  };

  const mockStaff = {
    id: 'u-staff-1',
    email: 'staff@arus.demo',
    name: 'Siti Staff',
    role: Role.staff,
    is_active: true,
  };

  const ownerToken = signAccessToken({
    sub: mockOwner.id,
    email: mockOwner.email,
    role: mockOwner.role,
  });

  const staffToken = signAccessToken({
    sub: mockStaff.id,
    email: mockStaff.email,
    role: mockStaff.role,
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('T-ANA-01: Owner mendapatkan overview KPI lengkap dengan gross profit dan margin', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.transaction.aggregate).mockResolvedValue({
      _sum: { total_idr: 1000000, subtotal_idr: 1000000, discount_idr: 0 },
    } as any);
    vi.mocked(prisma.transaction.count).mockResolvedValue(25);
    vi.mocked(prisma.transactionItem.findMany).mockResolvedValue([
      { quantity: 25, unit_price_idr: 40000, unit_cost_idr: 15000, line_total_idr: 1000000 },
    ] as any);

    const res = await request(app)
      .get('/api/analytics/overview')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.revenue_idr).toBe(1000000);
    expect(res.body.data.transaction_count).toBe(25);
    expect(res.body.data.avg_basket_size_idr).toBe(40000);
    expect(res.body.data.gross_profit_idr).toBe(625000); // 1.000.000 - (25 * 15.000)
    expect(res.body.data.gross_margin_pct).toBe(63);
  });

  it('T-ANA-02: Staff mendapatkan overview KPI tanpa informasi gross profit dan margin', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: 'out-1' }] as any);
    vi.mocked(prisma.transaction.aggregate).mockResolvedValue({
      _sum: { total_idr: 500000, subtotal_idr: 500000, discount_idr: 0 },
    } as any);
    vi.mocked(prisma.transaction.count).mockResolvedValue(10);
    vi.mocked(prisma.transactionItem.findMany).mockResolvedValue([]);

    const res = await request(app)
      .get('/api/analytics/overview?outlet_id=out-1')
      .set('Authorization', `Bearer ${staffToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.revenue_idr).toBe(500000);
    expect(res.body.data).not.toHaveProperty('gross_profit_idr');
    expect(res.body.data).not.toHaveProperty('gross_margin_pct');
  });

  it('T-ANA-03: Mengambil tren penjualan harian', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.transaction.findMany).mockResolvedValue([
      { total_idr: 250000, created_at: new Date() },
    ] as any);

    const res = await request(app)
      .get('/api/analytics/sales-trend?days=7')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(7);
  });
});
