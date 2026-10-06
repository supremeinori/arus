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
      const { outlet_id, days } = req.query;

      const data = await analyticsService.getSalesTrend(
        {
          outlet_id: outlet_id as string,
          days: days ? parseInt(days as string, 10) : undefined,
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
}

export const analyticsController = new AnalyticsController();
