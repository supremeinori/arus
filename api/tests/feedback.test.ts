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
      userOutlet: {
        findMany: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
      feedback: {
        create: vi.fn(),
        findMany: vi.fn(),
      },
    },
  };
});

describe('Feedback Module (Phase 1 PAM)', () => {
  const mockOwner = {
    id: 'u-owner-1',
    email: 'owner@arus.demo',
    name: 'Rina Owner',
    role: Role.owner,
    avatar_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
    is_active: true,
  };

  const ownerToken = signAccessToken({
    sub: mockOwner.id,
    email: mockOwner.email,
    role: mockOwner.role,
  });

  beforeEach(() => {
    vi.clearAllMocks();
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
  });

  it('T-FB-01: Berhasil menyimpan kesan dan saran matkul PAM (Status 201)', async () => {
    vi.mocked(prisma.feedback.create).mockResolvedValue({
      id: 'fb-123',
      user_id: mockOwner.id,
      kesan: 'Materi kuliah sangat praktis dan relevan dengan industri.',
      saran: 'Perbanyak studi kasus arsitektur offline-first dan LBS.',
      rating: 5,
      created_at: new Date(),
      user: {
        id: mockOwner.id,
        name: mockOwner.name,
        email: mockOwner.email,
        role: mockOwner.role,
        avatar_url: mockOwner.avatar_url,
      },
    } as any);

    const res = await request(app)
      .post('/api/feedback')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        kesan: 'Materi kuliah sangat praktis dan relevan dengan industri.',
        saran: 'Perbanyak studi kasus arsitektur offline-first dan LBS.',
        rating: 5,
      });

    expect(res.status).toBe(201);
    expect(res.body.data.id).toBeDefined();
    expect(res.body.data.kesan).toContain('praktis');
    expect(res.body.data.saran).toContain('studi kasus');
  });

  it('T-FB-02: Menolak pengiriman jika kesan atau saran kosong (Status 400)', async () => {
    const res = await request(app)
      .post('/api/feedback')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        kesan: '',
        saran: '',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  it('T-FB-03: Berhasil mengambil daftar riwayat feedback (Status 200)', async () => {
    vi.mocked(prisma.feedback.findMany).mockResolvedValue([
      {
        id: 'fb-123',
        user_id: mockOwner.id,
        kesan: 'Kuliah PAM luar biasa seru.',
        saran: 'Pertahankan tugas proyek bertahap.',
        rating: 5,
        created_at: new Date(),
        user: {
          id: mockOwner.id,
          name: mockOwner.name,
          email: mockOwner.email,
          role: mockOwner.role,
          avatar_url: mockOwner.avatar_url,
        },
      } as any,
    ]);

    const res = await request(app)
      .get('/api/feedback')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThanOrEqual(1);
  });
});
