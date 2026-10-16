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
      aiConversation: {
        create: vi.fn(),
        findMany: vi.fn(),
        findFirst: vi.fn(),
      },
      aiMessage: {
        create: vi.fn(),
      },
      transaction: {
        aggregate: vi.fn(),
        count: vi.fn(),
        findMany: vi.fn(),
      },
      transactionItem: {
        findMany: vi.fn(),
      },
      inventory: {
        count: vi.fn(),
        findMany: vi.fn(),
      },
    },
  };
});

describe('AI Assistant Module (Milestone 9)', () => {
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
  });

  it(
    'T-AI-01: AI Assistant menjawab pertanyaan omset dengan fakta database terverifikasi',
    async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
      vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);

      vi.mocked(prisma.aiConversation.create).mockResolvedValue({
        id: 'conv-1',
        user_id: mockOwner.id,
        title: 'Berapa omset saya hari ini?',
      } as any);

      vi.mocked(prisma.transaction.aggregate).mockResolvedValue({
        _sum: { total_idr: 1500000, subtotal_idr: 1500000, discount_idr: 0 },
      } as any);
      vi.mocked(prisma.transaction.count).mockResolvedValue(30);
      vi.mocked(prisma.transactionItem.findMany).mockResolvedValue([]);

      vi.mocked(prisma.aiMessage.create).mockResolvedValue({
        id: 'msg-1',
        conversation_id: 'conv-1',
        role: 'assistant',
        content: 'Berdasarkan data operasional terkini: Total omset saat ini sebesar Rp 1.500.000 dari 30 transaksi.',
      } as any);

      const res = await request(app)
        .post('/api/ai/chat')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          message: 'Berapa omset penjualan saya hari ini?',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.facts).toHaveLength(1);
      expect(res.body.data.facts[0].value.revenue_idr).toBe(1500000);
      expect(res.body.data.message.content).toContain('1.500.000');
    },
    15000
  );

  it(
    'T-AI-02: AI Assistant memberikan panduan bantuan jika pertanyaan di luar data transaksi/stok',
    async () => {
    vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
    vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);

    vi.mocked(prisma.aiConversation.create).mockResolvedValue({
      id: 'conv-2',
      user_id: mockOwner.id,
      title: 'Halo apa kabar?',
    } as any);

    vi.mocked(prisma.aiMessage.create).mockResolvedValue({
      id: 'msg-2',
      conversation_id: 'conv-2',
      role: 'assistant',
      content: 'Saya adalah AI Business Assistant ARUS.',
    } as any);

    const res = await request(app)
      .post('/api/ai/chat')
      .set('Authorization', `Bearer ${ownerToken}`)
      .send({
        message: 'Halo apa kabar?',
      });

    expect(res.status).toBe(200);
    expect(res.body.data.facts).toHaveLength(0);
  }, 15000);
});
