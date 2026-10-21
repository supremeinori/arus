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
      aiChatLog: {
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
      ingredient: {
        count: vi.fn(),
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

  const mockManager = {
    id: 'u-mgr-1',
    email: 'manager@arus.demo',
    name: 'Budi Manager',
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
    },
    15000
  );

  it(
    'T-AI-03: AI Assistant membandingkan performa antarcabang secara adil berdasarkan data aktual',
    async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
      const mockOutlets = [
        { id: 'out-1', name: 'Kopi Arus - Sudirman HQ', timezone: 'Asia/Jakarta' },
        { id: 'out-2', name: 'Kopi Arus - Bali', timezone: 'Asia/Makassar' },
      ];
      vi.mocked(prisma.outlet.findMany).mockResolvedValue(mockOutlets as any);

      // Transaksi di Sudirman: 15 juta, di Bali: 5 juta
      vi.mocked(prisma.transaction.aggregate).mockResolvedValue({
        _sum: { total_idr: 20000000, subtotal_idr: 20000000, discount_idr: 0 },
      } as any);
      vi.mocked(prisma.transaction.count).mockResolvedValue(40);
      vi.mocked(prisma.transaction.findMany).mockResolvedValue([
        { id: 'tx-1', outlet_id: 'out-1', total_idr: 15000000, subtotal_idr: 15000000, discount_idr: 0, created_at: new Date() },
        { id: 'tx-2', outlet_id: 'out-2', total_idr: 5000000, subtotal_idr: 5000000, discount_idr: 0, created_at: new Date() },
      ] as any);
      vi.mocked(prisma.transactionItem.findMany).mockResolvedValue([]);

      const res = await request(app)
        .post('/api/ai/chat')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          message: 'Bandingkan performa cabang Sudirman dan Bali',
        });

      expect(res.status).toBe(200);
      const comparisonFact = res.body.data.facts.find((f: any) => f.type === 'branch_comparison');
      expect(comparisonFact).toBeDefined();
      expect(comparisonFact.value.branches).toHaveLength(2);
      expect(comparisonFact.value.branches[0].name).toBe('Kopi Arus - Sudirman HQ');
      expect(comparisonFact.value.branches[0].revenue_idr).toBe(15000000);
      expect(comparisonFact.value.branches[1].name).toBe('Kopi Arus - Bali');
      expect(comparisonFact.value.branches[1].revenue_idr).toBe(5000000);
    },
    15000
  );

  it(
    'T-AI-04: AI Assistant menolak akses jika pengguna meminta data cabang di luar wewenangnya (RBAC)',
    async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue(mockManager as any);
      vi.mocked(prisma.userOutlet.findMany).mockResolvedValue([
        { user_id: mockManager.id, outlet_id: 'out-sudirman' },
      ] as any);

      // Seluruh cabang di DB
      vi.mocked(prisma.outlet.findMany).mockResolvedValue([
        { id: 'out-sudirman', name: 'Kopi Arus - Sudirman HQ', timezone: 'Asia/Jakarta' },
        { id: 'out-bali', name: 'Kopi Arus - Bali Canggu', timezone: 'Asia/Makassar' },
      ] as any);

      const res = await request(app)
        .post('/api/ai/chat')
        .set('Authorization', `Bearer ${managerToken}`)
        .send({
          message: 'Bagaimana penjualan di cabang Bali Canggu hari ini?',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.reply_text).toContain('tidak memiliki izin akses');
      expect(res.body.data.reply_text).toContain('Bali Canggu');
    },
    15000
  );

  it(
    'T-AI-05: AI Assistant menganalisis menu terlaris berdasarkan transaksi riil di database',
    async () => {
      vi.mocked(prisma.user.findUnique).mockResolvedValue(mockOwner as any);
      vi.mocked(prisma.outlet.findMany).mockResolvedValue([]);

      vi.mocked(prisma.transaction.aggregate).mockResolvedValue({
        _sum: { total_idr: 850000, subtotal_idr: 850000, discount_idr: 0 },
      } as any);
      vi.mocked(prisma.transaction.count).mockResolvedValue(15);
      vi.mocked(prisma.transactionItem.findMany).mockResolvedValue([
        {
          product_name_snapshot: 'Americano Dingin',
          quantity: 25,
          unit_price_idr: 18000,
          unit_cost_idr: 3500,
          line_total_idr: 450000,
          transaction: { outlet_id: 'out-1' },
        },
        {
          product_name_snapshot: 'Es Kopi Susu Aren',
          quantity: 18,
          unit_price_idr: 22000,
          unit_cost_idr: 6500,
          line_total_idr: 396000,
          transaction: { outlet_id: 'out-1' },
        },
      ] as any);

      const res = await request(app)
        .post('/api/ai/chat')
        .set('Authorization', `Bearer ${ownerToken}`)
        .send({
          message: 'Menu apa yang paling laris?',
        });

      expect(res.status).toBe(200);
      const productFact = res.body.data.facts.find((f: any) => f.type === 'top_products');
      expect(productFact).toBeDefined();
      expect(productFact.value[0].name).toBe('Americano Dingin');
      expect(productFact.value[0].sold).toBe(25);
      expect(productFact.value[1].name).toBe('Es Kopi Susu Aren');
      expect(productFact.value[1].sold).toBe(18);
    },
    15000
  );
});
