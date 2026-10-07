import crypto from 'crypto';
import { prisma } from '../../config/db';
import { isDbAvailable } from '../../config/db-health';
import { AppError } from '../../shared/errors';
import { ReportType, TransactionStatus } from '@prisma/client';
import { GenerateReportInput } from './reports.schema';

const DEFAULT_CHAIN_ID = '00000000-0000-0000-0000-000000000001';

/**
 * Serialisasi objek secara kanonikal (key terurut alfabetis)
 * agar perhitungan SHA-256 hash snapshot deterministik 100%.
 */
export function canonicalStringify(obj: unknown): string {
  if (obj === null || typeof obj !== 'object') {
    return JSON.stringify(obj);
  }
  if (Array.isArray(obj)) {
    return '[' + obj.map(canonicalStringify).join(',') + ']';
  }
  const keys = Object.keys(obj as Record<string, unknown>).sort();
  return (
    '{' +
    keys
      .map(
        (k) =>
          JSON.stringify(k) +
          ':' +
          canonicalStringify((obj as Record<string, unknown>)[k])
      )
      .join(',') +
    '}'
  );
}

export function computePayloadHash(payload: unknown): string {
  const canonical = canonicalStringify(payload);
  return crypto.createHash('sha256').update(canonical).digest('hex');
}

export class ReportsService {
  /**
   * Menghasilkan laporan snapshot berkala dan menyimpannya secara tamper-evident (SHA-256).
   */
  async generateReport(userId: string, input: GenerateReportInput) {
    const fromDate = new Date(input.period_from);
    fromDate.setHours(0, 0, 0, 0);

    const toDate = new Date(input.period_to);
    toDate.setHours(23, 59, 59, 999);

    if (fromDate > toDate) {
      throw new AppError(
        'INVALID_DATE_RANGE',
        400,
        'Tanggal mulai (period_from) tidak boleh lebih besar dari tanggal akhir (period_to).'
      );
    }

    if (!(await isDbAvailable())) {
      const defaultPayload = {
        summary: {
          total_revenue_idr: 4500000,
          total_discount_idr: 0,
          transaction_count: 120,
          avg_basket_size_idr: 37500,
          net_margin_idr: 2700000,
          gross_margin_percentage: 60,
        },
      };
      const title = input.title || `Laporan ${input.type}`;
      const payloadHash = computePayloadHash(defaultPayload);
      return {
        id: `rep-${Date.now()}`,
        type: input.type,
        title,
        period_from: fromDate,
        period_to: toDate,
        outlet_scope: input.outlet_ids || ['out-001'],
        payload: defaultPayload,
        payload_hash: payloadHash,
        has_data: true,
        created_by: userId,
        created_at: new Date(),
        creator: { id: userId, name: 'Rina Kartika (Owner)', email: 'owner@arus.demo', role: 'owner' },
      };
    }

    // Tentukan outlet yang dicakup
    let outletScope: string[] = [];
    if (input.outlet_ids && input.outlet_ids.length > 0) {
      outletScope = input.outlet_ids;
    } else {
      const allOutlets = await prisma.outlet.findMany({
        where: { is_active: true },
        select: { id: true },
      });
      outletScope = allOutlets.map((o) => o.id);
    }

    let reportPayload: Record<string, unknown> = {};
    let defaultTitle = '';

    if (input.type === ReportType.sales_summary) {
      defaultTitle = `Laporan Penjualan (${input.period_from.slice(0, 10)} s/d ${input.period_to.slice(0, 10)})`;
      reportPayload = await this._aggregateSales(outletScope, fromDate, toDate);
    } else if (input.type === ReportType.inventory_status) {
      defaultTitle = `Status Inventaris & Nilai Aset (${new Date().toISOString().slice(0, 10)})`;
      reportPayload = await this._aggregateInventory(outletScope);
    } else if (input.type === ReportType.outlet_comparison) {
      defaultTitle = `Perbandingan Kinerja Antar Outlet (${input.period_from.slice(0, 10)} s/d ${input.period_to.slice(0, 10)})`;
      reportPayload = await this._aggregateOutletComparison(outletScope, fromDate, toDate);
    }

    const title = input.title || defaultTitle;
    const payloadHash = computePayloadHash(reportPayload);

    return prisma.$transaction(async (tx) => {
      // 1. Simpan Report
      const report = await tx.report.create({
        data: {
          type: input.type,
          title,
          period_from: fromDate,
          period_to: toDate,
          outlet_scope: outletScope,
          payload: reportPayload as any,
          payload_hash: payloadHash,
          has_data: true,
          created_by: userId,
        },
        include: {
          creator: {
            select: { id: true, name: true, email: true, role: true },
          },
        },
      });

      // 2. Kaitkan ke Tamper-evident Blockchain Ledger
      const lastBlock = await tx.blockchainRecord.findFirst({
        where: { chain_id: DEFAULT_CHAIN_ID },
        orderBy: { block_index: 'desc' },
      });

      const blockIndex = lastBlock ? lastBlock.block_index + 1n : 1n;
      const prevHash = lastBlock ? lastBlock.block_hash : '0'.repeat(64);
      const blockHash = crypto
        .createHash('sha256')
        .update(`${DEFAULT_CHAIN_ID}:${blockIndex}:${payloadHash}:${prevHash}`)
        .digest('hex');

      await tx.blockchainRecord.create({
        data: {
          chain_id: DEFAULT_CHAIN_ID,
          block_index: blockIndex,
          record_type: 'report',
          record_id: report.id,
          data_hash: payloadHash,
          prev_hash: prevHash,
          block_hash: blockHash,
        },
      });

      return {
        ...report,
        blockchain: {
          block_index: Number(blockIndex),
          block_hash: blockHash,
          prev_hash: prevHash,
        },
      };
    });
  }

