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
      ingredient: {
        count: vi.fn(),
        findMany: vi.fn(),
        findUnique: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
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

describe('Inventory Module (Milestone 5 / Modul 2)', () => {
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

  it('T-INV-01: List bahan baku mengembalikan data bahan baku dan mendeteksi status low', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([{ id: 'out-1' }] as any);
    vi.mocked(prisma.ingredient.findMany).mockResolvedValue([
      {
        id: 'ing-1',
        outlet_id: 'out-1',
        name: 'Biji Kopi Espresso',
        unit: 'gram',
        stock_qty: 30,
        reorder_level: 50,
        cost_per_unit: 150,
        updated_at: new Date(),
        outlet: { id: 'out-1', name: 'Outlet Tebet' },
      },
    ] as any);

    const res = await request(app)
      .get('/api/inventory/ingredients?outlet_id=out-1')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveLength(1);
    expect(res.body.data[0].status).toBe('low');
    expect(res.body.data[0].cost_per_unit).toBe(150);
  });

  it('T-INV-02: Adjustment stok opname berhasil mengupdate stok bahan baku dan mencatat mutasi', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([{ id: 'out-1' }] as any);
    vi.mocked(prisma.ingredient.findUnique).mockResolvedValue({
      id: 'ing-1',
      outlet_id: 'out-1',
      name: 'Biji Kopi Espresso',
      unit: 'gram',
      stock_qty: 10,
      reorder_level: 50,
      cost_per_unit: 150,
    } as any);

    vi.mocked(prisma.ingredient.update).mockResolvedValue({
      id: 'ing-1',
      outlet_id: 'out-1',
      name: 'Biji Kopi Espresso',
      unit: 'gram',
      stock_qty: 15,
      reorder_level: 50,
      cost_per_unit: 150,
      updated_at: new Date(),
      outlet: { id: 'out-1', name: 'Outlet Tebet' },
    } as any);

    vi.mocked(prisma.inventoryMovement.create).mockResolvedValue({
      id: 'mov-1',
      outlet_id: 'out-1',
      ingredient_id: 'ing-1',
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
        ingredient_id: 'ing-1',
        movement_type: 'correction',
        quantity_delta: 5,
        note: 'Hasil opname',
      });

    expect(res.status).toBe(201);
    expect(res.body.data.ingredient.stock_qty).toBe(15);
    expect(res.body.data.movement.movement_type).toBe('correction');
  });

  it('T-INV-03: Menolak penyesuaian jika stok tidak mencukupi (INSUFFICIENT_STOCK)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([{ id: 'out-1' }] as any);
    vi.mocked(prisma.ingredient.findUnique).mockResolvedValue({
      id: 'ing-1',
      outlet_id: 'out-1',
      name: 'Biji Kopi Espresso',
      unit: 'gram',
      stock_qty: 5,
      reorder_level: 50,
      cost_per_unit: 150,
    } as any);

    const res = await request(app)
      .post('/api/inventory/adjustments')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        outlet_id: 'out-1',
        ingredient_id: 'ing-1',
        movement_type: 'waste',
        quantity_delta: -10, // Mengurangi 10 saat stok cuma 5
      });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INSUFFICIENT_STOCK');
  });
});
