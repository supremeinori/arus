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
      aiChatLog: {
        create: vi.fn(),
        findMany: vi.fn(),
      },
      transaction: {
        aggregate: vi.fn(),
        count: vi.fn(),
        findMany: vi.fn(),
      },
      transactionItem: {
        findMany: vi.fn(),
      },
      ingredient: {
        count: vi.fn(),
        findMany: vi.fn(),
      },
    },
  };
});

describe('ARUS Voice & STT Backend Module (arus_voice_spec.md)', () => {
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

  it('T-VOICE-01: POST /api/ai/tts mengubah teks menjadi audio_base64', async () => {
    const res = await request(app)
      .post('/api/ai/tts')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        text: 'Halo, saya Gadis dari ARUS.',
      });

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('audio_base64');
    expect(typeof res.body.data.audio_base64).toBe('string');
  });

  it('T-VOICE-02: POST /api/ai/chat mengembalikan voice_summary dan audio_base64', async () => {
    vi.mocked(prisma.transaction.aggregate).mockResolvedValue({
      _sum: { total_idr: 15000000, subtotal_idr: 15000000, discount_idr: 0 },
    } as any);
    vi.mocked(prisma.transaction.count).mockResolvedValue(40);
    vi.mocked(prisma.transactionItem.findMany).mockResolvedValue([]);

    const res = await request(app)
      .post('/api/ai/chat')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        message: 'Berapa omset kita hari ini?',
      });

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('voice_summary');
    expect(res.body.data).toHaveProperty('reply_text');
    expect(res.body.data).toHaveProperty('audio_base64');
    expect(typeof res.body.data.voice_summary).toBe('string');
    expect(res.body.data.voice_summary.length).toBeGreaterThan(0);
  });
});
