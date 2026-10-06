import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role, PaymentMethod, TransactionStatus } from '@prisma/client';

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
      product: {
        findUnique: vi.fn(),
      },
      inventory: {
        findUnique: vi.fn(),
        update: vi.fn(),
      },
      inventoryMovement: {
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

describe('Transactions & POS Module (Milestone 6)', () => {
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

  it('T-POS-01: Berhasil membuat transaksi tunai dan memotong stok', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: 'out-1' }] as any);
    vi.mocked(prisma.transaction.findUnique).mockResolvedValue(null); // Idempotency check: belum ada
    vi.mocked(prisma.product.findUnique).mockResolvedValue({
      id: 'prod-1',
      name: 'Kopi Susu',
      price_idr: 20000,
      cost_idr: 8000,
      is_active: true,
    } as any);
    vi.mocked(prisma.inventory.findUnique).mockResolvedValue({
      outlet_id: 'out-1',
      product_id: 'prod-1',
      quantity: 10,
    } as any);

    vi.mocked(prisma.transaction.create).mockResolvedValue({
      id: 'tx-1',
      receipt_no: 'INV-20261006-1234',
      outlet_id: 'out-1',
      cashier_id: mockStaff.id,
      subtotal_idr: 40000,
      discount_idr: 0,
      total_idr: 40000,
      paid_idr: 50000,
      change_idr: 10000,
      status: TransactionStatus.completed,
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
        outlet_id: 'out-1',
        payment_method: PaymentMethod.cash,
        paid_idr: 50000,
        items: [{ product_id: 'prod-1', quantity: 2 }],
      });

    expect(res.status).toBe(201);
    expect(res.body.data.total_idr).toBe(40000);
    expect(res.body.data.change_idr).toBe(10000);
    expect(prisma.inventory.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { quantity: 8 },
      })
    );
  });

  it('T-POS-02: Menolak checkout jika uang tunai kurang (PAYMENT_INSUFFICIENT)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([{ outlet_id: 'out-1' }] as any);
    vi.mocked(prisma.transaction.findUnique).mockResolvedValue(null);
    vi.mocked(prisma.product.findUnique).mockResolvedValue({
      id: 'prod-1',
      name: 'Kopi Susu',
      price_idr: 20000,
      cost_idr: 8000,
      is_active: true,
    } as any);
    vi.mocked(prisma.inventory.findUnique).mockResolvedValue({
      outlet_id: 'out-1',
      product_id: 'prod-1',
      quantity: 10,
    } as any);

    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({
        client_request_id: '8b7074e4-a145-427f-a65c-6119f8638b94',
        outlet_id: 'out-1',
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

  it('T-POS-04: Owner berhasil melakukan void transaksi dan mengembalikan stok', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);

    vi.mocked(prisma.transaction.findUnique).mockResolvedValue({
      id: 'tx-1',
      receipt_no: 'INV-20261006-1234',
      outlet_id: 'out-1',
      status: TransactionStatus.completed,
      items: [{ product_id: 'prod-1', quantity: 2 }],
    } as any);

    vi.mocked(prisma.inventory.findUnique).mockResolvedValue({
      outlet_id: 'out-1',
      product_id: 'prod-1',
      quantity: 8,
    } as any);

    vi.mocked(prisma.transaction.update).mockResolvedValue({
      id: 'tx-1',
      status: TransactionStatus.voided,
      void_reason: 'Pelanggan membatalkan pesanan',
    } as any);

    const res = await request(app)
      .post('/api/transactions/tx-1/void')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ reason: 'Pelanggan membatalkan pesanan' });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe(TransactionStatus.voided);
    // Verifikasi stok dikembalikan dari 8 -> 10 (8 + 2)
    expect(prisma.inventory.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { quantity: 10 },
      })
    );
  });
});
