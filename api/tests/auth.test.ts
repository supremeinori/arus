import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';
import app from '../src/app';
import { prisma } from '../src/config/db';
import * as tokens from '../src/shared/tokens';
import { signAccessToken } from '../src/shared/jwt';
import { Role } from '@prisma/client';

vi.mock('../src/config/db', () => {
  return {
    prisma: {
      user: {
        findUnique: vi.fn(),
        update: vi.fn(),
        findMany: vi.fn(),
        count: vi.fn(),
      },
      refreshToken: {
        create: vi.fn(),
        findUnique: vi.fn(),
        update: vi.fn(),
        updateMany: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
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

describe('Auth & RBAC Module (Milestone 3)', () => {
  const mockOwner = {
    id: 'a0000000-0000-0000-0000-000000000001',
    email: 'owner@arus.com',
    name: 'Rina Kartika',
    password_hash: '$argon2id$v=19$m=19456,t=2,p=1$fakehash',
    role: Role.owner,
    is_active: true,
    failed_login_count: 0,
    locked_until: null,
    user_outlets: [],
    settings: {
      display_currency: 'IDR',
      display_timezone: 'Asia/Jakarta',
    },
  };

  const mockStaff = {
    id: 'a0000000-0000-0000-0000-000000000003',
    email: 'staff@arus.demo',
    name: 'Siti Rahma',
    password_hash: '$argon2id$v=19$m=19456,t=2,p=1$fakehash',
    role: Role.staff,
    is_active: true,
    failed_login_count: 0,
    locked_until: null,
    user_outlets: [],
    settings: null,
  };

  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('POST /api/auth/login', () => {
    it('T-AUTH-01: Login dengan kredensial valid mengembalikan token dan user', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
      vi.spyOn(tokens, 'verifyPassword').mockResolvedValue(true);
      vi.mocked(prisma.outlet.findMany).mockResolvedValue([
        { id: 'out-1', name: 'ARUS Jogja', timezone: 'Asia/Jakarta', address: 'Malioboro' } as any,
      ]);
      vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as any);
      vi.mocked(prisma.user.update).mockResolvedValue(mockOwner as any);

      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'owner@arus.com', password: 'ValidPassword1' });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('data');
      expect(res.body.data).toHaveProperty('access_token');
      expect(res.body.data).toHaveProperty('refresh_token');
      expect(res.body.data.user.email).toBe('owner@arus.com');
      expect(res.body.data.user.role).toBe('owner');
    });

    it('T-AUTH-02: Login dengan password salah mengembalikan 401 AUTH_INVALID_CREDENTIALS', async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
      vi.spyOn(tokens, 'verifyPassword').mockResolvedValue(false);
      vi.mocked(prisma.user.update).mockResolvedValue(mockOwner as any);

      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'owner@arus.com', password: 'WrongPassword' });

      expect(res.status).toBe(401);
      expect(res.body).toHaveProperty('error');
      expect(res.body.error.code).toBe('AUTH_INVALID_CREDENTIALS');
    });

    it('T-AUTH-03: Gagal login 5x mengembalikan 423 AUTH_LOCKED', async () => {
      const lockedUser = {
        ...mockOwner,
        locked_until: new Date(Date.now() + 10 * 60 * 1000), // masih terkunci 10 menit
      };
      vi.mocked(prisma.user.findUnique).mockResolvedValue(lockedUser as any);

      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'owner@arus.com', password: 'AnyPassword' });

      expect(res.status).toBe(423);
      expect(res.body.error.code).toBe('AUTH_LOCKED');
    });
  });

  describe('POST /api/auth/refresh', () => {
    it('T-AUTH-04: Refresh token valid menghasilkan token baru (rotasi)', async () => {
      const activeToken = {
        id: 'token-1',
        user_id: mockOwner.id,
        family_id: 'family-1',
        token_hash: 'hash-1',
        expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        revoked_at: null,
        user: mockOwner,
      };

      vi.mocked(prisma.refreshToken.findUnique).mockResolvedValue(activeToken as any);
      vi.mocked(prisma.refreshToken.update).mockResolvedValue({} as any);
      vi.mocked(prisma.refreshToken.create).mockResolvedValue({} as any);

      const res = await request(app)
        .post('/api/auth/refresh')
        .send({ refresh_token: 'valid_refresh_token_string' });

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveProperty('access_token');
      expect(res.body.data).toHaveProperty('refresh_token');
    });

    it('T-AUTH-05: Penggunaan ulang token yang sudah dicabut memicu pencabutan keluarga token (AUTH_REFRESH_REUSED)', async () => {
      const reusedToken = {
        id: 'token-old',
        user_id: mockOwner.id,
        family_id: 'family-1',
        token_hash: 'hash-old',
        expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        revoked_at: new Date(Date.now() - 10000), // Sudah pernah di-revoke
        user: mockOwner,
      };

      vi.mocked(prisma.refreshToken.findUnique).mockResolvedValue(reusedToken as any);
      vi.mocked(prisma.refreshToken.updateMany).mockResolvedValue({ count: 2 });

      const res = await request(app)
        .post('/api/auth/refresh')
        .send({ refresh_token: 'reused_token_string' });

      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('AUTH_REFRESH_REUSED');
      expect(prisma.refreshToken.updateMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: { family_id: 'family-1' } })
      );
    });
  });

  describe('RBAC & Role Scoping', () => {
    it('T-RBAC-05: Staff memanggil POST /api/users ditolak dengan 403 FORBIDDEN', async () => {
      const staffToken = signAccessToken({
        sub: mockStaff.id,
        email: mockStaff.email,
        role: mockStaff.role,
      });

      vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
      vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([]);

      const res = await request(app)
        .post('/api/users')
        .set('Authorization', `Bearer ${staffToken}`)
        .send({
          name: 'New Staff',
          email: 'newstaff@arus.demo',
          password: 'Password123',
          role: 'staff',
        });

      expect(res.status).toBe(403);
      expect(res.body.error.code).toBe('FORBIDDEN');
    });

    it('T-RBAC-06: Owner memanggil GET /api/users diizinkan dengan 200', async () => {
      const ownerToken = signAccessToken({
        sub: mockOwner.id,
        email: mockOwner.email,
        role: mockOwner.role,
      });

      vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
      vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);
      vi.mocked(prisma.user.count).mockResolvedValue(1);
      vi.mocked(prisma.user.findMany).mockResolvedValue([
        {
          id: mockOwner.id,
          name: mockOwner.name,
          email: mockOwner.email,
          role: mockOwner.role,
          is_active: true,
          created_at: new Date(),
          user_outlets: [],
        } as any,
      ]);

      const res = await request(app)
        .get('/api/users')
        .set('Authorization', `Bearer ${ownerToken}`);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveLength(1);
      expect(res.body.meta.total).toBe(1);
    });
  });
});
