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

  it('T-CAT-06: Create produk menyimpan image_url (opsional)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.findUnique).mockResolvedValue(null as any);
    vi.mocked(prisma.product.create).mockResolvedValue({
      ...sampleProducts[0],
      image_url: 'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80',
    } as any);

    const imageUrl = 'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80';

    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        name: 'Kopi Gambar',
        sku: 'KOP-IMG-01',
        price_idr: 25000,
        image_url: imageUrl,
      });

    expect(res.status).toBe(201);
    // image_url harus diteruskan ke Prisma apa adanya.
    expect(vi.mocked(prisma.product.create).mock.calls[0][0].data.image_url).toBe(imageUrl);
    // Dan dikembalikan lagi di response supaya bisa dimuat ulang oleh form.
    expect(res.body.data.image_url).toBe(imageUrl);
  });

  it('T-CAT-07: Create produk tanpa image_url menyimpan null (tidak wajib)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.findUnique).mockResolvedValue(null as any);
    vi.mocked(prisma.product.create).mockResolvedValue({
      ...sampleProducts[0],
      image_url: null,
    } as any);

    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        name: 'Kopi Tanpa Gambar',
        sku: 'KOP-NOGAMBAR-01',
        price_idr: 25000,
      });

    expect(res.status).toBe(201);
    expect(vi.mocked(prisma.product.create).mock.calls[0][0].data.image_url).toBeNull();
  });

  it('T-CAT-08: Update produk menyimpan image_url baru', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.findUnique).mockResolvedValue(sampleProducts[0] as any);
    vi.mocked(prisma.product.update).mockResolvedValue(sampleProducts[0] as any);

    const imageUrl = 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=500&q=80';

    const res = await request(app)
      .patch('/api/products/prod-1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ image_url: imageUrl });

    expect(res.status).toBe(200);
    expect(vi.mocked(prisma.product.update).mock.calls[0][0].data.image_url).toBe(imageUrl);
  });

  it('T-CAT-09: Update produk bisa mengosongkan image_url (null)', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.findUnique).mockResolvedValue(sampleProducts[0] as any);
    vi.mocked(prisma.product.update).mockResolvedValue(sampleProducts[0] as any);

    const res = await request(app)
      .patch('/api/products/prod-1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ image_url: null });

    expect(res.status).toBe(200);
    expect(vi.mocked(prisma.product.update).mock.calls[0][0].data.image_url).toBeNull();
  });

  it('T-CAT-10: Update produk tanpa field image_url tidak mengubah kolom gambar', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.findUnique).mockResolvedValue(sampleProducts[0] as any);
    vi.mocked(prisma.product.update).mockResolvedValue(sampleProducts[0] as any);

    const res = await request(app)
      .patch('/api/products/prod-1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({ price_idr: 26000 });

    expect(res.status).toBe(200);
    const updateData = vi.mocked(prisma.product.update).mock.calls[0][0].data as any;
    expect(updateData.image_url).toBeUndefined();
  });

  it('T-CAT-11: Detail produk mengembalikan image_url untuk dimuat ulang form', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.product.findUnique).mockResolvedValue({
      ...sampleProducts[0],
      image_url: 'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80',
      recipes: [],
    } as any);

    const res = await request(app)
      .get('/api/products/prod-1')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.image_url).toBe(
      'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80',
    );
  });
});
