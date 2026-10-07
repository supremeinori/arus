import { Request, Response, NextFunction } from 'express';
import { integrityService } from './integrity.service';

export class IntegrityController {
  getChainForOutlet(req: Request, res: Response, next: NextFunction): void {
    try {
      const { outletId } = req.params;
      const chain = integrityService.getChainForOutlet(outletId || 'out-001');
      res.status(200).json({ data: chain });
    } catch (err) {
      next(err);
    }
  }

  verifyTransaction(req: Request, res: Response, next: NextFunction): void {
    try {
      const { id } = req.params;
      const result = integrityService.verifyTransaction(id);
      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  verifyReport(req: Request, res: Response, next: NextFunction): void {
    try {
      const { id } = req.params;
      const result = integrityService.verifyReport(id);
      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const integrityController = new IntegrityController();
