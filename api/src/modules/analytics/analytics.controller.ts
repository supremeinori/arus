import { Request, Response, NextFunction } from 'express';
import { analyticsService } from './analytics.service';

export class AnalyticsController {
  async getOverview(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, from, to } = req.query;

      const data = await analyticsService.getOverview(
        {
          outlet_id: outlet_id as string,
          from: from as string,
          to: to as string,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  async getSalesTrend(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, days, from, to } = req.query;

      const data = await analyticsService.getSalesTrend(
        {
          outlet_id: outlet_id as string,
          days: days ? parseInt(days as string, 10) : undefined,
          from: from as string,
          to: to as string,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  async getPeakHours(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id } = req.query;

      const data = await analyticsService.getPeakHours(
        { outlet_id: outlet_id as string },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  async getShiftSummary(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const { outlet_id } = req.query;

      const data = await analyticsService.getShiftSummary(user.id, outlet_id as string);

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/analytics/forecast/sales
   * Prediksi tren penjualan masa depan (minggu depan / bulan depan).
   */
  async getSalesForecast(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, horizon } = req.query;

      const horizonDays = horizon ? parseInt(horizon as string, 10) : 7;
      const data = await analyticsService.getSalesForecast(
        {
          outlet_id: outlet_id as string,
          horizon_days: horizonDays,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/analytics/forecast/stockout
   * Prediksi sisa waktu sampai stok habis (stock runout date).
   */
  async getStockoutForecast(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id } = req.query;

      const data = await analyticsService.getStockoutForecast(
        { outlet_id: outlet_id as string },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  /**
   * GET /api/analytics/leaderboard
   * Leaderboard menu terlaris berdasarkan data penjualan aktual di database.
   */
  async getLeaderboard(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, from, to, limit } = req.query;

      const data = await analyticsService.getLeaderboard(
        {
          outlet_id: outlet_id as string,
          from: from as string,
          to: to as string,
          limit: limit ? parseInt(limit as string, 10) : undefined,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }
}

export const analyticsController = new AnalyticsController();
