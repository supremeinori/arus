import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role, PaymentMethod, TxnStatus } from '@prisma/client';

vi.mock('../src/config/db', () => {
  return {
    prisma: {
      user: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
      },
      product: {
        findUnique: vi.fn(),
      },
      ingredient: {
        findUnique: vi.fn(),
        update: vi.fn(),
      },
      inventoryMovement: {
        create: vi.fn(),
      },
      blockchainRecord: {
        findFirst: vi.fn(),
        create: vi.fn(),
      },
      notification: {
        create: vi.fn(),
      },
      transaction: {
        findUnique: vi.fn(),
        findMany: vi.fn(),
        count: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
      },
      $transaction: vi.fn((callback) => {
        if (typeof callback === 'function') {
          return callback(prisma);
        }
        return Promise.all(callback);
      }),
    },
  };
});

describe('Transactions & POS Module (Milestone 6 / Modul 2)', () => {
  const mockStaff = {
    id: 'u-staff-1',
    email: 'staff@arus.demo',
    name: 'Siti Staff',
    role: Role.staff,
    is_active: true,
  };

  const mockOwner = {
    id: 'u-owner-1',
    email: 'owner@arus.demo',
    name: 'Rina Owner',
    role: Role.owner,
    is_active: true,
  };

  const staffToken = signAccessToken({
    sub: mockStaff.id,
    email: mockStaff.email,
    role: mockStaff.role,
  });

  const ownerToken = signAccessToken({
    sub: mockOwner.id,
    email: mockOwner.email,
    role: mockOwner.role,
  });

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('T-POS-01: Berhasil membuat transaksi tunai dan memotong stok bahan baku sesuai resep', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: '00000000-0000-0000-0000-000000000001' }] as any);
    vi.mocked(prisma.transaction.findUnique).mockResolvedValue(null);
    vi.mocked(prisma.product.findUnique).mockResolvedValue({
      id: 'prod-1',
      name: 'Kopi Susu',
      price_idr: 20000,
      is_active: true,
      recipes: [
        {
          ingredient_id: 'ing-1',
          amount_needed: 20,
          ingredient: {
            id: 'ing-1',
            outlet_id: '00000000-0000-0000-0000-000000000001',
            cost_per_unit: 100,
          },
        },
      ],
    } as any);

    vi.mocked(prisma.ingredient.findUnique).mockResolvedValue({
      id: 'ing-1',
      outlet_id: '00000000-0000-0000-0000-000000000001',
      name: 'Biji Kopi Arabika',
      unit: 'gram',
      stock_qty: 100,
      reorder_level: 30,
    } as any);

    vi.mocked(prisma.blockchainRecord.findFirst).mockResolvedValue(null);
    vi.mocked(prisma.blockchainRecord.create).mockResolvedValue({} as any);

    vi.mocked(prisma.transaction.create).mockResolvedValue({
      id: 'tx-1',
      receipt_no: 'INV-20261006-1234',
      outlet_id: '00000000-0000-0000-0000-000000000001',
      cashier_id: mockStaff.id,
      subtotal_idr: 40000,
      discount_idr: 0,
      total_idr: 40000,
      paid_idr: 50000,
      change_idr: 10000,
      status: TxnStatus.completed,
      created_at: new Date(),
      items: [
        {
          product_id: 'prod-1',
          product_name_snapshot: 'Kopi Susu',
          unit_price_idr: 20000,
          quantity: 2,
          line_total_idr: 40000,
        },
      ],
    } as any);

    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({
        client_request_id: '7b7074e4-a145-427f-a65c-6119f8638b93',
        outlet_id: '00000000-0000-0000-0000-000000000001',
        payment_method: PaymentMethod.cash,
        paid_idr: 50000,
        items: [{ product_id: 'prod-1', quantity: 2 }],
      });

    expect(res.status).toBe(201);
    expect(res.body.data.total_idr).toBe(40000);
    expect(res.body.data.change_idr).toBe(10000);
    // Verifikasi pemotongan stok bahan baku: 100 - (20 * 2) = 60
    expect(prisma.ingredient.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'ing-1' },
        data: { stock_qty: 60 },
      })
    );
  });

  it('T-POS-02: Menolak checkout jika uang tunai kurang (PAYMENT_INSUFFICIENT)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: '00000000-0000-0000-0000-000000000001' }] as any);
    vi.mocked(prisma.transaction.findUnique).mockResolvedValue(null);
    vi.mocked(prisma.product.findUnique).mockResolvedValue({
      id: 'prod-1',
      name: 'Kopi Susu',
      price_idr: 20000,
      is_active: true,
      recipes: [
        {
          ingredient_id: 'ing-1',
          amount_needed: 20,
          ingredient: {
            id: 'ing-1',
            outlet_id: '00000000-0000-0000-0000-000000000001',
            cost_per_unit: 100,
          },
        },
      ],
    } as any);
    vi.mocked(prisma.ingredient.findUnique).mockResolvedValue({
      id: 'ing-1',
      outlet_id: '00000000-0000-0000-0000-000000000001',
      name: 'Biji Kopi Arabika',
      unit: 'gram',
      stock_qty: 100,
      reorder_level: 30,
    } as any);

    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({
        client_request_id: '8b7074e4-a145-427f-a65c-6119f8638b94',
        outlet_id: '00000000-0000-0000-0000-000000000001',
        payment_method: PaymentMethod.cash,
        paid_idr: 10000, // Total 20.000, dibayar hanya 10.000
        items: [{ product_id: 'prod-1', quantity: 1 }],
      });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('PAYMENT_INSUFFICIENT');
  });

  it('T-POS-03: Staff dilarang melakukan void transaksi (403 FORBIDDEN)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);

    const res = await request(app)
      .post('/api/transactions/tx-1/void')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({ reason: 'Salah input menu' });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });

  it('T-POS-04: Owner berhasil melakukan void transaksi dan mengembalikan stok bahan baku', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);

    vi.mocked(prisma.transaction.findUnique).mockResolvedValue({
      id: 'tx-1',
      receipt_no: 'INV-20261006-1234',
      outlet_id: '00000000-0000-0000-0000-000000000001',
      status: TxnStatus.completed,
      created_at: new Date(),
      items: [{ product_id: 'prod-1', quantity: 2 }],
    } as any);

    vi.mocked(prisma.product.findUnique).mockResolvedValue({
      id: 'prod-1',
      recipes: [
        {
          ingredient_id: 'ing-1',
          amount_needed: 20,
        },
      ],
    } as any);

    vi.mocked(prisma.ingredient.findUnique).mockResolvedValue({
      id: 'ing-1',
      outlet_id: '00000000-0000-0000-0000-000000000001',
      stock_qty: 60,
    } as any);

    vi.mocked(prisma.transaction.update).mockResolvedValue({
      id: 'tx-1',
      status: TxnStatus.voided,
    } as any);

    const res = await request(app)
      .post('/api/transactions/tx-1/void')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ reason: 'Pelanggan membatalkan pesanan' });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe(TxnStatus.voided);
    // Verifikasi stok dikembalikan dari 60 -> 100 (60 + 20*2)
    expect(prisma.ingredient.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { id: 'ing-1' },
        data: { stock_qty: 100 },
      })
    );
  });
});
