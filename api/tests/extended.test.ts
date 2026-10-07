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
      product: {
        findMany: vi.fn(),
        count: vi.fn(),
      },
      outlet: {
        findMany: vi.fn(),
      },
      userOutlet: {
        findMany: vi.fn(),
      },
    },
  };
});

describe('Extended Modules: Integrity, Game, and Search (Milestones 15-17)', () => {
  const mockOwner = {
    id: 'u-owner-1',
    email: 'owner@arus.demo',
    name: 'Rina Owner',
    role: Role.owner,
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
  });

  it('GET /api/integrity/chain/out-001 harus mengembalikan blok ledger', async () => {
    const res = await request(app)
      .get('/api/integrity/chain/out-001')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThan(0);
    expect(res.body.data[0]).toHaveProperty('payload_hash');
    expect(res.body.data[0]).toHaveProperty('previous_hash');
    expect(res.body.data[0]).toHaveProperty('merkle_root');
  });

  it('GET /api/integrity/verify/transaction/trx-001 harus mengonfirmasi keabsahan hash transaksi', async () => {
    const res = await request(app)
      .get('/api/integrity/verify/transaction/trx-001')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.is_valid).toBe(true);
    expect(res.body.data.ledger_status).toBe('ANCHORED_IN_BLOCKCHAIN');
  });

  it('GET /api/game/scenarios harus mengembalikan skenario mini-game', async () => {
    const res = await request(app)
      .get('/api/game/scenarios')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBe(3);
    expect(res.body.data[0]).toHaveProperty('options');
  });

  it('POST /api/game/sessions harus menghitung skor dan rank skenario', async () => {
    const res = await request(app)
      .post('/api/game/sessions')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        answers: [
          { scenario_id: 'scen-01', option_id: 'opt-1a' },
          { scenario_id: 'scen-02', option_id: 'opt-2b' },
          { scenario_id: 'scen-03', option_id: 'opt-3a' },
        ],
      });

    expect(res.status).toBe(200);
    expect(res.body.data.total_score).toBe(295);
    expect(res.body.data.rank).toContain('Master Store Manager');
  });

  it('GET /api/search harus mendukung pencarian global dengan query q', async () => {
    const res = await request(app)
      .get('/api/search?q=kopi')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('products');
    expect(res.body.data).toHaveProperty('outlets');
  });
});
