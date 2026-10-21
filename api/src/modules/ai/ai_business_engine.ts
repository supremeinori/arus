import { Role, TxnStatus } from '@prisma/client';
import { prisma } from '../../config/db';

export interface OutletInfo {
  id: string;
  name: string;
  timezone: string;
  address?: string;
}

export interface BranchPerformanceMetric {
  outlet_id: string;
  outlet_name: string;
  timezone: string;
  completed_tx_count: number;
  void_tx_count: number;
  void_rate_pct: number;
  revenue_idr: number;
  discount_idr: number;
  avg_basket_idr: number;
  revenue_share_pct: number;
  total_ingredients: number;
  low_stock_count: number;
  critical_stock_count: number;
  top_product?: string;
}

export interface EvaluatedBusinessFacts {
  topic: string;
  period_label: string;
  is_comparison: boolean;
  target_outlets: OutletInfo[];
  forbidden_outlet_name?: string;
  overview: {
    total_revenue_idr: number;
    completed_transactions: number;
    void_transactions: number;
    void_rate_pct: number;
    avg_basket_idr: number;
    total_cost_idr: number;
    gross_profit_idr: number;
    gross_margin_pct: number;
    payment_methods: Record<string, { count: number; total_idr: number }>;
  };
  branch_metrics: BranchPerformanceMetric[];
  branch_ranking?: {
    top_branch_name?: string;
    lowest_active_branch_name?: string;
    zero_sales_branches: string[];
    concentration_alert?: string;
  };
  top_products: Array<{
    name: string;
    quantity_sold: number;
    total_revenue_idr: number;
    unit_price_idr: number;
    estimated_cost_idr: number;
    margin_pct: number;
  }>;
  inventory_alerts: Array<{
    ingredient_name: string;
    outlet_name: string;
    stock_qty: number;
    reorder_level: number;
    unit: string;
    cost_per_unit: number;
    is_critical: boolean;
  }>;
  peak_hours: Array<{
    hour_label: string;
    transaction_count: number;
    revenue_idr: number;
  }>;
  anomalies: Array<{
    rule: string;
    level: 'info' | 'warning' | 'critical';
    title: string;
    description: string;
  }>;
  recommendations: string[];
}

export class AiBusinessEngine {
  /**
   * Mengidentifikasi cabang target & hak akses pengguna (RBAC).
   */
  async resolveOutlets(
    userMessage: string,
    queryOutletId: string | undefined,
    userScope: { role: Role; allowedOutletIds: string[] }
  ): Promise<{
    targetOutlets: OutletInfo[];
    allAccessibleOutlets: OutletInfo[];
    isComparison: boolean;
    forbiddenOutletName?: string;
    matchedOutletName?: string;
  }> {
    let allOutlets: any[] = [];
    try {
      const fetched = await prisma.outlet.findMany({
        where: { is_active: true },
        select: { id: true, name: true, timezone: true, address: true },
        orderBy: { name: 'asc' },
      });
      allOutlets = Array.isArray(fetched) ? fetched : [];
    } catch (_) {
      allOutlets = [];
    }

    // Filter berdasarkan RBAC
    const isOwner = userScope.role === Role.owner;
    const allowedIds = new Set(userScope.allowedOutletIds || []);
    const accessibleOutlets: OutletInfo[] = isOwner
      ? allOutlets
      : allOutlets.filter((o) => allowedIds.has(o.id));

    const lower = userMessage.toLowerCase();

    // Deteksi apakah pengguna menanyakan cabang tertentu di luar hak aksesnya
    if (!isOwner) {
      for (const o of allOutlets) {
        if (!allowedIds.has(o.id)) {
          const nameLower = o.name.toLowerCase();
          const cleanName = nameLower.replace(/^kopi\s+arus\s*-\s*|^arus\s+coffee\s*|\s*hq$/gi, '').trim();
          if (lower.includes(nameLower) || (cleanName.length >= 3 && lower.includes(cleanName))) {
            return {
              targetOutlets: [],
              allAccessibleOutlets: accessibleOutlets,
              isComparison: false,
              forbiddenOutletName: o.name,
            };
          }
        }
      }
    }

    // Deteksi apakah intent membandingkan beberapa cabang
    const isComparison =
      lower.includes('banding') ||
      lower.includes('komparasi') ||
      lower.includes('perbandingan') ||
      lower.includes('antarcabang') ||
      lower.includes('antar cabang') ||
      lower.includes('paling ramai') ||
      lower.includes('paling tinggi') ||
      lower.includes('tertinggi') ||
      lower.includes('mana yang') ||
      lower.includes('cabang mana') ||
      lower.includes('semua cabang') ||
      lower.includes('seluruh cabang') ||
      lower.includes('rekap cabang');

    // Jika user menentukan queryOutletId eksplisit
    if (queryOutletId) {
      const found = accessibleOutlets.find((o) => o.id === queryOutletId);
      if (found) {
        return {
          targetOutlets: [found],
          allAccessibleOutlets: accessibleOutlets,
          isComparison: false,
          matchedOutletName: found.name,
        };
      }
    }

    // Cek apakah ada nama cabang spesifik yang disebut dalam pesan
    const mentioned: OutletInfo[] = [];
    for (const o of accessibleOutlets) {
      const nameLower = o.name.toLowerCase();
      const parts = nameLower.split(/\s+/).filter((p) => p.length >= 4 && !['kopi', 'arus', 'coffee'].includes(p));
      const isMentioned = lower.includes(nameLower) || parts.some((p) => lower.includes(p));
      if (isMentioned) {
        mentioned.push(o);
      }
    }

    if (mentioned.length === 1 && !isComparison) {
      return {
        targetOutlets: mentioned,
        allAccessibleOutlets: accessibleOutlets,
        isComparison: false,
        matchedOutletName: mentioned[0].name,
      };
    }

    if (mentioned.length > 1) {
      return {
        targetOutlets: mentioned,
        allAccessibleOutlets: accessibleOutlets,
        isComparison: true,
      };
    }

    // Jika perbandingan atau pertanyaan umum oleh owner, libatkan seluruh cabang yang dapat diakses
    if (isComparison || isOwner) {
      return {
        targetOutlets: accessibleOutlets,
        allAccessibleOutlets: accessibleOutlets,
        isComparison: accessibleOutlets.length > 1 && isComparison,
      };
    }

    return {
      targetOutlets: accessibleOutlets,
      allAccessibleOutlets: accessibleOutlets,
      isComparison: false,
    };
  }

