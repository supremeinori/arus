import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role, MovementType } from '@prisma/client';

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
        count: vi.fn(),
        findMany: vi.fn(),
        findUnique: vi.fn(),
        update: vi.fn(),
      },
      inventoryMovement: {
        count: vi.fn(),
        findMany: vi.fn(),
        create: vi.fn(),
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

describe('Inventory Module (Milestone 5)', () => {
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

  it('T-INV-01: List stok mengembalikan data stok dan mendeteksi is_low_stock', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.inventory.count).mockResolvedValue(1);
    vi.mocked(prisma.inventory.findMany).mockResolvedValue([
      {
        outlet_id: 'out-1',
        product_id: 'prod-1',
        quantity: 3,
        reorder_level: 5,
        avg_lead_time_days: 2,
        updated_at: new Date(),
        outlet: { id: 'out-1', name: 'Outlet Tebet' },
        product: {
          id: 'prod-1',
          sku: 'KOP-01',
          name: 'Kopi Susu',
          unit: 'cup',
          price_idr: 18000,
          cost_idr: 7000,
          category: { id: 'c-1', name: 'Kopi' },
        },
      },
    ] as any);

    const res = await request(app)
      .get('/api/inventory/stocks?outlet_id=out-1')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].is_low_stock).toBe(true);
    expect(res.body.data[0].cost_idr).toBe(7000);
  });

  it('T-INV-02: Adjustment stok opname berhasil mengupdate stok dan mencatat mutasi', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.inventory.findUnique).mockResolvedValue({
      outlet_id: 'out-1',
      product_id: 'prod-1',
      quantity: 10,
    } as any);

    vi.mocked(prisma.inventory.update).mockResolvedValue({
      outlet_id: 'out-1',
      product_id: 'prod-1',
      quantity: 15,
    } as any);

    vi.mocked(prisma.inventoryMovement.create).mockResolvedValue({
      id: 'mov-1',
      outlet_id: 'out-1',
      product_id: 'prod-1',
      movement_type: 'correction',
      quantity_delta: 5,
      quantity_after: 15,
      note: 'Hasil opname',
      created_by: mockOwner.id,
    } as any);

    const res = await request(app)
      .post('/api/inventory/adjustments')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        outlet_id: 'out-1',
        product_id: 'prod-1',
        movement_type: 'correction',
        quantity_delta: 5,
        note: 'Hasil opname',
      });

    expect(res.status).toBe(201);
    expect(res.body.data.inventory.quantity).toBe(15);
    expect(res.body.data.movement.movement_type).toBe('correction');
  });

  it('T-INV-03: Menolak penyesuaian jika stok tidak mencukupi (INSUFFICIENT_STOCK)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.inventory.findUnique).mockResolvedValue({
      outlet_id: 'out-1',
      product_id: 'prod-1',
      quantity: 5,
    } as any);

    const res = await request(app)
      .post('/api/inventory/adjustments')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        outlet_id: 'out-1',
        product_id: 'prod-1',
        movement_type: 'waste',
        quantity_delta: -10, // Mengurangi 10 saat stok cuma 5
      });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INSUFFICIENT_STOCK');
  });
});
