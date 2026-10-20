import { Router } from 'express';
import { analyticsController } from './analytics.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();

// Proteksi token untuk seluruh endpoint analitik
router.use('/analytics', requireAuth);

// 1. GET /api/analytics/overview - Ringkasan KPI Eksekutif (Revenue, Transaksi, Basket Size, Margin)
router.get('/analytics/overview', (req, res, next) => analyticsController.getOverview(req, res, next));

// 2. GET /api/analytics/sales-trend - Tren penjualan harian (Grafik 7 / 30 hari)
router.get('/analytics/sales-trend', (req, res, next) => analyticsController.getSalesTrend(req, res, next));

// 3. GET /api/analytics/peak-hours - Distribusi jam ramai transaksi
router.get('/analytics/peak-hours', (req, res, next) => analyticsController.getPeakHours(req, res, next));

// 4. GET /api/analytics/shift-summary - Ringkasan shift kerja kasir (hari ini)
router.get('/analytics/shift-summary', (req, res, next) => analyticsController.getShiftSummary(req, res, next));

// 5. GET /api/analytics/forecast/sales - AI Time Series Sales Forecasting (7 / 30 hari ke depan)
router.get('/analytics/forecast/sales', (req, res, next) => analyticsController.getSalesForecast(req, res, next));

// 6. GET /api/analytics/forecast/stockout - AI Stock Runout & Velocity Prediction
router.get('/analytics/forecast/stockout', (req, res, next) => analyticsController.getStockoutForecast(req, res, next));

export default router;
