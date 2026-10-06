import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role, ReportType, TransactionStatus } from '@prisma/client';
import { computePayloadHash } from '../src/modules/reports/reports.service';

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
        findMany: vi.fn(),
      },
      inventory: {
        findMany: vi.fn(),
      },
      report: {
        create: vi.fn(),
        findMany: vi.fn(),
        findUnique: vi.fn(),
      },
      blockchainRecord: {
        findFirst: vi.fn(),
        create: vi.fn(),
      },
      $transaction: vi.fn((callback) => callback(prisma)),
    },
  };
});

describe('Reports & Tamper-evident Ledger Module (Milestone 10)', () => {
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
    name: 'Budi Kasir',
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
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
  });

  it('T-REP-01: Owner berhasil men-generate sales_summary report dengan SHA-256 payload hash & blockchain anchor', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([
      { id: '11111111-1111-1111-1111-111111111111', name: 'Outlet Tebet', is_active: true },
    ] as any);

    // Mock transactions data
    vi.mocked(prisma.transaction.findMany).mockResolvedValue([
      {
        id: 'tx-1',
        total_idr: 100000,
        discount_idr: 5000,
        payment_method: 'qris',
        status: TransactionStatus.completed,
        created_at: new Date('2026-10-01T10:00:00Z'),
        items: [
          {
            product_id: 'p-1',
            quantity: 2,
            subtotal_idr: 105000,
            cost_at_sale_idr: 25000,
            product: { name: 'Kopi Susu Senja', cost_idr: 25000 },
          },
        ],
      },
    ] as any);

    // Mock report create
    vi.mocked(prisma.report.create).mockImplementation(async ({ data }: any) => {
      return {
        id: 'rep-uuid-1',
        ...data,
        creator: { id: mockOwner.id, name: mockOwner.name, email: mockOwner.email, role: mockOwner.role },
      };
    });

    vi.mocked(prisma.blockchainRecord.findFirst).mockResolvedValue(null);
    vi.mocked(prisma.blockchainRecord.create).mockResolvedValue({} as any);

    const res = await request(app)
      .post('/api/reports')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        type: 'sales_summary',
        title: 'Laporan Penjualan Awal Bulan',
        period_from: '2026-10-01',
        period_to: '2026-10-07',
        outlet_ids: ['11111111-1111-1111-1111-111111111111'],
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.id).toBe('rep-uuid-1');
    expect(res.body.data.payload_hash).toHaveLength(64); // SHA-256 hex string
    expect(res.body.data.blockchain.block_index).toBe(1);
    expect(res.body.data.payload.summary.total_revenue_idr).toBe(100000);
    expect(res.body.data.payload.summary.net_margin_idr).toBe(50000); // 100k - (2 * 25k)
  });

  it('T-REP-02: Role staff ditolak (403 Forbidden) saat mencoba generate laporan', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);

    const res = await request(app)
      .post('/api/reports')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({
        type: 'sales_summary',
        period_from: '2026-10-01',
        period_to: '2026-10-07',
      });

    expect(res.status).toBe(403);
    expect(prisma.report.create).not.toHaveBeenCalled();
  });

  it('T-REP-03: Mengambil detail laporan dan memverifikasi integritas hash snapshot (is_valid = true)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const validPayload = {
      summary: { total_revenue_idr: 500000, transaction_count: 10 },
      top_items: [{ name: 'Kopi Susu', revenue: 200000 }],
    };
    const validHash = computePayloadHash(validPayload);

    vi.mocked(prisma.report.findUnique).mockResolvedValue({
      id: 'rep-uuid-1',
      type: ReportType.sales_summary,
      title: 'Laporan Valid',
      payload: validPayload,
      payload_hash: validHash,
      creator: { id: mockOwner.id, name: mockOwner.name, email: mockOwner.email, role: mockOwner.role },
      blockchain_records: [
        {
          block_index: 1n,
          block_hash: 'abc123hash',
        },
      ],
    } as any);

    const res = await request(app)
      .get('/api/reports/rep-uuid-1')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.verification.is_valid).toBe(true);
    expect(res.body.data.verification.stored_hash).toBe(validHash);
    expect(res.body.data.verification.computed_hash).toBe(validHash);
    expect(res.body.data.verification.blockchain_anchored).toBe(true);
  });

  it('T-REP-04: Mendeteksi jika payload database telah di-tamper / dimanipulasi (is_valid = false)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const originalPayload = { summary: { total_revenue_idr: 500000 } };
    const originalHash = computePayloadHash(originalPayload);

    // Payload yang sudah diubah diam-diam oleh pihak tidak sah
    const tamperedPayload = { summary: { total_revenue_idr: 9999999 } };

    vi.mocked(prisma.report.findUnique).mockResolvedValue({
      id: 'rep-uuid-tampered',
      type: ReportType.sales_summary,
      title: 'Laporan Tampered',
      payload: tamperedPayload,
      payload_hash: originalHash,
      creator: { id: mockOwner.id, name: mockOwner.name, email: mockOwner.email, role: mockOwner.role },
      blockchain_records: [],
    } as any);

    const res = await request(app)
      .get('/api/reports/rep-uuid-tampered')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.verification.is_valid).toBe(false);
    expect(res.body.data.verification.computed_hash).not.toBe(originalHash);
  });

  it('T-REP-05: Verifikasi independen melalui endpoint POST /api/reports/:id/verify', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const payload = { summary: { total_skus: 15, low_stock_count: 2 } };
    const hash = computePayloadHash(payload);

    vi.mocked(prisma.report.findUnique).mockResolvedValue({
      id: 'rep-uuid-2',
      title: 'Status Inventaris',
      payload,
      payload_hash: hash,
    } as any);

    const res = await request(app)
      .post('/api/reports/rep-uuid-2/verify')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.is_valid).toBe(true);
    expect(res.body.data.message).toContain('Integritas laporan terverifikasi valid');
  });
});