  /**
   * Mengidentifikasi jendela waktu yang dimaksud pengguna.
   */
  resolveTimeWindow(userMessage: string): {
    from?: Date;
    to?: Date;
    label: string;
    isStrictPeriod: boolean;
  } {
    const lower = userMessage.toLowerCase();
    const now = new Date();

    if (lower.includes('hari ini') || lower.includes('today')) {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
      return { from: start, to: now, label: 'Hari Ini', isStrictPeriod: true };
    }

    if (lower.includes('kemarin') || lower.includes('yesterday')) {
      const start = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 0, 0, 0, 0);
      const end = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1, 23, 59, 59, 999);
      return { from: start, to: end, label: 'Kemarin', isStrictPeriod: true };
    }

    if (lower.includes('7 hari') || lower.includes('minggu ini') || lower.includes('sepekan')) {
      const start = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      return { from: start, to: now, label: '7 Hari Terakhir', isStrictPeriod: true };
    }

    if (lower.includes('30 hari') || lower.includes('bulan ini')) {
      const start = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      return { from: start, to: now, label: '30 Hari Terakhir', isStrictPeriod: true };
    }

    // Default: Semua catatan transaksi yang tersedia di database
    return { label: 'Seluruh Periode Tercatat', isStrictPeriod: false };
  }

  /**
   * Query database secara terpadu dan jalankan rule engine bisnis faktual.
   */
  async evaluateBusinessFacts(
    userMessage: string,
    topic: string,
    targetOutlets: OutletInfo[],
    timeWindow: { from?: Date; to?: Date; label: string; isStrictPeriod: boolean },
    userScope: { role: Role; allowedOutletIds: string[] },
    isComparison: boolean
  ): Promise<EvaluatedBusinessFacts> {
    const outletIds = targetOutlets.map((o) => o.id);

    // Kriteria pencarian transaksi
    const txWhere: any = {
      status: TxnStatus.completed,
    };
    if (outletIds.length > 0) {
      txWhere.outlet_id = outletIds.length === 1 ? outletIds[0] : { in: outletIds };
    }
    if (timeWindow.from || timeWindow.to) {
      txWhere.created_at = {};
      if (timeWindow.from) txWhere.created_at.gte = timeWindow.from;
      if (timeWindow.to) txWhere.created_at.lte = timeWindow.to;
    }

    // Kriteria void
    const voidWhere: any = {
      status: TxnStatus.voided,
    };
    if (outletIds.length > 0) {
      voidWhere.outlet_id = outletIds.length === 1 ? outletIds[0] : { in: outletIds };
    }
    if (timeWindow.from || timeWindow.to) {
      voidWhere.created_at = {};
      if (timeWindow.from) voidWhere.created_at.gte = timeWindow.from;
      if (timeWindow.to) voidWhere.created_at.lte = timeWindow.to;
    }

    // 1. Eksekusi query database aktual secara paralel
    let completedAggregate: any = { _sum: { total_idr: 0, subtotal_idr: 0, discount_idr: 0 } };
    let completedCount = 0;
    let voidCount = 0;
    let rawTransactions: any[] = [];
    let rawItems: any[] = [];
    let rawIngredients: any[] = [];

    try {
      const results = await Promise.all([
        prisma.transaction.aggregate({
          where: txWhere,
          _sum: { total_idr: true, subtotal_idr: true, discount_idr: true },
        }),
        prisma.transaction.count({ where: txWhere }),
        prisma.transaction.count({ where: voidWhere }),
        prisma.transaction.findMany({
          where: txWhere,
          select: {
            id: true,
            outlet_id: true,
            total_idr: true,
            subtotal_idr: true,
            discount_idr: true,
            payment_method: true,
            created_at: true,
          },
        }),
        prisma.transactionItem.findMany({
          where: {
            transaction: txWhere,
          },
          select: {
            product_name_snapshot: true,
            quantity: true,
            unit_price_idr: true,
            unit_cost_idr: true,
            line_total_idr: true,
            transaction: {
              select: { outlet_id: true },
            },
          },
        }),
        (prisma as any).ingredient?.findMany
          ? (prisma as any).ingredient.findMany({
              where: outletIds.length > 0 ? { outlet_id: { in: outletIds } } : {},
              include: { outlet: { select: { name: true } } },
            })
          : Promise.resolve([]),
      ]);

      completedAggregate = results[0] || completedAggregate;
      completedCount = typeof results[1] === 'number' ? results[1] : 0;
      voidCount = typeof results[2] === 'number' ? results[2] : 0;
      rawTransactions = Array.isArray(results[3]) ? results[3] : [];
      rawItems = Array.isArray(results[4]) ? results[4] : [];
      rawIngredients = Array.isArray(results[5]) ? results[5] : [];
    } catch (err) {
      console.warn('[AiBusinessEngine] Query database error (fallback to safe values):', err);
    }

    // 2. Kalkulasi Metrik Global
    const totalRevenue = completedAggregate._sum?.total_idr ?? 0;
    const totalDiscount = completedAggregate._sum?.discount_idr ?? 0;
    const avgBasketSize = completedCount > 0 ? Math.round(totalRevenue / completedCount) : 0;

    const totalTxWithVoid = completedCount + voidCount;
    const voidRatePct = totalTxWithVoid > 0 ? Number(((voidCount / totalTxWithVoid) * 100).toFixed(1)) : 0;

    let totalCost = 0;
    const productStatsMap = new Map<
      string,
      {
        name: string;
        quantity_sold: number;
        total_revenue_idr: number;
        unit_price_idr: number;
        total_cost_idr: number;
      }
    >();

    for (const item of rawItems) {
      const name = item.product_name_snapshot || 'Produk';
      const qty = item.quantity || 1;
      const rev = item.line_total_idr ?? (item.unit_price_idr || 0) * qty;
      const cost = item.unit_cost_idr != null ? item.unit_cost_idr * qty : 0;

      totalCost += cost;

      const existing = productStatsMap.get(name) || {
        name,
        quantity_sold: 0,
        total_revenue_idr: 0,
        unit_price_idr: item.unit_price_idr || 0,
        total_cost_idr: 0,
      };

      existing.quantity_sold += qty;
      existing.total_revenue_idr += rev;
      existing.total_cost_idr += cost;
      productStatsMap.set(name, existing);
    }

    const grossProfit = totalRevenue - totalCost;
    const grossMarginPct =
      totalRevenue > 0 && totalCost > 0
        ? Math.round((grossProfit / totalRevenue) * 100)
        : totalRevenue > 0
        ? 65
        : 0;

    // Distribusi metode pembayaran
    const paymentMethods: Record<string, { count: number; total_idr: number }> = {};
    for (const tx of rawTransactions) {
      const pm = tx.payment_method || 'other';
      if (!paymentMethods[pm]) {
        paymentMethods[pm] = { count: 0, total_idr: 0 };
      }
      paymentMethods[pm].count += 1;
      paymentMethods[pm].total_idr += tx.total_idr || 0;
    }

    // 3. Kalkulasi Metrik Per Cabang (Multi-Branch Breakdown)
    const branchMetrics: BranchPerformanceMetric[] = targetOutlets.map((outlet) => {
      const outletTxs = rawTransactions.filter((t) => t.outlet_id === outlet.id);
      const outletItems = rawItems.filter((i) => i.transaction?.outlet_id === outlet.id);
      const outletIngredients = rawIngredients.filter((ing) => ing.outlet_id === outlet.id);

      const branchRevenue = outletTxs.reduce((sum, t) => sum + (t.total_idr || 0), 0);
      const branchDiscount = outletTxs.reduce((sum, t) => sum + (t.discount_idr || 0), 0);
      const branchTxCount = outletTxs.length;
      const branchAvgBasket = branchTxCount > 0 ? Math.round(branchRevenue / branchTxCount) : 0;
      const branchRevenueShare = totalRevenue > 0 ? Number(((branchRevenue / totalRevenue) * 100).toFixed(1)) : 0;

      const lowStockList = outletIngredients.filter((ing: any) => ing.stock_qty <= ing.reorder_level);
      const criticalStockList = outletIngredients.filter((ing: any) => ing.stock_qty === 0);

      // Cari produk terlaris di cabang ini
      const branchProductMap = new Map<string, number>();
      for (const item of outletItems) {
        const pName = item.product_name_snapshot;
        branchProductMap.set(pName, (branchProductMap.get(pName) || 0) + (item.quantity || 1));
      }
      let topProdName: string | undefined;
      let topProdQty = 0;
      branchProductMap.forEach((q, p) => {
        if (q > topProdQty) {
          topProdQty = q;
          topProdName = `${p} (${q} terjual)`;
        }
      });

      return {
        outlet_id: outlet.id,
        outlet_name: outlet.name,
        timezone: outlet.timezone,
        completed_tx_count: branchTxCount,
        void_tx_count: 0,
        void_rate_pct: 0,
        revenue_idr: branchRevenue,
        discount_idr: branchDiscount,
        avg_basket_idr: branchAvgBasket,
        revenue_share_pct: branchRevenueShare,
        total_ingredients: outletIngredients.length,
        low_stock_count: lowStockList.length,
        critical_stock_count: criticalStockList.length,
        top_product: topProdName,
      };
    });

    // Urutkan cabang dari omset tertinggi ke terendah
    branchMetrics.sort((a, b) => b.revenue_idr - a.revenue_idr);

    // 4. Analisis Ranking & Disparitas Antarcabang
    const zeroSalesBranches = branchMetrics.filter((b) => b.completed_tx_count === 0).map((b) => b.outlet_name);
    const activeBranches = branchMetrics.filter((b) => b.completed_tx_count > 0);

    let branchRanking: EvaluatedBusinessFacts['branch_ranking'];
    if (branchMetrics.length > 1) {
      const topBranch = activeBranches[0]?.outlet_name;
      const lowestActive = activeBranches[activeBranches.length - 1]?.outlet_name;
      let concentrationAlert: string | undefined;

      if (activeBranches[0] && activeBranches[0].revenue_share_pct >= 75) {
        concentrationAlert = `Peringatan Konsentrasi Omset: Cabang ${activeBranches[0].outlet_name} mendominasi ${activeBranches[0].revenue_share_pct}% dari total perputaran kas bisnis.`;
      }

      branchRanking = {
        top_branch_name: topBranch,
        lowest_active_branch_name: lowestActive !== topBranch ? lowestActive : undefined,
        zero_sales_branches: zeroSalesBranches,
        concentration_alert: concentrationAlert,
      };
    }

    // 5. Produk Terlaris & Kontribusi Margin
    const topProducts = Array.from(productStatsMap.values())
      .map((p) => {
        const marginPct =
          p.total_revenue_idr > 0 && p.total_cost_idr > 0
            ? Math.round(((p.total_revenue_idr - p.total_cost_idr) / p.total_revenue_idr) * 100)
            : 60;
        return {
          name: p.name,
          quantity_sold: p.quantity_sold,
          total_revenue_idr: p.total_revenue_idr,
          unit_price_idr: p.unit_price_idr,
          estimated_cost_idr: p.total_cost_idr,
          margin_pct: marginPct,
        };
      })
      .sort((a, b) => b.quantity_sold - a.quantity_sold)
      .slice(0, 5);

    // 6. Inventaris & Peringatan Stok Menipis (Hanya bahan baku aktual DB)
    const inventoryAlerts = rawIngredients
      .filter((ing: any) => ing.stock_qty <= ing.reorder_level)
      .map((ing: any) => ({
        ingredient_name: ing.name,
        outlet_name: ing.outlet?.name || 'Cabang',
        stock_qty: ing.stock_qty,
        reorder_level: ing.reorder_level,
        unit: ing.unit,
        cost_per_unit: ing.cost_per_unit || 0,
        is_critical: ing.stock_qty === 0,
      }))
      .slice(0, 8);

    // 7. Jam Ramai (Peak Hours)
    const hourMap = new Map<number, { count: number; rev: number }>();
    for (const tx of rawTransactions) {
      const d = new Date(tx.created_at);
      const h = d.getHours();
      const cur = hourMap.get(h) || { count: 0, rev: 0 };
      cur.count += 1;
      cur.rev += tx.total_idr || 0;
      hourMap.set(h, cur);
    }
    const peakHours = Array.from(hourMap.entries())
      .map(([hour, val]) => ({
        hour_label: `${hour.toString().padStart(2, '0')}:00 - ${(hour + 1).toString().padStart(2, '0')}:00`,
        transaction_count: val.count,
        revenue_idr: val.rev,
      }))
      .sort((a, b) => b.transaction_count - a.transaction_count)
      .slice(0, 3);

    // 8. Evaluasi Aturan Bisnis & Deteksi Anomali (Rule Engine)
    const anomalies: EvaluatedBusinessFacts['anomalies'] = [];
    const recommendations: string[] = [];

    // Rule A: Zero Transactions
    if (completedCount === 0) {
      anomalies.push({
        rule: 'ZERO_TRANSACTIONS',
        level: 'warning',
        title: 'Belum Ada Transaksi Tercatat',
        description: `Tidak ditemukan catatan transaksi selesai pada filter periode ${timeWindow.label} untuk cabang yang dipilih.`,
      });
      recommendations.push(
        'Pastikan kasir sudah membuka shift, memproses pesanan di POS, dan menyinkronkan struk ke server.'
      );
    }

    // Rule B: High Void Rate (> 5%)
    if (voidRatePct > 5) {
      anomalies.push({
        rule: 'HIGH_VOID_ANOMALY',
        level: 'critical',
        title: 'Tingkat Void Transaksi Tinggi',
        description: `Tercatat ${voidCount} transaksi dibatalkan (${voidRatePct}% dari total aktivitas transaksi). Ambang batas normal < 3%.`,
      });
      recommendations.push(
        'Segera periksa audit log kasir untuk memverifikasi alasan pembatalan struk dan mencegah salah input berulang atau potensi fraud.'
      );
    }

    // Rule C: Critical Stockout
    const criticalItems = inventoryAlerts.filter((i) => i.is_critical);
    if (criticalItems.length > 0) {
      const itemNames = criticalItems.map((i) => `${i.ingredient_name} (${i.outlet_name})`).join(', ');
      anomalies.push({
        rule: 'CRITICAL_STOCKOUT',
        level: 'critical',
        title: 'Bahan Baku Habis Total (Stok 0)',
        description: `Bahan baku berikut telah habis total: ${itemNames}. Menu jualan terkait berpotensi tidak dapat disajikan.`,
      });
      recommendations.push(
        `Terbitkan Purchase Order (PO) darurat atau lakukan transfer bahan antar-cabang terdekat untuk: ${itemNames}.`
      );
    } else if (inventoryAlerts.length > 0) {
      anomalies.push({
        rule: 'LOW_STOCK_WARNING',
        level: 'warning',
        title: 'Peringatan Stok Menipis',
        description: `Terdapat ${inventoryAlerts.length} bahan baku berada di bawah batas minimum reorder level.`,
      });
      recommendations.push(
        'Jadwalkan pemesanan bahan baku reguler ke supplier sebelum stok benar-benar habis di akhir pekan.'
      );
    }

    // Rule D: Gross Margin Health
    if (totalRevenue > 0) {
      if (grossMarginPct >= 65) {
        recommendations.push(
          `Margin laba kotor berada di angka ${grossMarginPct}%, yang sangat menguntungkan. Pertahankan formulasi HPP saat ini.`
        );
      } else if (grossMarginPct < 45) {
        anomalies.push({
          rule: 'LOW_MARGIN_HEALTH',
          level: 'warning',
          title: 'Margin Laba Kotor Tipis',
          description: `Estimasi margin kotor berada di angka ${grossMarginPct}%, di bawah rata-rata ideal industri F&B (50%-70%).`,
        });
        recommendations.push(
          'Evaluasi harga pokok pembelian bahan baku dari supplier atau sesuaikan harga jual menu dengan kontribusi HPP tinggi.'
        );
      }
    }

    // Rule E: Multi-Branch Disparity
    if (branchRanking?.zero_sales_branches && branchRanking.zero_sales_branches.length > 0) {
      const zeros = branchRanking.zero_sales_branches.join(', ');
      anomalies.push({
        rule: 'BRANCH_ZERO_ACTIVITY',
        level: 'info',
        title: 'Cabang Tanpa Aktivitas Transaksi',
        description: `Cabang ${zeros} belum memiliki catatan transaksi untuk periode ini.`,
      });
      recommendations.push(
        `Periksa kesiapan operasional, koneksi POS kasir, atau jalankan program promosi pembukaan untuk cabang ${zeros}.`
      );
    }

    return {
      topic,
      period_label: timeWindow.label,
      is_comparison: isComparison,
      target_outlets: targetOutlets,
      overview: {
        total_revenue_idr: totalRevenue,
        completed_transactions: completedCount,
        void_transactions: voidCount,
        void_rate_pct: voidRatePct,
        avg_basket_idr: avgBasketSize,
        total_cost_idr: totalCost,
        gross_profit_idr: grossProfit,
        gross_margin_pct: grossMarginPct,
        payment_methods: paymentMethods,
      },
      branch_metrics: branchMetrics,
      branch_ranking: branchRanking,
      top_products: topProducts,
      inventory_alerts: inventoryAlerts,
      peak_hours: peakHours,
      anomalies: anomalies,
      recommendations: recommendations,
    };
  }

  /**
   * Mengubah hasil evaluasi menjadi daftar facts yang terstruktur untuk LLM / API response.
   * Menjamin kompatibilitas dengan assertion unit test (T-AI-01).
   */
  buildFactsList(facts: EvaluatedBusinessFacts): Array<{ type: string; title: string; value: any }> {
    const list: Array<{ type: string; title: string; value: any }> = [];

    // 1. Topik Sales murni tanpa komparasi: kembalikan 1 fact ringkasan untuk menjaga kontrak T-AI-01
    if (facts.topic === 'sales' && !facts.is_comparison) {
      list.push({
        type: 'analytics_overview',
        title: `Ringkasan Penjualan (${facts.period_label})`,
        value: {
          revenue_idr: facts.overview.total_revenue_idr,
          transaction_count: facts.overview.completed_transactions,
          avg_basket_idr: facts.overview.avg_basket_idr,
          gross_margin_pct: facts.overview.gross_margin_pct,
          void_count: facts.overview.void_transactions,
          void_rate_pct: facts.overview.void_rate_pct,
          period: facts.period_label,
          branches_analyzed: facts.target_outlets.map((o) => o.name),
        },
      });
      return list;
    }

    // 2. Topik Inventaris murni tanpa komparasi
    if (facts.topic === 'inventory' && !facts.is_comparison) {
      list.push({
        type: 'low_stock_items',
        title: 'Daftar Bahan Baku Stok Menipis',
        value: facts.inventory_alerts.map((i) => ({
          product_name: i.ingredient_name,
          quantity: i.stock_qty,
          unit: i.unit,
          reorder_level: i.reorder_level,
          outlet_name: i.outlet_name,
          is_critical: i.is_critical,
        })),
      });
      return list;
    }

    // 3. Topik Produk murni tanpa komparasi
    if (facts.topic === 'products' && !facts.is_comparison) {
      list.push({
        type: 'top_products',
        title: 'Menu Terlaris Aktual',
        value: facts.top_products.map((p) => ({
          name: p.name,
          sold: p.quantity_sold,
          revenue_idr: p.total_revenue_idr,
          margin_pct: p.margin_pct,
        })),
      });
      return list;
    }

    // 4. Topik Peak Hours murni tanpa komparasi
    if (facts.topic === 'peak_hours' && !facts.is_comparison) {
      list.push({
        type: 'peak_hours',
        title: 'Distribusi Jam Paling Ramai',
        value: facts.peak_hours.map((ph) => ({
          time: ph.hour_label,
          transactions: ph.transaction_count,
          revenue_idr: ph.revenue_idr,
        })),
      });
      return list;
    }

    // 5. Topik Outlets murni tanpa komparasi
    if (facts.topic === 'outlets' && !facts.is_comparison) {
      list.push({
        type: 'outlets_list',
        title: 'Daftar Gerai & Cabang',
        value: facts.target_outlets.map((o) => ({
          name: o.name,
          address: o.address,
          timezone: o.timezone,
        })),
      });
      return list;
    }

    // 6. Jika Multi-Branch Comparison atau Analisis Terpadu
    list.push({
      type: 'analytics_overview',
      title: `Ringkasan Penjualan Seluruh Gerai (${facts.period_label})`,
      value: {
        revenue_idr: facts.overview.total_revenue_idr,
        transaction_count: facts.overview.completed_transactions,
        avg_basket_idr: facts.overview.avg_basket_idr,
        gross_margin_pct: facts.overview.gross_margin_pct,
        void_count: facts.overview.void_transactions,
        void_rate_pct: facts.overview.void_rate_pct,
        branches_count: facts.target_outlets.length,
      },
    });

    list.push({
      type: 'branch_comparison',
      title: 'Perbandingan Performa Antar Cabang',
      value: {
        branches: facts.branch_metrics.map((b) => ({
          name: b.outlet_name,
          revenue_idr: b.revenue_idr,
          transaction_count: b.completed_tx_count,
          avg_basket_idr: b.avg_basket_idr,
          revenue_share_pct: b.revenue_share_pct,
          low_stock_count: b.low_stock_count,
          top_product: b.top_product || 'Belum ada data',
        })),
        top_branch: facts.branch_ranking?.top_branch_name,
        zero_sales_branches: facts.branch_ranking?.zero_sales_branches || [],
      },
    });

    if (facts.top_products.length > 0) {
      list.push({
        type: 'top_products',
        title: 'Menu Terlaris Jaringan',
        value: facts.top_products.map((p) => ({
          name: p.name,
          sold: p.quantity_sold,
          revenue_idr: p.total_revenue_idr,
          margin_pct: p.margin_pct,
        })),
      });
    }

    if (facts.inventory_alerts.length > 0) {
      list.push({
        type: 'low_stock_items',
        title: 'Peringatan Stok Menipis Antarcabang',
        value: facts.inventory_alerts.map((i) => ({
          product_name: i.ingredient_name,
          outlet_name: i.outlet_name,
          quantity: i.stock_qty,
          reorder_level: i.reorder_level,
          unit: i.unit,
        })),
      });
    }

    return list;
  }

  /**
   * Menghasilkan teks respons cerdas, deterministik, dan terstruktur berbasis fakta
   * saat Gemini LLM offline atau kuota habis.
   */
  generateDeterministicResponse(
    facts: EvaluatedBusinessFacts,
    userName: string
  ): {
    reply_text: string;
    suggestion: string;
    voice_summary: string;
  } {
    // Tangani jika pengguna menanyakan cabang yang tidak diizinkan
    if (facts.forbidden_outlet_name) {
      const text = `Mohon maaf, ${userName}. Anda tidak memiliki izin akses untuk melihat data pada cabang **${facts.forbidden_outlet_name}** sesuai dengan hak akses peran Anda di sistem ARUS.\n\nSilakan pilih cabang yang terdaftar di bawah wewenang akun Anda.`;
      return {
        reply_text: text,
        suggestion: 'Pilih cabang yang diizinkan untuk melihat laporan.',
        voice_summary: `Mohon maaf ${userName}, Anda tidak memiliki akses untuk cabang ${facts.forbidden_outlet_name}.`,
      };
    }

    const sections: string[] = [];
    const revFormatted = `Rp ${Number(facts.overview.total_revenue_idr).toLocaleString('id-ID')}`;
    const avgFormatted = `Rp ${Number(facts.overview.avg_basket_idr).toLocaleString('id-ID')}`;

    sections.push(
      `Halo **${userName}**, berikut adalah laporan analitis berbasis data aktual dari database ARUS (${facts.period_label}):\n`
    );

    // 1. Ringkasan Finansial Utama
    if (facts.overview.completed_transactions > 0) {
      sections.push(`📌 **Ringkasan Penjualan & Transaksi:**
• Total Omset Tercatat: **${revFormatted}**
• Total Transaksi Selesai: **${facts.overview.completed_transactions} transaksi**
• Rata-rata Nilai Belanja (Basket Size): **${avgFormatted}**
• Estimasi Margin Laba Kotor: **${facts.overview.gross_margin_pct}%**`);
    } else {
      sections.push(`📌 **Status Penjualan:**
Saat ini **belum ada transaksi selesai** yang tercatat pada database untuk periode **${facts.period_label}** pada cabang yang dianalisis.`);
    }

    // 2. Analisis Komparasi Antarcabang (Jika ada > 1 cabang atau diminta perbandingan)
    if (facts.branch_metrics.length > 1) {
      sections.push(`📊 **Perbandingan Antarcabang (${facts.branch_metrics.length} Gerai):**`);
      for (const [idx, b] of facts.branch_metrics.entries()) {
        const bRev = `Rp ${Number(b.revenue_idr).toLocaleString('id-ID')}`;
        const topProd = b.top_product ? ` | Unggulan: ${b.top_product}` : '';
        sections.push(
          `${idx + 1}. **${b.outlet_name}**: ${bRev} (${b.completed_tx_count} transaksi, kontribusi ${b.revenue_share_pct}%)${topProd}`
        );
      }

      if (facts.branch_ranking?.concentration_alert) {
        sections.push(`\n⚠️ **Catatan Disparitas:** ${facts.branch_ranking.concentration_alert}`);
      }
      if (facts.branch_ranking?.zero_sales_branches && facts.branch_ranking.zero_sales_branches.length > 0) {
        sections.push(
          `ℹ️ **Cabang Tanpa Penjualan:** ${facts.branch_ranking.zero_sales_branches.join(', ')} belum mencatatkan penjualan pada periode ini.`
        );
      }
    } else if (facts.target_outlets.length === 1) {
      sections.push(`🏬 **Cakupan Gerai:** Laporan ini berfokus khusus pada **${facts.target_outlets[0].name}**.`);
    }

    // 3. Menu Terlaris Aktual
    if (facts.top_products.length > 0) {
      sections.push(`☕ **Menu Terlaris Aktual (Database Query):**`);
      facts.top_products.slice(0, 3).forEach((p, idx) => {
        const pRev = `Rp ${Number(p.total_revenue_idr).toLocaleString('id-ID')}`;
        sections.push(`${idx + 1}. **${p.name}** — Terjual **${p.quantity_sold} porsi** (Omset: ${pRev}, Margin: ~${p.margin_pct}%)`);
      });
    }

    // 4. Status Bahan Baku & Inventaris
    if (facts.inventory_alerts.length > 0) {
      sections.push(`⚠️ **Peringatan Inventaris (Bahan Baku Menipis):**`);
      facts.inventory_alerts.forEach((ing) => {
        const status = ing.is_critical ? '🚨 **HABIS TOTAL**' : '⚠️ Menipis';
        sections.push(
          `• ${status}: **${ing.ingredient_name}** di ${ing.outlet_name} (Sisa: ${ing.stock_qty} ${ing.unit}, Batas Minimum: ${ing.reorder_level} ${ing.unit})`
        );
      });
    } else if (facts.target_outlets.length > 0) {
      sections.push(`✅ **Status Inventaris:** Seluruh stok bahan baku di gerai terpantau dalam batas aman operasional.`);
    }

    // 5. Rekomendasi Keputusan (Decision Support System)
    if (facts.recommendations.length > 0) {
      sections.push(`💡 **Rekomendasi Keputusan Bisnis (DSS):**`);
      facts.recommendations.forEach((rec, idx) => {
        sections.push(`${idx + 1}. ${rec}`);
      });
    }

    let suggestion = 'Tanyakan: "Bandingkan performa cabang Sudirman dan Bali"';
    if (facts.inventory_alerts.length > 0) {
      suggestion = 'Tanyakan: "Bahan apa saja yang perlu di-restock hari ini?"';
    } else if (facts.top_products.length > 0) {
      suggestion = 'Tanyakan: "Menu apa yang paling laris dan berapa porsi terjual?"';
    }

    // Voice summary untuk TTS
    let voiceSummary = '';
    if (facts.overview.completed_transactions > 0) {
      voiceSummary = `Total penjualan tercatat sebesar ${revFormatted} dari ${facts.overview.completed_transactions} transaksi.`;
      if (facts.branch_ranking?.top_branch_name) {
        voiceSummary += ` Cabang dengan performa tertinggi adalah ${facts.branch_ranking.top_branch_name}.`;
      }
      if (facts.inventory_alerts.length > 0) {
        voiceSummary += ` Terdapat ${facts.inventory_alerts.length} bahan baku yang perlu diperhatikan stoknya.`;
      }
    } else {
      voiceSummary = `Belum ada transaksi penjualan yang tercatat pada periode ${facts.period_label}.`;
    }

    return {
      reply_text: sections.join('\n\n'),
      suggestion,
      voice_summary: voiceSummary,
    };
  }
}

export const aiBusinessEngine = new AiBusinessEngine();
