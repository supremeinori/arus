import { Request, Response, NextFunction } from 'express';
import { ReportsService } from './reports.service';
import { generateReportSchema } from './reports.schema';
import { ReportType } from '@prisma/client';

const reportsService = new ReportsService();

export class ReportsController {
  async generateReport(req: Request, res: Response, next: NextFunction) {
    try {
      const validated = generateReportSchema.parse(req.body);
      const userId = (req as any).user.id;

      const report = await reportsService.generateReport(userId, validated);

      res.status(201).json({
        success: true,
        message: 'Laporan berhasil dibuat dan diamankan dengan payload hash tamper-evident.',
        data: report,
      });
    } catch (err) {
      next(err);
    }
  }

  async getReports(req: Request, res: Response, next: NextFunction) {
    try {
      const { outlet_id, type } = req.query;

      const reports = await reportsService.getReports({
        outlet_id: outlet_id as string | undefined,
        type: type as ReportType | undefined,
      });

      res.json({
        success: true,
        data: reports,
      });
    } catch (err) {
      next(err);
    }
  }

  async getReportById(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const report = await reportsService.getReportById(id);

      res.json({
        success: true,
        data: report,
      });
    } catch (err) {
      next(err);
    }
  }

  async verifyReport(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const result = await reportsService.verifyReport(id);

      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}
