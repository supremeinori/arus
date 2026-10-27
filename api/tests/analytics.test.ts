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

  const mockManager = {
    id: 'u-mgr-1',
    email: 'manager@arus.demo',
    name: 'Doni Manager',
    role: Role.manager,
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

  const managerToken = signAccessToken({
    sub: mockManager.id,
    email: mockManager.email,
    role: mockManager.role,
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

  it('T-ANA-04: Manager terkunci pada outlet yang di-assign dan ditolak jika mengakses outlet lain', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockManager as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: 'out-mgr' }] as any);

    // 1. Ditolak jika mencoba mengakses outlet yang bukan miliknya
    const resForbidden = await request(app)
      .get('/api/analytics/overview?outlet_id=out-other')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(resForbidden.status).toBe(403);

    // 2. Berhasil jika mengakses outlet yang di-assign oleh owner, dan tetap mendapatkan kalkulasi laba/margin
    vi.mocked(prisma.transaction.aggregate).mockResolvedValue({
      _sum: { total_idr: 800000, subtotal_idr: 800000, discount_idr: 0 },
    } as any);
    vi.mocked(prisma.transaction.count).mockResolvedValue(15);
    vi.mocked(prisma.transactionItem.findMany).mockResolvedValue([
      { quantity: 15, unit_price_idr: 53333, unit_cost_idr: 20000, line_total_idr: 800000 },
    ] as any);

    const resAllowed = await request(app)
      .get('/api/analytics/overview?outlet_id=out-mgr')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(resAllowed.status).toBe(200);
    expect(resAllowed.body.data.revenue_idr).toBe(800000);
    expect(resAllowed.body.data).toHaveProperty('gross_profit_idr');
  });

  it('T-ANA-05: Mengambil tren penjualan dengan filter from dan to rentang tanggal kustom', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.transaction.findMany).mockResolvedValue([
      { total_idr: 150000, created_at: new Date('2026-10-02T10:00:00.000Z') },
    ] as any);

    const res = await request(app)
      .get('/api/analytics/sales-trend?from=2026-10-01&to=2026-10-03')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(3);
    expect(res.body.data[0]).toEqual({ date: '2026-10-01', revenue_idr: 0, count: 0 });
    expect(res.body.data[1]).toEqual({ date: '2026-10-02', revenue_idr: 150000, count: 1 });
    expect(res.body.data[2]).toEqual({ date: '2026-10-03', revenue_idr: 0, count: 0 });
  });

  it('T-ANA-06: Manager ditolak dengan 403 jika mengakses tren penjualan outlet di luar wewenangnya', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockManager as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: 'out-mgr' }] as any);

    const res = await request(app)
      .get('/api/analytics/sales-trend?outlet_id=out-forbidden')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(403);
  });
});
