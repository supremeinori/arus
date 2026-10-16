import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role, PaymentMethod, TxnStatus } from '@prisma/client';

vi.mock('../src/config/db', () => {
  return {
    prisma: {
      user: { findUnique: vi.fn(), findMany: vi.fn() },
      outlet: { findMany: vi.fn() },
      userOutlet: { findMany: vi.fn() },
      product: { findUnique: vi.fn(), findMany: vi.fn() },
      ingredient: { findUnique: vi.fn(), findMany: vi.fn(), update: vi.fn() },
      inventoryMovement: { create: vi.fn() },
      blockchainRecord: {
        findUnique: vi.fn().mockResolvedValue(null),
        findFirst: vi.fn().mockResolvedValue(null),
        create: vi.fn(),
      },
      $queryRaw: vi.fn().mockResolvedValue([]),
      $executeRaw: vi.fn().mockResolvedValue(0),
      notification: { create: vi.fn() },
      transaction: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        count: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
      },
      $transaction: vi.fn((callback) => {
        if (typeof callback === 'function') return callback(prisma);
        return Promise.all(callback);
      }),
    },
  };
});

describe('POS Endpoints (BAGIAN 1 spec)', () => {
  const mockStaff = { id: 'u-staff-1', email: 'staff@arus.demo', name: 'Siti', role: Role.staff, is_active: true };
  const mockOwner = { id: 'u-owner-1', email: 'owner@arus.demo', name: 'Rina', role: Role.owner, is_active: true };
  const staffToken = signAccessToken({ sub: mockStaff.id, email: mockStaff.email, role: mockStaff.role });
  const ownerToken = signAccessToken({ sub: mockOwner.id, email: mockOwner.email, role: mockOwner.role });
  const OUTLET = '00000000-0000-0000-0000-000000000001';

  beforeEach(() => vi.clearAllMocks());

  it('GET /api/pos/catalog mengembalikan is_available & max_portions', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: OUTLET }] as any);
    vi.mocked(prisma.product.findMany).mockResolvedValue([
      {
        id: 'prod-1', sku: 'KOP-01', name: 'Kopi Susu', price_idr: 20000,
        image_url: null, category_id: null, category: null,
        recipes: [
          { ingredient: { id: 'ing-1', outlet_id: OUTLET, name: 'Kopi', unit: 'gram', stock_qty: 100, cost_per_unit: 100 } , amount_needed: 20},
        ],
      },
      {
        id: 'prod-2', sku: 'KOP-02', name: 'Kopi Habis', price_idr: 20000,
        image_url: null, category_id: null, category: null,
        recipes: [
          { ingredient: { id: 'ing-1', outlet_id: OUTLET, name: 'Kopi', unit: 'gram', stock_qty: 5, cost_per_unit: 100 }, amount_needed: 20 },
        ],
      },
    ] as any);

    const res = await request(app).get(`/api/pos/catalog?outlet_id=${OUTLET}`).set('Authorization', `Bearer ${staffToken}`);
    expect(res.status).toBe(200);
    expect(res.body.data[0]).toMatchObject({ id: 'prod-1', is_available: true, max_portions: 5 });
    expect(res.body.data[1]).toMatchObject({ id: 'prod-2', is_available: false, max_portions: 0 });
  });

  it('POST /api/pos/checkout sukses (delegasi atomik) + stok kurang jadi 400', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: OUTLET }] as any);
    vi.mocked(prisma.transaction.findUnique).mockResolvedValue(null);
    vi.mocked(prisma.product.findUnique).mockResolvedValue({
      id: 'prod-1', name: 'Kopi Susu', price_idr: 20000, is_active: true,
      recipes: [{ ingredient_id: 'ing-1', amount_needed: 20, ingredient: { id: 'ing-1', outlet_id: OUTLET, cost_per_unit: 100 } }],
    } as any);
    vi.mocked(prisma.ingredient.findUnique).mockResolvedValue({ id: 'ing-1', outlet_id: OUTLET, name: 'Kopi', unit: 'gram', stock_qty: 100, reorder_level: 30 } as any);
    vi.mocked(prisma.transaction.create).mockResolvedValue({
      id: 'tx-1', receipt_no: 'INV-1', outlet_id: OUTLET, subtotal_idr: 40000, discount_idr: 0,
      total_idr: 40000, paid_idr: 50000, change_idr: 10000, status: TxnStatus.completed, created_at: new Date(), items: [],
    } as any);

    const ok = await request(app).post('/api/pos/checkout').set('Authorization', `Bearer ${staffToken}`).send({
      outlet_id: OUTLET, client_request_id: 'aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa',
      payment_method: PaymentMethod.cash, paid_idr: 50000, items: [{ product_id: 'prod-1', quantity: 2 }],
    });
    expect(ok.status).toBe(201);
    expect(ok.body.data.total_idr).toBe(40000);

    // stok kurang → 400 BAD_REQUEST (bukan 409)
    vi.mocked(prisma.ingredient.findUnique).mockResolvedValue({ id: 'ing-1', outlet_id: OUTLET, name: 'Kopi', unit: 'gram', stock_qty: 10, reorder_level: 30 } as any);
    const fail = await request(app).post('/api/pos/checkout').set('Authorization', `Bearer ${staffToken}`).send({
      outlet_id: OUTLET, client_request_id: 'bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb',
      payment_method: PaymentMethod.cash, paid_idr: 50000, items: [{ product_id: 'prod-1', quantity: 2 }],
    });
    expect(fail.status).toBe(400);
  });

  it('POST /api/pos/void: staff 403, owner sukses', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    const forbidden = await request(app).post('/api/pos/void').set('Authorization', `Bearer ${staffToken}`).send({ transaction_id: 'tx-1', reason: 'salah' });
    expect(forbidden.status).toBe(403);

    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.transaction.findUnique).mockResolvedValue({
      id: 'tx-1', receipt_no: 'INV-1', outlet_id: OUTLET, status: TxnStatus.completed,
      created_at: new Date(), total_idr: 40000, items: [{ product_id: 'prod-1', quantity: 1, product_name_snapshot: 'Kopi', unit_price_idr: 20000 }],
    } as any);
    vi.mocked(prisma.product.findUnique).mockResolvedValue({ id: 'prod-1', recipes: [{ ingredient_id: 'ing-1', amount_needed: 20 }] } as any);
    vi.mocked(prisma.ingredient.findUnique).mockResolvedValue({ id: 'ing-1', stock_qty: 80 } as any);
    vi.mocked(prisma.transaction.update).mockResolvedValue({ id: 'tx-1', status: TxnStatus.voided } as any);

    const res = await request(app).post('/api/pos/void').set('Authorization', `Bearer ${ownerToken}`).send({ transaction_id: 'tx-1', reason: 'batal' });
    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe(TxnStatus.voided);
  });
});
