import { Request, Response, NextFunction } from 'express';
import { insightsService } from './insights.service';
import { InsightSeverity, InsightStatus } from '@prisma/client';

export class InsightsController {
  async generate(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const result = await insightsService.generateInsights();
      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async list(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, severity, status } = req.query;

      const data = await insightsService.listInsights(
        {
          outlet_id: outlet_id as string,
          severity: severity as InsightSeverity,
          status: status as InsightStatus,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  async updateStatus(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { id } = req.params;
      const { status } = req.body;

      const updated = await insightsService.updateStatus(id, status as InsightStatus);
      res.status(200).json({ data: updated });
    } catch (err) {
      next(err);
    }
  }
}

export const insightsController = new InsightsController();
