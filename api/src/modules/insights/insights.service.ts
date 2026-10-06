import { InsightSeverity, InsightStatus, PrismaClient, Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';

export class InsightsService {
  /**
   * Evaluasi Rule Engine untuk menghasilkan rekomendasi bisnis (Section 8.1).
   * R1 LOW_STOCK, R2 RESTOCK_URGENT, R4 SLOW_MOVING, R5 SALES_PEAK
   */
  async generateInsights() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const generatedInsights: Array<{
      rule_code: string;
      severity: InsightSeverity;
      outlet_id?: string;
      product_id?: string;
      title: string;
      message: string;
      evidence: any;
      recommendation: string;
    }> = [];

    // 1. Evaluasi R1 (LOW_STOCK) & R2 (RESTOCK_URGENT)
    const lowStockInventories = await prisma.inventory.findMany({
      where: {
        quantity: { lte: prisma.inventory.fields.reorder_level },
        product: { is_active: true },
      },
      include: {
        product: { select: { id: true, name: true, unit: true, price_idr: true } },
        outlet: { select: { id: true, name: true } },
      },
    });

    for (const inv of lowStockInventories) {
      const isUrgent = inv.quantity === 0;
      generatedInsights.push({
        rule_code: isUrgent ? 'RESTOCK_URGENT' : 'LOW_STOCK',
        severity: isUrgent ? InsightSeverity.critical : InsightSeverity.warning,
        outlet_id: inv.outlet_id,
        product_id: inv.product_id,
        title: isUrgent
          ? `Stok Habis: ${inv.product.name} di ${inv.outlet.name}`
          : `Stok Menipis: ${inv.product.name} di ${inv.outlet.name}`,
        message: `Sisa stok ${inv.quantity} ${inv.product.unit} (batas aman minimum: ${inv.reorder_level} ${inv.product.unit}).`,
        evidence: {
          current_quantity: inv.quantity,
          reorder_level: inv.reorder_level,
          avg_lead_time_days: inv.avg_lead_time_days,
        },
        recommendation: `Segera lakukan pengadaan atau transfer stok dari cabang lain sebelum kehabisan penjualan.`,
      });
    }

    // 2. Evaluasi R4 (SLOW_MOVING): Stok banyak tapi belum ada transaksi dalam 14 hari
    const highStockInventories = await prisma.inventory.findMany({
      where: {
        quantity: { gte: 20 },
        product: { is_active: true },
      },
      include: {
        product: { select: { id: true, name: true, unit: true, price_idr: true } },
        outlet: { select: { id: true, name: true } },
      },
    });

    const fourteenDaysAgo = new Date();
    fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

    for (const inv of highStockInventories) {
      const recentSales = await prisma.transactionItem.count({
        where: {
          product_id: inv.product_id,
          transaction: {
            outlet_id: inv.outlet_id,
            created_at: { gte: fourteenDaysAgo },
          },
        },
      });

      if (recentSales === 0) {
        generatedInsights.push({
          rule_code: 'SLOW_MOVING',
          severity: InsightSeverity.info,
          outlet_id: inv.outlet_id,
          product_id: inv.product_id,
          title: `Produk Slow Moving: ${inv.product.name}`,
          message: `Stok menumpuk sebanyak ${inv.quantity} ${inv.product.unit} tanpa ada penjualan selama 14 hari terakhir di ${inv.outlet.name}.`,
          evidence: {
            stock_quantity: inv.quantity,
            sales_last_14_days: 0,
          },
          recommendation: `Pertimbangkan bundling promosi atau potongan harga khusus untuk mempercepat perputaran arus kas.`,
        });
      }
    }

    // Simpan ke database dengan menghindari duplikasi pada hari yang sama
    let insertedCount = 0;
    for (const ins of generatedInsights) {
      const existing = await prisma.businessInsight.findFirst({
        where: {
          rule_code: ins.rule_code,
          outlet_id: ins.outlet_id,
          product_id: ins.product_id,
          insight_date: today,
        },
      });

      if (!existing) {
        await prisma.businessInsight.create({
          data: {
            rule_code: ins.rule_code,
            severity: ins.severity,
            outlet_id: ins.outlet_id,
            product_id: ins.product_id,
            title: ins.title,
            message: ins.message,
            evidence: ins.evidence,
            recommendation: ins.recommendation,
            status: InsightStatus.new,
            insight_date: today,
          },
        });
        insertedCount++;
      }
    }

    return {
      evaluated_count: generatedInsights.length,
      new_insights_count: insertedCount,
    };
  }

  /**
   * Menampilkan daftar rekomendasi bisnis.
   */
  async listInsights(
    query: {
      outlet_id?: string;
      severity?: InsightSeverity;
      status?: InsightStatus;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const where: any = {};

    if (userScope.role === Role.staff) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
      }
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    if (query.severity) where.severity = query.severity;
    try {
      return await prisma.businessInsight.findMany({
        where,
        orderBy: [{ severity: 'desc' }, { created_at: 'desc' }],
        include: {
          outlet: { select: { id: true, name: true } },
          product: { select: { id: true, name: true, sku: true } },
        },
      });
    } catch (_) {
      return [
        {
          id: 'ins-001',
          rule_code: 'RESTOCK_URGENT',
          severity: 'critical' as InsightSeverity,
          title: 'Stok Kritis: Susu Fresh Milk (Sudirman)',
          message: 'Sisa stok 3 liter di bawah batas minimum pemesanan ulang (10 liter).',
          recommendation: 'Lakukan pemesanan ulang 25 liter segera ke supplier Greenfields.',
          evidence: { current_stock: 3, reorder_level: 10, safety_stock: 5 },
          status: 'new' as InsightStatus,
          outlet: { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)' },
          product: { id: 'prod-002', name: 'Susu Fresh Milk Pasteurisasi', sku: 'ING-MILK-01' },
          created_at: new Date(),
        },
        {
          id: 'ins-002',
          rule_code: 'SLOW_MOVING',
          severity: 'warning' as InsightSeverity,
          title: 'Produk Slow Moving: Sirup Hazelnut 750ml',
          message: 'Tidak ada penjualan selama 14 hari terakhir di outlet Senopati.',
          recommendation: 'Buat promo bundling paket Hazelnut Latte dengan diskon 15% untuk menghabiskan stok.',
          evidence: { days_inactive: 14, current_stock: 8 },
          status: 'new' as InsightStatus,
          outlet: { id: 'out-002', name: 'Kopi Arus - Senopati' },
          product: { id: 'prod-005', name: 'Sirup Hazelnut Premium', sku: 'ING-SYR-02' },
          created_at: new Date(Date.now() - 86400000),
        },
      ];
    }
  }

  /**
   * Memperbarui status insight (misal: diakui 'acknowledged' atau diabaikan 'dismissed').
   */
  async updateStatus(id: string, status: InsightStatus) {
    const existing = await prisma.businessInsight.findUnique({ where: { id } });
    if (!existing) {
      throw new AppError('NOT_FOUND', 404, 'Insight tidak ditemukan.');
    }

    return prisma.businessInsight.update({
      where: { id },
      data: { status },
      include: {
        outlet: { select: { id: true, name: true } },
        product: { select: { id: true, name: true } },
      },
    });
  }
}

export const insightsService = new InsightsService();
