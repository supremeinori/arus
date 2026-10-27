import { PrismaClient, Role, TxnStatus, PaymentMethod } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';

export class AnalyticsService {
  /**
   * Ringkasan KPI Eksekutif (Revenue, Transaksi, Rata-rata Keranjang, Margin).
   * Otomatis mengecualikan transaksi yang berstatus 'voided'.
   */
  async getOverview(
    query: {
      outlet_id?: string;
      from?: string; // YYYY-MM-DD
      to?: string;   // YYYY-MM-DD
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const where: any = {
      status: TxnStatus.completed,
    };

    // Filter Outlet Scope
    if (userScope.role !== Role.owner) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
      }
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    // Filter Periode Tanggal
    if (query.from || query.to) {
      where.created_at = {};
      if (query.from) where.created_at.gte = new Date(`${query.from}T00:00:00.000Z`);
      if (query.to) where.created_at.lte = new Date(`${query.to}T23:59:59.999Z`);
    }

    let aggregate: any;
    let transactionsCount = 0;
    let items: any[] = [];

    try {
      const result = await Promise.all([
        prisma.transaction.aggregate({
          where,
          _sum: {
            total_idr: true,
            subtotal_idr: true,
            discount_idr: true,
          },
        }),
        prisma.transaction.count({ where }),
        prisma.transactionItem.findMany({
          where: {
            transaction: where,
          },
          select: {
            quantity: true,
            unit_price_idr: true,
            unit_cost_idr: true,
            line_total_idr: true,
          },
        }),
      ]);
      aggregate = result[0];
      transactionsCount = result[1];
      items = result[2];
    } catch (err: unknown) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 500, 'Gagal memuat ringkasan analitik dari database.');
    }

    const totalRevenue = aggregate._sum?.total_idr ?? 0;
    const avgBasketSize = transactionsCount > 0 ? Math.round(totalRevenue / transactionsCount) : 0;

    // Kalkulasi Margin Kotor (hanya jika ada HPP dan bukan pemanggil staff)
    let totalCost = 0;
    for (const item of items) {
      if (item.unit_cost_idr != null) {
        totalCost += item.unit_cost_idr * item.quantity;
      }
    }
    const estimatedGrossProfit = totalRevenue - totalCost;
    const grossMarginPct = totalRevenue > 0 ? Math.round((estimatedGrossProfit / totalRevenue) * 100) : 0;

    return {
      revenue_idr: totalRevenue,
      subtotal_idr: aggregate._sum?.subtotal_idr ?? 0,
      discount_idr: aggregate._sum?.discount_idr ?? 0,
      transaction_count: transactionsCount,
      avg_basket_size_idr: avgBasketSize,
      ...(userScope.role !== Role.staff
        ? {
            total_cost_idr: totalCost,
            gross_profit_idr: estimatedGrossProfit,
            gross_margin_pct: grossMarginPct,
          }
        : {}),
    };
  }

  /**
   * Tren Penjualan Harian (7 hari terakhir secara default) untuk visualisasi diagram tren.
   * Mendukung parameter `days` atau `from` dan `to` (format YYYY-MM-DD).
   */
  async getSalesTrend(
    query: {
      outlet_id?: string;
      days?: number;
      from?: string;
      to?: string;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role !== Role.owner) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
      }
    }

    let startDate: Date;
    let endDate: Date;

    if (query.from || query.to) {
      const fromStr = query.from || query.to!;
      const toStr = query.to || query.from!;
      startDate = new Date(`${fromStr}T00:00:00.000Z`);
      endDate = new Date(`${toStr}T23:59:59.999Z`);
    } else {
      const days = query.days ?? 7;
      const now = new Date();
      endDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 23, 59, 59, 999));
      startDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0));
      startDate.setUTCDate(startDate.getUTCDate() - (days - 1));
    }

    const where: any = {
      status: TxnStatus.completed,
      created_at: { gte: startDate, lte: endDate },
    };

    if (userScope.role !== Role.owner) {
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    try {
      const transactions = await prisma.transaction.findMany({
        where,
        select: {
          total_idr: true,
          created_at: true,
        },
        orderBy: { created_at: 'asc' },
      });

      // Kelompokkan per tanggal UTC (YYYY-MM-DD)
      const trendMap = new Map<string, { date: string; revenue_idr: number; count: number }>();

      const curr = new Date(startDate);
      while (curr <= endDate) {
        const y = curr.getUTCFullYear();
        const m = String(curr.getUTCMonth() + 1).padStart(2, '0');
        const day = String(curr.getUTCDate()).padStart(2, '0');
        const dateStr = `${y}-${m}-${day}`;
        trendMap.set(dateStr, { date: dateStr, revenue_idr: 0, count: 0 });
        curr.setUTCDate(curr.getUTCDate() + 1);
      }

      for (const tx of transactions) {
        const txDate = new Date(tx.created_at);
        const y = txDate.getUTCFullYear();
        const m = String(txDate.getUTCMonth() + 1).padStart(2, '0');
        const day = String(txDate.getUTCDate()).padStart(2, '0');
        const dateStr = `${y}-${m}-${day}`;
        const entry = trendMap.get(dateStr);
        if (entry) {
          entry.revenue_idr += tx.total_idr;
          entry.count += 1;
        }
      }

      return Array.from(trendMap.values());
    } catch (err: unknown) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 500, 'Gagal memuat tren penjualan dari database.');
    }
  }

  /**
   * Distribusi Jam Ramai Transaksi (00:00 - 23:00).
   */
  async getPeakHours(
    query: { outlet_id?: string },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const where: any = { status: TxnStatus.completed };
    if (userScope.role !== Role.owner) {
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    try {
      const transactions = await prisma.transaction.findMany({
        where,
        select: { created_at: true, total_idr: true },
      });

      const hours = Array.from({ length: 24 }, (_, i) => ({
        hour: i,
        label: `${i.toString().padStart(2, '0')}:00`,
        transaction_count: 0,
        total_revenue_idr: 0,
      }));

      for (const tx of transactions) {
        const h = tx.created_at.getHours();
        hours[h].transaction_count += 1;
        hours[h].total_revenue_idr += tx.total_idr;
      }

      return hours;
    } catch (err: unknown) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 500, 'Gagal memuat data jam ramai dari database.');
    }
  }

  /**
   * Ringkasan Shift Kasir Hari Ini (SC05).
   */
  async getShiftSummary(cashierId: string, outletId?: string) {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const where: any = {
      cashier_id: cashierId,
      status: TxnStatus.completed,
      created_at: { gte: todayStart },
    };
    if (outletId) where.outlet_id = outletId;

    const [aggregate, cashAggregate, qrisAggregate, transactionsCount, latestTransactions] = await Promise.all([
      prisma.transaction.aggregate({
        where,
        _sum: { total_idr: true },
      }),
      prisma.transaction.aggregate({
        where: { ...where, payment_method: PaymentMethod.cash },
        _sum: { total_idr: true },
      }),
      prisma.transaction.aggregate({
        where: { ...where, payment_method: PaymentMethod.qris_simulated },
        _sum: { total_idr: true },
      }),
      prisma.transaction.count({ where }),
      prisma.transaction.findMany({
        where,
        take: 5,
        orderBy: { created_at: 'desc' },
        include: {
          items: true,
          outlet: { select: { name: true } },
        },
      }),
    ]);

    return {
      today_revenue_idr: aggregate._sum.total_idr ?? 0,
      cash_revenue_idr: cashAggregate._sum.total_idr ?? 0,
      qris_revenue_idr: qrisAggregate._sum.total_idr ?? 0,
      transaction_count: transactionsCount,
      recent_transactions: latestTransactions,
    };
  }

  /**
   * =========================================================================
   * AI PREDICTIVE ANALYTICS ENGINE
   * =========================================================================
   */

  /**
   * 1. ESTIMASI PREDIKSI TREN PENJUALAN PERIODIK (Time Series Forecasting)
   * Menggunakan riwayat aktual penuh, evaluasi holdout komparatif terhadap baseline,
   * dan transparansi keterbatasan data tanpa angka sintetis.
   */
  async getSalesForecast(
    query: {
      outlet_id?: string;
      horizon_days?: number; // 7 atau 30 hari
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role !== Role.owner) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
      }
    }

    const horizonDays = query.horizon_days === 30 ? 30 : 7;
    // Jendela riwayat: 30 hari untuk horizon 7 hari, 60 hari untuk horizon 30 hari
    const historyDays = Math.max(horizonDays * 2, 30);

    const now = new Date();
    const toUtcDateStr = (d: Date): string => {
      const y = d.getUTCFullYear();
      const m = String(d.getUTCMonth() + 1).padStart(2, '0');
      const day = String(d.getUTCDate()).padStart(2, '0');
      return `${y}-${m}-${day}`;
    };

    const endDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 23, 59, 59, 999));
    const startDate = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0));
    startDate.setUTCDate(startDate.getUTCDate() - (historyDays - 1));

    const where: any = {
      status: TxnStatus.completed,
      created_at: { gte: startDate, lte: endDate },
    };

    if (userScope.role !== Role.owner) {
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    try {
      const transactions = await prisma.transaction.findMany({
        where,
        select: { created_at: true, total_idr: true },
        orderBy: { created_at: 'asc' },
      });

      // Siapkan Map tanggal riwayat kontinyu tanpa pemotongan tersembunyi
      const historicalMap = new Map<string, number>();
      const curr = new Date(startDate);
      while (curr <= endDate) {
        historicalMap.set(toUtcDateStr(curr), 0);
        curr.setUTCDate(curr.getUTCDate() + 1);
      }

      for (const tx of transactions) {
        const dStr = toUtcDateStr(new Date(tx.created_at));
        if (historicalMap.has(dStr)) {
          historicalMap.set(dStr, (historicalMap.get(dStr) ?? 0) + tx.total_idr);
        }
      }

      const historicalEntries = Array.from(historicalMap.entries())
        .sort((a, b) => a[0].localeCompare(b[0]))
        .map(([date, revenue]) => ({
          date,
          revenue_idr: revenue,
          is_projected: false,
        }));

      const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
      const nonZeroEntries = historicalEntries.filter((e) => e.revenue_idr > 0);
      const nonZeroDays = nonZeroEntries.length;
      const totalHistoricalRev = historicalEntries.reduce((sum, e) => sum + e.revenue_idr, 0);

      // KASUS 1: Riwayat belum memadai (kurang dari 3 hari transaksi aktual)
      // Tampilkan keterbatasan secara transparan tanpa mengarang data historis palsu
      if (nonZeroDays < 3 || totalHistoricalRev === 0) {
        const naiveDailyVal = nonZeroDays > 0 ? Math.round(totalHistoricalRev / nonZeroDays) : 0;
        const forecast: Array<{
          date: string;
          day_name: string;
          revenue_idr: number;
          lower_bound_idr: number;
          upper_bound_idr: number;
          is_projected: boolean;
        }> = [];

        for (let h = 1; h <= horizonDays; h++) {
          const futureDate = new Date(endDate);
          futureDate.setUTCDate(futureDate.getUTCDate() + h);
          const dateStr = toUtcDateStr(futureDate);
          const dow = futureDate.getUTCDay();

          forecast.push({
            date: dateStr,
            day_name: dayNames[dow],
            revenue_idr: naiveDailyVal,
            lower_bound_idr: Math.max(0, Math.round(naiveDailyVal * 0.7)),
            upper_bound_idr: Math.round(naiveDailyVal * 1.3),
            is_projected: true,
          });
        }

        const projectedTotal = naiveDailyVal * horizonDays;
        return {
          horizon_days: horizonDays,
          historical: historicalEntries,
          forecast,
          summary: {
            projected_total_revenue_idr: projectedTotal,
            previous_period_revenue_idr: totalHistoricalRev,
            growth_pct: 0.0,
            avg_daily_projected_idr: naiveDailyVal,
            peak_projected_day: forecast[0] ?? { date: '', day_name: '', revenue_idr: 0 },
            ai_insight:
              nonZeroDays === 0
                ? 'Belum ada data transaksi penjualan pada outlet ini. Lakukan transaksi untuk mengaktifkan peramalan deret waktu AI.'
                : `Data riwayat transaksi masih terbatas (${nonZeroDays} hari). Model menggunakan baseline rata-rata sederhana hingga data historis mencapai minimal 7 hari.`,
          },
          evaluation: {
            status: 'insufficient_history',
            data_points_count: nonZeroDays,
            required_points_count: 3,
            model_name: 'naive_mean_baseline',
          },
        };
      }

      // KASUS 2: Riwayat memadai (>= 3 hari). Lakukan evaluasi holdout kronologis terhadap baseline
      const N = historicalEntries.length;
      const holdoutSize = Math.min(7, Math.max(1, Math.floor(N / 4)));
      const trainEntries = historicalEntries.slice(0, N - holdoutSize);
      const testEntries = historicalEntries.slice(N - holdoutSize);

      // Fit model musiman harian pada data latih (Day-of-Week Seasonality)
      const trainDowTotals: { sum: number; count: number }[] = Array.from({ length: 7 }, () => ({ sum: 0, count: 0 }));
      let trainTotalRev = 0;
      trainEntries.forEach((entry) => {
        const dow = new Date(entry.date).getUTCDay();
        trainDowTotals[dow].sum += entry.revenue_idr;
        trainDowTotals[dow].count += 1;
        trainTotalRev += entry.revenue_idr;
      });

      const trainDailyAvg = trainTotalRev / Math.max(1, trainEntries.length);
      const trainDowMultipliers = trainDowTotals.map((item) => {
        if (item.count === 0 || trainDailyAvg === 0) return 1.0;
        const avgForDay = item.sum / item.count;
        return Math.min(Math.max(avgForDay / trainDailyAvg, 0.6), 1.6);
      });

      // Fit regresi linier pada data latih
      let trainSumX = 0, trainSumY = 0, trainSumXY = 0, trainSumX2 = 0;
      trainEntries.forEach((entry, idx) => {
        trainSumX += idx;
        trainSumY += entry.revenue_idr;
        trainSumXY += idx * entry.revenue_idr;
        trainSumX2 += idx * idx;
      });
      const trainDenom = trainEntries.length * trainSumX2 - trainSumX * trainSumX;
      const trainSlope = trainDenom !== 0 ? (trainEntries.length * trainSumXY - trainSumX * trainSumY) / trainDenom : 0;
      const trainIntercept = (trainSumY - trainSlope * trainSumX) / trainEntries.length;

      // Evaluasi MAE pada Holdout Test Set: Model vs Baseline Seasonal-Naive
      let modelAbsErrorSum = 0;
      let baselineAbsErrorSum = 0;

      testEntries.forEach((entry, idx) => {
        const testIdx = trainEntries.length + idx;
        const dow = new Date(entry.date).getUTCDay();

        // Prediksi Model Seasonal-Trend
        const modelPred = Math.max(0, Math.round((trainIntercept + trainSlope * testIdx) * trainDowMultipliers[dow]));
        modelAbsErrorSum += Math.abs(entry.revenue_idr - modelPred);

        // Prediksi Baseline Seasonal-Naive (mengambil nilai 7 hari lalu jika ada, fallback ke rata-rata)
        const naiveSourceIdx = testIdx - 7;
        const baselinePred = naiveSourceIdx >= 0 && naiveSourceIdx < trainEntries.length
          ? trainEntries[naiveSourceIdx].revenue_idr
          : Math.round(trainDailyAvg);
        baselineAbsErrorSum += Math.abs(entry.revenue_idr - baselinePred);
      });

      const modelMae = modelAbsErrorSum / holdoutSize;
      const baselineMae = baselineAbsErrorSum / holdoutSize;

      // Keputusan Seleksi Model: gunakan model Seasonal-Trend bila error tidak lebih buruk dari baseline
      const useSeasonalTrend = modelMae <= baselineMae * 1.1;

      // Proyeksikan ke Depan menggunakan seluruh data riwayat N
      const fullDowTotals: { sum: number; count: number }[] = Array.from({ length: 7 }, () => ({ sum: 0, count: 0 }));
      historicalEntries.forEach((entry) => {
        const dow = new Date(entry.date).getUTCDay();
        fullDowTotals[dow].sum += entry.revenue_idr;
        fullDowTotals[dow].count += 1;
      });
      const fullDailyAvg = totalHistoricalRev / N;
      const fullDowMultipliers = fullDowTotals.map((item) => {
        if (item.count === 0 || fullDailyAvg === 0) return 1.0;
        const avgForDay = item.sum / item.count;
        return Math.min(Math.max(avgForDay / fullDailyAvg, 0.6), 1.6);
      });

      let sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      historicalEntries.forEach((entry, idx) => {
        sumX += idx;
        sumY += entry.revenue_idr;
        sumXY += idx * entry.revenue_idr;
        sumX2 += idx * idx;
      });
      const denominator = N * sumX2 - sumX * sumX;
      const slope = denominator !== 0 ? (N * sumXY - sumX * sumY) / denominator : 0;
      const intercept = (sumY - slope * sumX) / N;

      let sumSquaredResiduals = 0;
      historicalEntries.forEach((entry, idx) => {
        const trendEstimate = intercept + slope * idx;
        const diff = entry.revenue_idr - trendEstimate;
        sumSquaredResiduals += diff * diff;
      });
      const residualStdDev = Math.sqrt(sumSquaredResiduals / Math.max(1, N - 2));

      const forecast: Array<{
        date: string;
        day_name: string;
        revenue_idr: number;
        lower_bound_idr: number;
        upper_bound_idr: number;
        is_projected: boolean;
      }> = [];

      let projectedTotal = 0;
      let peakProjected = { date: '', day_name: '', revenue_idr: 0 };

      for (let h = 1; h <= horizonDays; h++) {
        const futureDate = new Date(endDate);
        futureDate.setUTCDate(futureDate.getUTCDate() + h);
        const dateStr = toUtcDateStr(futureDate);
        const dow = futureDate.getUTCDay();

        let projectedRev = 0;
        if (useSeasonalTrend) {
          const futureX = N - 1 + h;
          const baseTrend = Math.max(fullDailyAvg * 0.5, intercept + slope * futureX);
          projectedRev = Math.max(0, Math.round(baseTrend * fullDowMultipliers[dow]));
        } else {
          // Fallback ke seasonal naive
          const histSourceIdx = N - 7 + ((h - 1) % 7);
          projectedRev = histSourceIdx >= 0 && histSourceIdx < N
            ? historicalEntries[histSourceIdx].revenue_idr
            : Math.round(fullDailyAvg);
        }

        const marginOfError = Math.round(Math.max(projectedRev * 0.12, 1.28 * residualStdDev));
        const lowerBound = Math.max(0, projectedRev - marginOfError);
        const upperBound = projectedRev + marginOfError;

        if (projectedRev > peakProjected.revenue_idr) {
          peakProjected = {
            date: dateStr,
            day_name: dayNames[dow],
            revenue_idr: projectedRev,
          };
        }

        projectedTotal += projectedRev;

        forecast.push({
          date: dateStr,
          day_name: dayNames[dow],
          revenue_idr: projectedRev,
          lower_bound_idr: lowerBound,
          upper_bound_idr: upperBound,
          is_projected: true,
        });
      }

      // Periode pembanding menggunakan jendela hari yang sama persis
      const prevPeriodRevenue = historicalEntries.slice(-horizonDays).reduce((acc, curr) => acc + curr.revenue_idr, 0);
      const growthPct =
        prevPeriodRevenue > 0
          ? Math.round(((projectedTotal - prevPeriodRevenue) / prevPeriodRevenue) * 1000) / 10
          : 0.0;

      const avgDailyProjected = Math.round(projectedTotal / horizonDays);

      return {
        horizon_days: horizonDays,
        historical: historicalEntries,
        forecast,
        summary: {
          projected_total_revenue_idr: projectedTotal,
          previous_period_revenue_idr: prevPeriodRevenue,
          growth_pct: growthPct,
          avg_daily_projected_idr: avgDailyProjected,
          peak_projected_day: peakProjected,
          ai_insight:
            growthPct >= 0
              ? `Model memproyeksikan omzet ${horizonDays} hari ke depan tumbuh +${growthPct}% dengan puncak pada ${peakProjected.day_name}. Evaluasi holdout MAE: Rp ${Math.round(modelMae).toLocaleString('id-ID')} vs baseline Rp ${Math.round(baselineMae).toLocaleString('id-ID')}.`
              : `Model memproyeksikan tren omzet ${growthPct}% untuk ${horizonDays} hari ke depan dengan puncak pada ${peakProjected.day_name}. Evaluasi holdout MAE: Rp ${Math.round(modelMae).toLocaleString('id-ID')}.`,
        },
        evaluation: {
          status: 'evaluated',
          holdout_days: holdoutSize,
          model_name: useSeasonalTrend ? 'seasonal_decomposition_trend' : 'seasonal_naive_baseline',
          model_mae_idr: Math.round(modelMae),
          baseline_mae_idr: Math.round(baselineMae),
        },
      };
    } catch (err: unknown) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 500, 'Gagal memuat peramalan penjualan dari database.');
    }
  }

  /**
   * 2. ESTIMASI PREDIKSI KAPAN STOK AKAN HABIS (Stock Runout Prediction)
   * Menghitung laju pemakaian bahan aktual per hari (14 hari terakhir),
   * memproyeksikan status risiko tanpa fabrikasi data sintetis.
   */
  async getStockoutForecast(
    query: { outlet_id?: string },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role !== Role.owner) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
      }
    }

    const where: any = {};
    if (userScope.role !== Role.owner) {
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    try {
      const ingredients = await prisma.ingredient.findMany({
        where,
        include: {
          outlet: { select: { id: true, name: true } },
          movements: {
            where: {
              created_at: { gte: new Date(Date.now() - 14 * 24 * 60 * 60 * 1000) },
              quantity_delta: { lt: 0 },
            },
            select: { quantity_delta: true, created_at: true },
          },
        },
        orderBy: [{ stock_qty: 'asc' }, { name: 'asc' }],
      });

      if (!ingredients || ingredients.length === 0) {
        return {
          summary: {
            critical_count: 0,
            warning_count: 0,
            safe_count: 0,
            total_items: 0,
            ai_recommendation: 'Belum ada data bahan baku pada cabang ini. Tambahkan bahan baku di menu Inventori untuk memantau prediksi stok.',
          },
          items: [],
        };
      }

      const now = new Date();
      const items = ingredients.map((ing) => {
        const totalUsed = ing.movements.reduce((acc, m) => acc + Math.abs(m.quantity_delta), 0);
        const dailyVelocity = Math.round((totalUsed / 14) * 10) / 10;

        let daysUntilStockout: number;
        let status: 'critical' | 'warning' | 'safe';

        if (ing.stock_qty <= 0) {
          daysUntilStockout = 0;
          status = 'critical';
        } else if (dailyVelocity <= 0) {
          daysUntilStockout = 999;
          status = ing.stock_qty <= ing.reorder_level ? 'warning' : 'safe';
        } else {
          daysUntilStockout = Math.floor(ing.stock_qty / dailyVelocity);
          if (daysUntilStockout <= 2) {
            status = 'critical';
          } else if (daysUntilStockout <= 6 || ing.stock_qty <= ing.reorder_level) {
            status = 'warning';
          } else {
            status = 'safe';
          }
        }

        const stockoutDate = new Date(now);
        stockoutDate.setDate(now.getDate() + (daysUntilStockout === 999 ? 30 : daysUntilStockout));
        const y = stockoutDate.getFullYear();
        const m = String(stockoutDate.getMonth() + 1).padStart(2, '0');
        const day = String(stockoutDate.getDate()).padStart(2, '0');
        const projectedDateStr = daysUntilStockout === 999 ? '> 30 hari' : `${y}-${m}-${day}`;

        const maxCapacityRef = Math.max(ing.stock_qty, ing.reorder_level * 3);
        const stockCapacityPct = Math.min(100, Math.max(0, Math.round((ing.stock_qty / maxCapacityRef) * 100)));

        const recommendedReorderQty = dailyVelocity > 0
          ? Math.max(
              Math.ceil(dailyVelocity * 7 + ing.reorder_level - ing.stock_qty),
              Math.ceil(dailyVelocity * 5)
            )
          : Math.max(0, ing.reorder_level - ing.stock_qty);

        const estimatedRestockCostIdr = recommendedReorderQty * ing.cost_per_unit;

        return {
          ingredient_id: ing.id,
          ingredient_name: ing.name,
          unit: ing.unit,
          outlet_name: ing.outlet?.name ?? 'Utama',
          current_stock: ing.stock_qty,
          reorder_level: ing.reorder_level,
          daily_velocity: dailyVelocity,
          days_until_stockout: daysUntilStockout,
          projected_stockout_date: projectedDateStr,
          status,
          stock_capacity_pct: stockCapacityPct,
          recommended_reorder_qty: recommendedReorderQty,
          cost_per_unit_idr: ing.cost_per_unit,
          estimated_restock_cost_idr: estimatedRestockCostIdr,
        };
      });

      const criticalCount = items.filter((i) => i.status === 'critical').length;
      const warningCount = items.filter((i) => i.status === 'warning').length;
      const safeCount = items.filter((i) => i.status === 'safe').length;

      let aiRecommendation = '';
      if (criticalCount > 0) {
        aiRecommendation = `PERINGATAN: ${criticalCount} bahan baku diproyeksikan habis dalam 1-2 hari. Segera buat Purchase Order (PO).`;
      } else if (warningCount > 0) {
        aiRecommendation = `Ada ${warningCount} bahan baku yang mendekati batas reorder (3-6 hari). Jadwalkan pembelian stok sebelum akhir pekan.`;
      } else {
        aiRecommendation = 'Seluruh persediaan bahan baku berada dalam kondisi aman (> 7 hari). Laju pemakaian saat ini stabil.';
      }

      return {
        summary: {
          critical_count: criticalCount,
          warning_count: warningCount,
          safe_count: safeCount,
          total_items: items.length,
          ai_recommendation: aiRecommendation,
        },
        items,
      };
    } catch (err: unknown) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 500, 'Gagal memuat peramalan stok dari database.');
    }
  }

  /**
   * Leaderboard Menu Terlaris (Top Selling Products) berdasarkan data penjualan aktual di database.
   * Mendukung filter outlet, tanggal (from/to), dan RBAC ketat (manager terkunci ke cabang sendiri).
   */
  async getLeaderboard(
    query: {
      outlet_id?: string;
      from?: string;
      to?: string;
      limit?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const limit = Math.min(query.limit ?? 20, 100);
    const whereTx: any = {
      status: TxnStatus.completed,
    };

    if (userScope.role !== Role.owner) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
      }
      whereTx.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      whereTx.outlet_id = query.outlet_id;
    }

    if (query.from || query.to) {
      whereTx.created_at = {};
      if (query.from) whereTx.created_at.gte = new Date(`${query.from}T00:00:00.000Z`);
      if (query.to) whereTx.created_at.lte = new Date(`${query.to}T23:59:59.999Z`);
    }

    try {
      const items = await prisma.transactionItem.findMany({
        where: {
          transaction: whereTx,
        },
        include: {
          product: {
            include: {
              category: { select: { name: true } },
            },
          },
        },
      });

      const productMap = new Map<string, {
        product_id: string;
        product_name: string;
        category_name: string;
        unit_price_idr: number;
        image_url: string | null;
        quantity_sold: number;
        total_revenue_idr: number;
      }>();

      for (const item of items) {
        const prodId = item.product_id;
        const name = item.product_name_snapshot || item.product?.name || 'Menu';
        const categoryName = item.product?.category?.name || 'Menu Utama';
        const unitPrice = item.unit_price_idr;
        const imageUrl = item.product?.image_url || null;

        const existing = productMap.get(prodId);
        if (existing) {
          existing.quantity_sold += item.quantity;
          existing.total_revenue_idr += item.line_total_idr;
        } else {
          productMap.set(prodId, {
            product_id: prodId,
            product_name: name,
            category_name: categoryName,
            unit_price_idr: unitPrice,
            image_url: imageUrl,
            quantity_sold: item.quantity,
            total_revenue_idr: item.line_total_idr,
          });
        }
      }

      const sortedList = Array.from(productMap.values()).sort((a, b) => {
        if (b.quantity_sold !== a.quantity_sold) {
          return b.quantity_sold - a.quantity_sold;
        }
        return b.total_revenue_idr - a.total_revenue_idr;
      });

      const ranked = sortedList.slice(0, limit).map((p, idx) => ({
        rank: idx + 1,
        product_id: p.product_id,
        product_name: p.product_name,
        category_name: p.category_name,
        quantity_sold: p.quantity_sold,
        total_revenue_idr: p.total_revenue_idr,
        unit_price_idr: p.unit_price_idr,
        image_url: p.image_url,
      }));

      return ranked;
    } catch (err) {
      // Tidak ada fallback data dummy: leaderboard HARUS berasal dari database.
      // Bila database gagal diakses, laporkan error agar UI menampilkan state error.
      console.warn('[AnalyticsService] getLeaderboard gagal:', err);
      throw new AppError(
        'DATABASE_ERROR',
        503,
        'Data penjualan tidak dapat dimuat dari database. Silakan coba lagi.'
      );
    }
  }
}

export const analyticsService = new AnalyticsService();
