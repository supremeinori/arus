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
      blockchainRecord: {
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
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([{ id: 'out-001' }] as any);
  });

  it('GET /api/integrity/blockchain/chain/out-001 returns persistent transaction blocks', async () => {
    vi.mocked(prisma.blockchainRecord.findMany).mockResolvedValue([
      {
        id: 'rec-001',
        outlet_id: 'out-001',
        block_index: 1,
        event_id: 'evt-001',
        event_type: 'sale',
        transaction_id: 'trx-001',
        created_at: new Date('2026-10-16T08:00:00.000Z'),
        prev_hash: '0'.repeat(64),
        data_hash: 'a'.repeat(64),
        block_hash: 'b'.repeat(64),
        event_data: { receipt_no: 'INV-CHAIN-001', total_idr: 12000 },
        backup_event_data: { receipt_no: 'INV-CHAIN-001', total_idr: 12000 },
        backup_data_hash: 'a'.repeat(64),
        backup_prev_hash: '0'.repeat(64),
        backup_block_hash: 'b'.repeat(64),
        transaction: { items: [] },
      } as any,
    ]);

    const res = await request(app)
      .get('/api/integrity/blockchain/chain/out-001')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data.blocks)).toBe(true);
    expect(res.body.data.blocks).toHaveLength(1);
    expect(res.body.data.blocks[0]).toHaveProperty('hash');
    expect(res.body.data.blocks[0]).toHaveProperty('previousHash');
  });

  it('GET /api/integrity/blockchain/verify/out-001 verifies the persistent chain', async () => {
    vi.mocked(prisma.blockchainRecord.findMany).mockResolvedValue([]);

    const res = await request(app)
      .get('/api/integrity/blockchain/verify/out-001')
      .set('Authorization', `Bearer ${ownerToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.isValid).toBe(true);
  });

  it('blocks Staff from every blockchain endpoint', async () => {
    const mockStaff = {
      id: 'u-staff-1',
      email: 'staff@arus.demo',
      name: 'Siti Staff',
      role: Role.staff,
      is_active: true,
    };
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockStaff as any);
    const staffToken = signAccessToken({
      sub: mockStaff.id,
      email: mockStaff.email,
      role: mockStaff.role,
    });

    const res = await request(app)
      .get('/api/integrity/blockchain/chain/out-001')
      .set('Authorization', `Bearer ${staffToken}`);

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('FORBIDDEN');
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
