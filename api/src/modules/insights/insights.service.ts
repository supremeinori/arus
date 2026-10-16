import { Role } from '@prisma/client';
import { prisma } from '../../config/db';
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
    const generatedInsights: BusinessInsightItem[] = [];

    // 1. Evaluasi R1 (LOW_STOCK) & R2 (RESTOCK_URGENT)
    const ingredients = await prisma.ingredient.findMany({
      include: {
        outlet: { select: { id: true, name: true } },
      },
    });

    for (const inv of ingredients) {
      if (inv.stock_qty <= inv.reorder_level) {
        const isUrgent = inv.stock_qty === 0;
        const id = `ins-stock-${inv.outlet_id}-${inv.id}`;
        const currentStatus = this.statusMap.get(id) || 'new';

        generatedInsights.push({
          id,
          rule_code: isUrgent ? 'RESTOCK_URGENT' : 'LOW_STOCK',
          severity: isUrgent ? 'critical' : 'warning',
          outlet_id: inv.outlet_id,
          product_id: inv.id,
          title: isUrgent
            ? `Bahan Baku Habis: ${inv.name} di ${inv.outlet.name}`
            : `Bahan Baku Menipis: ${inv.name} di ${inv.outlet.name}`,
          message: `Sisa stok ${inv.stock_qty} ${inv.unit} (batas aman minimum: ${inv.reorder_level} ${inv.unit}).`,
          evidence: {
            current_quantity: inv.stock_qty,
            reorder_level: inv.reorder_level,
            avg_lead_time_days: 3,
          },
          recommendation: `Segera lakukan pengadaan atau transfer bahan baku dari cabang lain sebelum kehabisan menu jualan.`,
          status: currentStatus,
          outlet: { id: inv.outlet.id, name: inv.outlet.name },
          product: { id: inv.id, name: inv.name, sku: inv.unit },
          created_at: new Date(),
        });
      }
    }

    // 2. Evaluasi R4 (SLOW_MOVING)
    const fourteenDaysAgo = new Date();
    fourteenDaysAgo.setDate(fourteenDaysAgo.getDate() - 14);

    const activeProducts = await prisma.product.findMany({
      where: { is_active: true },
      include: {
        recipes: {
          include: { ingredient: { include: { outlet: true } } },
        },
      },
    });

    const evaluatedPairs = new Set<string>();
    for (const prod of activeProducts) {
      for (const recipe of prod.recipes) {
        if (!recipe.ingredient?.outlet) continue;
        const outlet = recipe.ingredient.outlet;
        const pairKey = `${outlet.id}-${prod.id}`;
        if (evaluatedPairs.has(pairKey)) continue;
        evaluatedPairs.add(pairKey);

        const recentSales = await prisma.transactionItem.count({
          where: {
            product_id: prod.id,
            transaction: {
              outlet_id: outlet.id,
              created_at: { gte: fourteenDaysAgo },
            },
          },
        });

        if (recentSales === 0) {
          const id = `ins-slow-${outlet.id}-${prod.id}`;
          const currentStatus = this.statusMap.get(id) || 'new';

          generatedInsights.push({
            id,
            rule_code: 'SLOW_MOVING',
            severity: 'info',
            outlet_id: outlet.id,
            product_id: prod.id,
            title: `Menu Slow Moving: ${prod.name}`,
            message: `Menu ${prod.name} belum memiliki penjualan selama 14 hari terakhir di ${outlet.name}.`,
            evidence: {
              sales_last_14_days: 0,
            },
            recommendation: `Pertimbangkan bundling promosi atau potongan harga khusus untuk mempercepat perputaran menu.`,
            status: currentStatus,
            outlet: { id: outlet.id, name: outlet.name },
            product: { id: prod.id, name: prod.name, sku: prod.sku },
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
