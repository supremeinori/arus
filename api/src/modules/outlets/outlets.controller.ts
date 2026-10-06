import { Request, Response, NextFunction } from 'express';
import { OutletsService } from './outlets.service';
import {
  createOutletSchema,
  updateOutletSchema,
  nearestOutletQuerySchema,
} from './outlets.schema';

const outletsService = new OutletsService();

export class OutletsController {
  async list(req: Request, res: Response, next: NextFunction) {
    try {
      const user = (req as any).user;
      const userOutlets = (req as any).userOutlets || [];
      const outlets = await outletsService.listOutlets(user, userOutlets);

      res.json({
        success: true,
        data: outlets,
      });
    } catch (err) {
      next(err);
    }
  }

  async getById(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const outlet = await outletsService.getOutletById(id);

      res.json({
        success: true,
        data: outlet,
      });
    } catch (err) {
      next(err);
    }
  }

  async create(req: Request, res: Response, next: NextFunction) {
    try {
      const validated = createOutletSchema.parse(req.body);
      const outlet = await outletsService.createOutlet(validated);

      res.status(201).json({
        success: true,
        message: 'Outlet berhasil ditambahkan.',
        data: outlet,
      });
    } catch (err) {
      next(err);
    }
  }

  async update(req: Request, res: Response, next: NextFunction) {
    try {
      const { id } = req.params;
      const validated = updateOutletSchema.parse(req.body);
      const outlet = await outletsService.updateOutlet(id, validated);

      res.json({
        success: true,
        message: 'Informasi outlet berhasil diperbarui.',
        data: outlet,
      });
    } catch (err) {
      next(err);
    }
  }

  async performance(req: Request, res: Response, next: NextFunction) {
    try {
      const performance = await outletsService.getOutletsPerformance();

      res.json({
        success: true,
        data: performance,
      });
    } catch (err) {
      next(err);
    }
  }

  async nearest(req: Request, res: Response, next: NextFunction) {
    try {
      const { lat, lng } = nearestOutletQuerySchema.parse(req.query);
      const result = await outletsService.getNearestOutlet(lat, lng);

      res.json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }
}