  /**
   * Mengambil daftar laporan yang sudah di-generate.
   */
  async getReports(filter?: { outlet_id?: string; type?: ReportType }) {
    const where: any = {};
    if (filter?.type) {
      where.type = filter.type;
    }
    if (filter?.outlet_id) {
      where.outlet_scope = { has: filter.outlet_id };
    }

    if (!(await isDbAvailable())) {
      const dummyPayload = { summary: { total_revenue_idr: 5000000 } };
      return [
        {
          id: 'rep-001',
          type: ReportType.sales_summary,
          title: 'Laporan Penjualan Bulanan (Audited)',
          period_from: new Date(Date.now() - 30 * 86400000),
          period_to: new Date(),
          outlet_scope: ['out-001'],
          payload_hash: computePayloadHash(dummyPayload),
          created_by: { id: 'u-owner-001', name: 'Rina Kartika', email: 'owner@arus.demo' },
          created_at: new Date(),
        },
      ];
    }

    const reports = await prisma.report.findMany({
      where,
      orderBy: { created_at: 'desc' },
      include: {
        creator: {
          select: { id: true, name: true, email: true },
        },
      },
    });

    return reports.map((r) => ({
      id: r.id,
      type: r.type,
      title: r.title,
      period_from: r.period_from,
      period_to: r.period_to,
      outlet_scope: r.outlet_scope,
      payload_hash: r.payload_hash,
      created_by: r.creator,
      created_at: r.created_at,
    }));
  }

  /**
   * Mengambil detail laporan lengkap beserta verifikasi hash payload.
   */
  async getReportById(reportId: string) {
    const report = await prisma.report.findUnique({
      where: { id: reportId },
      include: {
        creator: {
          select: { id: true, name: true, email: true, role: true },
        },
        blockchain_records: {
          take: 1,
        },
      },
    });

    if (!report) {
      throw new AppError('NOT_FOUND', 404, 'Laporan tidak ditemukan.');
    }

    const computedHash = computePayloadHash(report.payload);
    const isValid = computedHash === report.payload_hash;

    const block = report.blockchain_records[0];
    const { blockchain_records, ...reportData } = report;

    return {
      ...reportData,
      verification: {
        is_valid: isValid,
        stored_hash: report.payload_hash,
        computed_hash: computedHash,
        verified_at: new Date().toISOString(),
        blockchain_anchored: !!block,
        block_index: block ? Number(block.block_index) : null,
        block_hash: block ? block.block_hash : null,
      },
    };
  }

  /**
   * Verifikasi independen keaslian payload terhadap SHA-256 hash.
   */
  async verifyReport(reportId: string) {
    const report = await prisma.report.findUnique({
      where: { id: reportId },
    });

    if (!report) {
      throw new AppError('NOT_FOUND', 404, 'Laporan tidak ditemukan.');
    }

    const computedHash = computePayloadHash(report.payload);
    const isValid = computedHash === report.payload_hash;

    return {
      report_id: report.id,
      title: report.title,
      is_valid: isValid,
      stored_hash: report.payload_hash,
      computed_hash: computedHash,
      message: isValid
        ? 'Integritas laporan terverifikasi valid (data asli, bebas tamper).'
        : 'PERINGATAN: Integritas laporan gagal, data payload terdeteksi telah dimodifikasi!',
      verified_at: new Date().toISOString(),
    };
  }

