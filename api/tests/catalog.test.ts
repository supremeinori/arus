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
      productCategory: {
        findMany: vi.fn(),
        findUnique: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
      },
      product: {
        findMany: vi.fn(),
        findUnique: vi.fn(),
        count: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
      },
      inventory: {
        createMany: vi.fn(),
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

describe('Catalog Module (Milestone 4)', () => {
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

  const sampleProducts = [
    {
      id: 'prod-1',
      sku: 'KOP-01',
      name: 'Es Kopi Susu',
      unit: 'cup',
      price_idr: 22000,
      cost_idr: 9000,
      is_active: true,
      category: { id: 'cat-1', name: 'Kopi' },
    },
  ];

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('T-CAT-02: Staff melihat daftar produk tanpa field cost_idr (HPP disembunyikan)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.count).mockResolvedValue(1);
    vi.mocked(prisma.product.findMany).mockResolvedValue(sampleProducts as any);

    const res = await request(app)
      .get('/api/products')
      .set('Authorization', `Bearer ${staffToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data[0]).toHaveProperty('price_idr', 22000);
    expect(res.body.data[0]).not.toHaveProperty('cost_idr');
  });

  it('T-CAT-03: Owner melihat daftar produk lengkap dengan cost_idr', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.count).mockResolvedValue(1);
    vi.mocked(prisma.product.findMany).mockResolvedValue(sampleProducts as any);

    const res = await request(app)
      .get('/api/products')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data[0]).toHaveProperty('cost_idr', 9000);
  });

  it('T-CAT-04: Menolak pembuatan produk jika SKU sudah ada (CATALOG_SKU_DUPLICATE)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.findUnique).mockResolvedValue(sampleProducts[0] as any);

    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        name: 'Kopi Baru',
        sku: 'KOP-01',
        price_idr: 25000,
        cost_idr: 10000,
        unit: 'cup',
      });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('CATALOG_SKU_DUPLICATE');
  });

  it('T-CAT-05: Staff dilarang menambah produk (403 FORBIDDEN)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);

    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({
        name: 'Produk Ilegal',
        sku: 'ILEGAL-01',
        price_idr: 10000,
      });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
  });
});
