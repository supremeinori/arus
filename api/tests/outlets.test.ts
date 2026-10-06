import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import { signAccessToken } from '../src/shared/jwt';
import { Role } from '@prisma/client';
import { calculateHaversineDistanceKm } from '../src/modules/outlets/outlets.service';

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
      userOutlet: {
        findMany: vi.fn(),
      },
      transaction: {
        aggregate: vi.fn(),
      },
    },
  };
});

describe('Outlets & LBS Module (Milestone 11)', () => {
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

  it('T-LBS-01: Owner berhasil membuat outlet baru via POST /api/outlets', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findUnique).mockResolvedValue(null);

    const newOutletData = {
      id: 'out-new-1',
      name: 'ARUS Surabaya Tunjungan',
      address: 'Jl. Tunjungan No. 12, Surabaya',
      latitude: -7.2612,
      longitude: 112.7388,
      timezone: 'Asia/Jakarta',
      is_active: true,
    };

    vi.mocked(prisma.outlet.create).mockResolvedValue(newOutletData as any);

    const res = await request(app)
      .post('/api/outlets')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        name: 'ARUS Surabaya Tunjungan',
        address: 'Jl. Tunjungan No. 12, Surabaya',
        latitude: -7.2612,
        longitude: 112.7388,
        timezone: 'Asia/Jakarta',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.name).toBe('ARUS Surabaya Tunjungan');
  });

  it('T-LBS-02: Role staff ditolak (403 Forbidden) saat membuat outlet baru', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);

    const res = await request(app)
      .post('/api/outlets')
      .set('Authorization', `Bearer ${staffToken}`)
      .send({
        name: 'Outlet Ilegal',
        address: 'Alamat',
        latitude: 0,
        longitude: 0,
      });

    expect(res.status).toBe(403);
    expect(prisma.outlet.create).not.toHaveBeenCalled();
  });

  it('T-LBS-03: Formula Haversine menghitung jarak cabang terdekat secara akurat', () => {
    // Malioboro Yogyakarta (-7.7828, 110.3670) ke Solo Slamet Riyadi (-7.5561, 110.8316)
    // Jarak riil darat/geodesik ~57 - 60 km
    const dist = calculateHaversineDistanceKm(-7.7828, 110.367, -7.5561, 110.8316);
    expect(dist).toBeGreaterThan(55);
    expect(dist).toBeLessThan(65);
  });

  it('T-LBS-04: GET /api/outlets/nearest mengembalikan outlet terurut berdasarkan kedekatan lokasi pengguna', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const mockOutlets = [
      {
        id: 'out-london',
        name: 'ARUS London Oxford',
        address: '14 Oxford Street, London',
        latitude: 51.5074,
        longitude: -0.1278,
        timezone: 'Europe/London',
        is_active: true,
      },
      {
        id: 'out-jogja',
        name: 'ARUS Jogja Malioboro',
        address: 'Jl. Malioboro No. 45, Yogyakarta',
        latitude: -7.7828,
        longitude: 110.367,
        timezone: 'Asia/Jakarta',
        is_active: true,
      },
    ];

    vi.mocked(prisma.outlet.findMany).mockResolvedValue(mockOutlets as any);

    // Pengguna berada di dekat Tugu Yogyakarta (-7.7829, 110.3671)
    const res = await request(app)
      .get('/api/outlets/nearest?lat=-7.7829&lng=110.3671')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.nearest_outlet.name).toBe('ARUS Jogja Malioboro');
    expect(res.body.data.nearest_outlet.distance_km).toBeLessThan(1.0); // Kurang dari 1 km
  });

  it('T-LBS-05: GET /api/outlets/performance mengembalikan metrik performa 30 hari untuk coloring peta', async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);

    const mockOutlets = [
      {
        id: 'out-1',
        name: 'ARUS Jogja',
        address: 'Malioboro',
        latitude: -7.7828,
        longitude: 110.367,
        timezone: 'Asia/Jakarta',
        is_active: true,
        inventory: [{ quantity: 10, reorder_level: 5 }],
      },
    ];

    vi.mocked(prisma.outlet.findMany).mockResolvedValue(mockOutlets as any);
    vi.mocked(prisma.transaction.aggregate).mockResolvedValue({
      _sum: { total_idr: 15000000 },
      _count: { id: 120 },
    } as any);

    const res = await request(app)
      .get('/api/outlets/performance')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data[0].revenue_30d_idr).toBe(15000000);
    expect(res.body.data[0].performance_status).toBe('optimal');
  });
});
