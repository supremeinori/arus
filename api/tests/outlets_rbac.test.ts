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
        findUnique: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
      },
      product: {
        findMany: vi.fn(),
        findUnique: vi.fn(),
        create: vi.fn(),
        update: vi.fn(),
        delete: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
      },
      transaction: {
        aggregate: vi.fn(),
      },
    },
  };
});

describe('Outlet & Catalog RBAC and Soft Delete Module', () => {
  const mockOwner = {
    id: 'u-owner-1',
    email: 'owner@arus.demo',
    name: 'Rina Owner',
    role: Role.owner,
    is_active: true,
  };

  const mockManager = {
    id: 'u-manager-1',
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

  const managerToken = signAccessToken({
    sub: mockManager.id,
    email: mockManager.email,
    role: mockManager.role,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
  });

  it('RBAC-01: Manager ditolak (403 Forbidden) saat membuat outlet baru', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockManager as any);

    const res = await request(app)
      .post('/api/outlets')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        name: 'Outlet Manager Ilegal',
        address: 'Alamat',
        latitude: -7.0,
        longitude: 110.0,
      });

    expect(res.status).toBe(403);
    expect(prisma.outlet.create).not.toHaveBeenCalled();
  });

  it('RBAC-02: Manager ditolak (403 Forbidden) saat memperbarui outlet', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockManager as any);

    const res = await request(app)
      .patch('/api/outlets/out-1')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        name: 'ARUS Modifikasi Ilegal',
      });

    expect(res.status).toBe(403);
    expect(prisma.outlet.update).not.toHaveBeenCalled();
  });

  it('RBAC-03: Manager ditolak (403 Forbidden) saat menonaktifkan outlet', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockManager as any);

    const res = await request(app)
      .delete('/api/outlets/out-1')
      .set('Authorization', `Bearer ${managerToken}`);

    expect(res.status).toBe(403);
    expect(prisma.outlet.update).not.toHaveBeenCalled();
  });

  it('RBAC-04: Manager ditolak (403 Forbidden) saat membuat atau mengedit produk di katalog', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockManager as any);

    const createRes = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        name: 'Kopi Manager',
        sku: 'MGR-01',
        price_idr: 25000,
      });

    expect(createRes.status).toBe(403);

    const updateRes = await request(app)
      .patch('/api/products/prod-1')
      .set('Authorization', `Bearer ${managerToken}`)
      .send({
        name: 'Kopi Edit Manager',
      });

    expect(updateRes.status).toBe(403);
  });

  it('RBAC-05: Owner berhasil memperbarui koordinat & informasi outlet via PATCH /api/outlets/:id', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findUnique)
      .mockResolvedValueOnce({
        id: 'out-1',
        name: 'ARUS Lama',
        address: 'Jl. Lama',
        latitude: -7.0,
        longitude: 110.0,
        timezone: 'Asia/Jakarta',
        is_active: true,
      } as any)
      .mockResolvedValueOnce(null);

    vi.mocked(prisma.outlet.update).mockResolvedValue({
      id: 'out-1',
      name: 'ARUS Jogja Baru',
      address: 'Jl. Malioboro 10',
      latitude: -7.7828,
      longitude: 110.3670,
      timezone: 'Asia/Jakarta',
      is_active: true,
    } as any);

    const res = await request(app)
      .patch('/api/outlets/out-1')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        name: 'ARUS Jogja Baru',
        address: 'Jl. Malioboro 10',
        latitude: -7.7828,
        longitude: 110.3670,
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.name).toBe('ARUS Jogja Baru');
    expect(res.body.data.latitude).toBe(-7.7828);
    expect(res.body.data.longitude).toBe(110.3670);
  });

  it('RBAC-06: Owner berhasil menonaktifkan outlet (Soft Delete) via DELETE /api/outlets/:id', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findUnique).mockResolvedValue({
      id: 'out-1',
      name: 'ARUS Cabang Sudirman',
      is_active: true,
      latitude: -6.2,
      longitude: 106.8,
    } as any);

    vi.mocked(prisma.outlet.update).mockResolvedValue({
      id: 'out-1',
      name: 'ARUS Cabang Sudirman',
      is_active: false,
      latitude: -6.2,
      longitude: 106.8,
    } as any);

    const res = await request(app)
      .delete('/api/outlets/out-1')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.message).toBe('Cabang outlet berhasil dinonaktifkan.');
    expect(res.body.data.is_active).toBe(false);

    expect(prisma.outlet.update).toHaveBeenCalledWith({
      where: { id: 'out-1' },
      data: { is_active: false },
    });
  });
});