  private async _aggregateSales(outletScope: string[], fromDate: Date, toDate: Date) {
    const transactions = await prisma.transaction.findMany({
      where: {
        outlet_id: { in: outletScope },
        status: TransactionStatus.completed,
        created_at: { gte: fromDate, lte: toDate },
      },
      include: {
        items: {
          include: {
            product: { select: { name: true, cost_idr: true } },
          },
        },
      },
    });

    const totalRevenue = transactions.reduce((sum, t) => sum + t.total_idr, 0);
    const totalDiscount = transactions.reduce((sum, t) => sum + t.discount_idr, 0);
    const transactionCount = transactions.length;
    const avgBasketSize = transactionCount > 0 ? Math.round(totalRevenue / transactionCount) : 0;

    let totalEstimatedCost = 0;
    const paymentMethods: Record<string, number> = {};
    const itemSales: Record<string, { name: string; quantity: number; revenue: number }> = {};

    for (const t of transactions) {
      paymentMethods[t.payment_method] = (paymentMethods[t.payment_method] || 0) + t.total_idr;

      for (const item of t.items) {
        const itemCost = item.unit_cost_idr ?? item.product?.cost_idr ?? 0;
        totalEstimatedCost += itemCost * item.quantity;

        if (!itemSales[item.product_id]) {
          itemSales[item.product_id] = {
            name: item.product?.name || 'Produk',
            quantity: 0,
            revenue: 0,
          };
        }
        itemSales[item.product_id].quantity += item.quantity;
        itemSales[item.product_id].revenue += item.line_total_idr;
      }
    }

    const netMarginIdr = totalRevenue - totalEstimatedCost;
    const marginPercentage = totalRevenue > 0 ? Number(((netMarginIdr / totalRevenue) * 100).toFixed(2)) : 0;

    const topItems = Object.values(itemSales)
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 5);

    return {
      summary: {
        total_revenue_idr: totalRevenue,
        total_discount_idr: totalDiscount,
        total_estimated_cost_idr: totalEstimatedCost,
        net_margin_idr: netMarginIdr,
        margin_percentage: marginPercentage,
        transaction_count: transactionCount,
        average_basket_size_idr: avgBasketSize,
      },
      payment_methods: paymentMethods,
      top_items: topItems,
      outlet_count: outletScope.length,
    };
  }

  private async _aggregateInventory(outletScope: string[]) {
    const stocks = await prisma.inventory.findMany({
      where: {
        outlet_id: { in: outletScope },
      },
      include: {
        product: { select: { name: true, sku: true, cost_idr: true, unit: true } },
        outlet: { select: { name: true } },
      },
    });

    const totalSkus = stocks.length;
    let totalQuantity = 0;
    let totalStockValueIdr = 0;
    const lowStockItems: Array<{
      product_name: string;
      outlet_name: string;
      quantity: number;
      reorder_level: number;
    }> = [];

    for (const s of stocks) {
      totalQuantity += s.quantity;
      const cost = s.product.cost_idr || 0;
      totalStockValueIdr += s.quantity * cost;

      if (s.quantity <= s.reorder_level) {
        lowStockItems.push({
          product_name: s.product.name,
          outlet_name: s.outlet.name,
          quantity: s.quantity,
          reorder_level: s.reorder_level,
        });
      }
    }

    return {
      summary: {
        total_skus: totalSkus,
        total_quantity: totalQuantity,
        total_stock_value_idr: totalStockValueIdr,
        low_stock_count: lowStockItems.length,
      },
      low_stock_items: lowStockItems.slice(0, 10),
      outlet_count: outletScope.length,
    };
  }

  private async _aggregateOutletComparison(outletScope: string[], fromDate: Date, toDate: Date) {
    const outlets = await prisma.outlet.findMany({
      where: { id: { in: outletScope } },
      select: { id: true, name: true },
    });

    const results = [];
    for (const o of outlets) {
      const txs = await prisma.transaction.findMany({
        where: {
          outlet_id: o.id,
          status: TransactionStatus.completed,
          created_at: { gte: fromDate, lte: toDate },
        },
        select: { total_idr: true },
      });

      const totalRevenue = txs.reduce((sum, t) => sum + t.total_idr, 0);
      results.push({
        outlet_id: o.id,
        outlet_name: o.name,
        transaction_count: txs.length,
        total_revenue_idr: totalRevenue,
      });
    }

    results.sort((a, b) => b.total_revenue_idr - a.total_revenue_idr);

    return {
      outlets: results,
      total_combined_revenue_idr: results.reduce((sum, r) => sum + r.total_revenue_idr, 0),
    };
  }
}
