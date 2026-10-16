import { Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { isDbAvailable } from '../../config/db-health';
import { AppError } from '../../shared/errors';

export type InsightSeverity = 'info' | 'warning' | 'critical';
export type InsightStatus = 'new' | 'acknowledged' | 'dismissed';

export interface BusinessInsightItem {
  id: string;
  rule_code: string;
  severity: InsightSeverity;
  outlet_id?: string;
  product_id?: string;
  title: string;
  message: string;
  evidence: any;
  recommendation: string;
  status: InsightStatus;
  outlet?: { id: string; name: string };
  product?: { id: string; name: string; sku?: string };
  created_at: Date;
}

export class InsightsService {
  private statusMap: Map<string, InsightStatus> = new Map();

  /**
   * Evaluasi Rule Engine on-the-fly untuk menghasilkan rekomendasi bisnis real-time (Section 8.1).
   * R1 LOW_STOCK, R2 RESTOCK_URGENT, R4 SLOW_MOVING
   */
  async generateInsights(): Promise<{ evaluated_count: number; insights: BusinessInsightItem[] }> {
    if (!(await isDbAvailable())) {
      const fallbackList: BusinessInsightItem[] = [
        {
          id: 'ins-001',
          rule_code: 'RESTOCK_URGENT',
          severity: 'critical',
          title: 'Stok Kritis: Susu Fresh Milk (Sudirman)',
          message: 'Sisa stok 3 liter di bawah batas minimum pemesanan ulang (10 liter).',
          recommendation: 'Lakukan pemesanan ulang 25 liter segera ke supplier Greenfields.',
          evidence: { current_stock: 3, reorder_level: 10, safety_stock: 5 },
          status: 'new',
          outlet: { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)' },
          product: { id: 'prod-002', name: 'Susu Fresh Milk Pasteurisasi', sku: 'ING-MILK-01' },
          created_at: new Date(),
        },
      ];
      return { evaluated_count: fallbackList.length, insights: fallbackList };
    }

    const generatedInsights: BusinessInsightItem[] = [];

    // 1. Evaluasi R1 (LOW_STOCK) & R2 (RESTOCK_URGENT)
    const inventories = await prisma.inventory.findMany({
      where: {
        product: { is_active: true },
      },
      include: {
        product: { select: { id: true, sku: true, name: true, unit: true, price_idr: true } },
        outlet: { select: { id: true, name: true } },
      },
    });

    for (const inv of inventories) {
      if (inv.quantity <= inv.reorder_level) {
        const isUrgent = inv.quantity === 0;
        const id = `ins-stock-${inv.outlet_id}-${inv.product_id}`;
        const currentStatus = this.statusMap.get(id) || 'new';

        generatedInsights.push({
          id,
          rule_code: isUrgent ? 'RESTOCK_URGENT' : 'LOW_STOCK',
          severity: isUrgent ? 'critical' : 'warning',
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
          status: currentStatus,
          outlet: { id: inv.outlet.id, name: inv.outlet.name },
          product: { id: inv.product.id, name: inv.product.name, sku: inv.product.sku },
          created_at: new Date(),
        });
      }
    }

    // 2. Evaluasi R4 (SLOW_MOVING)
    const fourteenDaysAgo = new Date();
    fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

    for (const inv of inventories) {
      if (inv.quantity >= 15) {
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
          const id = `ins-slow-${inv.outlet_id}-${inv.product_id}`;
          const currentStatus = this.statusMap.get(id) || 'new';

          generatedInsights.push({
            id,
            rule_code: 'SLOW_MOVING',
            severity: 'info',
            outlet_id: inv.outlet_id,
            product_id: inv.product_id,
            title: `Produk Slow Moving: ${inv.product.name}`,
            message: `Stok menumpuk sebanyak ${inv.quantity} ${inv.product.unit} tanpa ada penjualan selama 14 hari terakhir di ${inv.outlet.name}.`,
            evidence: {
              stock_quantity: inv.quantity,
              sales_last_14_days: 0,
            },
            recommendation: `Pertimbangkan bundling promosi atau potongan harga khusus untuk mempercepat perputaran arus kas.`,
            status: currentStatus,
            outlet: { id: inv.outlet.id, name: inv.outlet.name },
            product: { id: inv.product.id, name: inv.product.name, sku: inv.product.sku },
            created_at: new Date(),
          });
        }
      }
    }

    return {
      evaluated_count: generatedInsights.length,
      insights: generatedInsights,
    };
  }

  /**
   * Menampilkan daftar rekomendasi bisnis on-the-fly.
   */
  async listInsights(
    query: {
      outlet_id?: string;
      severity?: InsightSeverity;
      status?: InsightStatus;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ): Promise<BusinessInsightItem[]> {
    if (userScope.role === Role.staff && query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
      throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
    }

    const { insights } = await this.generateInsights();
    let filtered = insights;

    if (userScope.role === Role.staff) {
      filtered = filtered.filter((i) => !i.outlet_id || userScope.allowedOutletIds.includes(i.outlet_id));
    } else if (query.outlet_id) {
      filtered = filtered.filter((i) => i.outlet_id === query.outlet_id);
    }

    if (query.severity) {
      filtered = filtered.filter((i) => i.severity === query.severity);
    }

    if (query.status) {
      filtered = filtered.filter((i) => i.status === query.status);
    }

    return filtered;
  }

  /**
   * Memperbarui status insight secara in-memory.
   */
  async updateStatus(id: string, status: InsightStatus) {
    this.statusMap.set(id, status);
    return {
      id,
      status,
      updated_at: new Date(),
    };
  }
}

export const insightsService = new InsightsService();
