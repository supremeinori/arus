import { PrismaClient, Role, TxnStatus, PaymentMethod } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import { getStartOfDayInTimezone, getEndOfDayInTimezone } from '../../shared/timezone';

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
    let tz = 'Asia/Jakarta';
    let resolvedOutletId = outletId;

    if (resolvedOutletId) {
      const outlet = await prisma.outlet.findUnique({
        where: { id: resolvedOutletId },
        select: { timezone: true },
      });
      if (outlet?.timezone) tz = outlet.timezone;
    } else {
      const userOutlet = await prisma.userOutlet.findFirst({
        where: { user_id: cashierId },
        include: { outlet: { select: { id: true, timezone: true } } },
      });
      if (userOutlet?.outlet?.timezone) tz = userOutlet.outlet.timezone;
      if (userOutlet?.outlet?.id && !resolvedOutletId) resolvedOutletId = userOutlet.outlet.id;
    }

    const todayStart = getStartOfDayInTimezone(tz);
    const todayEnd = getEndOfDayInTimezone(tz);

    const where: any = {
      cashier_id: cashierId,
      status: TxnStatus.completed,
      created_at: { gte: todayStart, lte: todayEnd },
    };
    if (resolvedOutletId) where.outlet_id = resolvedOutletId;

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
    // Jendela riwayat cukup panjang agar tren dan musiman punya konteks.
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

      // Kalender kontinu: setiap hari di jendela riwayat selalu ada, termasuk hari bernilai 0.
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
      const totalHistoricalRev = historicalEntries.reduce((sum, e) => sum + e.revenue_idr, 0);
      const activeDays = historicalEntries.filter((e) => e.revenue_idr > 0).length;

      // KASUS 1: Belum ada transaksi sama sekali. Tidak ada angka sintetis.
      if (activeDays === 0 || totalHistoricalRev === 0) {
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
            revenue_idr: 0,
            lower_bound_idr: 0,
            upper_bound_idr: 0,
            is_projected: true,
          });
        }

        return {
          horizon_days: horizonDays,
          historical: historicalEntries,
          forecast,
          summary: {
            projected_total_revenue_idr: 0,
            previous_period_revenue_idr: 0,
            growth_pct: 0.0,
            avg_daily_projected_idr: 0,
            peak_projected_day: forecast[0] ?? { date: '', day_name: '', revenue_idr: 0 },
            ai_insight:
              'Belum ada data transaksi penjualan pada outlet ini. Lakukan transaksi kasir untuk mengaktifkan peramalan deret waktu.',
          },
          evaluation: {
            status: 'insufficient_history',
            data_points_count: 0,
            required_points_count: 1,
            model_name: 'zero_baseline',
            active_history_days: 0,
            trailing_zero_days: 0,
            confidence: 'low',
          },
        };
      }

      // Hari berjalan (parsial) dikeluarkan dari pemodelan agar omzet setengah hari
      // tidak menekan baseline. Hari selesai tetap dipakai, termasuk yang bernilai 0.
      let modelEntries = historicalEntries.slice(0, historicalEntries.length - 1);
      if (modelEntries.length === 0 || modelEntries.every((e) => e.revenue_idr === 0)) {
        modelEntries = historicalEntries.slice();
      }

      // Mulai dari hari penjualan pertama agar nol sebelum toko buka tidak menggeser tren.
      const firstActiveIdx = modelEntries.findIndex((e) => e.revenue_idr > 0);
      const win = modelEntries.slice(Math.max(0, firstActiveIdx));
      const winValues = win.map((e) => e.revenue_idr);
      const winDays = winValues.length;

      // 1. Base level recency-aware: EWMA (alpha 0.35). Hari 0 ikut menurunkan baseline.
      const alpha = 0.35;
      let ewma = winValues[0] ?? 0;
      for (let i = 1; i < winDays; i++) {
        ewma = alpha * winValues[i] + (1 - alpha) * ewma;
      }
      const overallAvg = winDays > 0 ? winValues.reduce((a, b) => a + b, 0) / winDays : 0;
      const baseLevel = Math.max(1, Math.round(ewma));

      // 2. Musiman day-of-week dengan Bayesian shrinkage (termasuk hari 0).
      const rawRetailPrior = [1.25, 0.82, 0.87, 0.92, 0.97, 1.16, 1.35]; // Minggu..Sabtu
      const sumPrior = rawRetailPrior.reduce((a, b) => a + b, 0);
      const retailPrior = rawRetailPrior.map((p) => p / (sumPrior / 7.0));
      const dowMultipliers: number[] = new Array<number>(7).fill(1);
      for (let d = 0; d < 7; d++) {
        let sum = 0;
        let count = 0;
        win.forEach((entry) => {
          if (new Date(entry.date).getUTCDay() === d) {
            sum += entry.revenue_idr;
            count += 1;
          }
        });
        const dowAvg = count > 0 ? sum / count : overallAvg;
        const empMult = overallAvg > 0 ? dowAvg / overallAvg : 1.0;
        const credibility = count / (count + 5.0);
        const blended = credibility * empMult + (1.0 - credibility) * retailPrior[d];
        dowMultipliers[d] = Math.min(1.8, Math.max(0.6, blended));
      }

      // 3. Tren linear pada indeks kalender (14 hari selesai terakhir, hari 0 ikut).
      const regWindow = Math.min(winDays, 14);
      const regStart = winDays - regWindow;
      let slope = 0;
      if (regWindow >= 3) {
        let sumX = 0;
        let sumY = 0;
        let sumXY = 0;
        let sumXX = 0;
        for (let i = 0; i < regWindow; i++) {
          const v = winValues[regStart + i];
          sumX += i;
          sumY += v;
          sumXY += i * v;
          sumXX += i * i;
        }
        const denom = regWindow * sumXX - sumX * sumX;
        const rawSlope = denom !== 0 ? (regWindow * sumXY - sumX * sumY) / denom : 0;
        const maxSlope = 0.06 * baseLevel;
        slope = Math.min(maxSlope, Math.max(-maxSlope, rawSlope));
      }

      // 4. Drought factor: makin lama 0 berturut-turut, proyeksi makin ditekan.
      let streakZero = 0;
      for (let i = winValues.length - 1; i >= 0; i--) {
        if (winValues[i] === 0) {
          streakZero += 1;
        } else {
          break;
        }
      }
      let drought = 1.0;
      if (streakZero >= 2) {
        drought = Math.pow(0.7, Math.min(streakZero - 1, 6));
      } else if (streakZero === 1) {
        drought = 0.85;
      }

      // 5. Volatilitas residual untuk confidence interval (kalender, hari 0 ikut).
      let residualSumSq = 0;
      for (let i = 0; i < regWindow; i++) {
        const entry = win[regStart + i];
        const dow = new Date(entry.date).getUTCDay();
        const expected = (baseLevel + slope * (i - (regWindow - 1) / 2)) * dowMultipliers[dow];
        const diff = entry.revenue_idr - expected;
        residualSumSq += diff * diff;
      }
      const sampleStdDev = Math.sqrt(residualSumSq / Math.max(1, regWindow - 1));
      const baseStdDev = Math.max(baseLevel * 0.12, sampleStdDev);

      const confidence = activeDays < 3 ? 'low' : activeDays < 7 ? 'medium' : 'normal';

      const forecast: Array<{
        date: string;
        day_name: string;
        revenue_idr: number;
        lower_bound_idr: number;
        upper_bound_idr: number;
        is_projected: boolean;
      }> = [];

      let projectedTotal = 0;
      let peakProjected = { date: '', day_name: '', revenue_idr: -1 };
      const phi = 0.92; // Faktor peredaman tren Holt

      for (let h = 1; h <= horizonDays; h++) {
        const futureDate = new Date(endDate);
        futureDate.setUTCDate(futureDate.getUTCDate() + h);
        const dateStr = toUtcDateStr(futureDate);
        const dow = futureDate.getUTCDay();

        const dampenedTrend = slope * ((phi * (1.0 - Math.pow(phi, h))) / (1.0 - phi));
        const trendBase = Math.max(baseLevel * 0.4, baseLevel + dampenedTrend);
        const projectedRev = Math.max(0, Math.round(trendBase * dowMultipliers[dow] * drought));

        const horizonUncertainty = Math.sqrt(1.0 + 0.05 * (h - 1));
        const marginOfError = Math.round(Math.max(projectedRev * 0.12, 1.28 * baseStdDev * horizonUncertainty));
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

      // Growth dibandingkan dengan horizon hari selesai terakhir (bukan angka sintetis).
      const prevPeriodRevenue = modelEntries
        .slice(-horizonDays)
        .reduce((acc, e) => acc + e.revenue_idr, 0);
      const growthPct =
        prevPeriodRevenue > 0
          ? Math.round(((projectedTotal - prevPeriodRevenue) / prevPeriodRevenue) * 1000) / 10
          : 0.0;
      const avgDailyProjected = Math.round(projectedTotal / horizonDays);
      const growthSign = growthPct >= 0 ? '+' : '';

      let aiInsight: string;
      if (streakZero >= 2) {
        aiInsight = `${streakZero} hari terakhir tanpa transaksi. Model menurunkan proyeksi omzet ${horizonDays} hari ke depan menjadi Rp ${projectedTotal.toLocaleString('id-ID')} (${growthSign}${growthPct}% vs ${horizonDays} hari terakhir).`;
      } else if (activeDays < 7) {
        aiInsight = `Model memadukan data aktif ${activeDays} hari dengan pola musiman ritel (puncak ${peakProjected.day_name}). Estimasi omzet ${horizonDays} hari ke depan Rp ${projectedTotal.toLocaleString('id-ID')} (${growthSign}${growthPct}% vs ${horizonDays} hari terakhir).`;
      } else {
        aiInsight = `Model memproyeksikan omzet ${horizonDays} hari ke depan Rp ${projectedTotal.toLocaleString('id-ID')} (${growthSign}${growthPct}% vs ${horizonDays} hari terakhir) dengan puncak pada ${peakProjected.day_name} (Rp ${peakProjected.revenue_idr.toLocaleString('id-ID')}).`;
      }

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
          ai_insight: aiInsight,
        },
        evaluation: {
          status: 'evaluated',
          data_points_count: activeDays,
          required_points_count: 1,
          model_name: 'ewma_bayesian_seasonal_dampened',
          active_history_days: activeDays,
          estimated_base_level_idr: baseLevel,
          trailing_zero_days: streakZero,
          confidence,
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
