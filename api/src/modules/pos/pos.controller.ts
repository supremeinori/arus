import { Request, Response, NextFunction } from 'express';
import { posService } from './pos.service';
import { posCatalogQuerySchema, posCheckoutSchema, posVoidSchema } from './pos.schema';
import { verifyOutletScope } from '../../middleware/auth';

export class PosController {
  async getCatalog(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const query = posCatalogQuerySchema.parse(req.query);
      verifyOutletScope(req, query.outlet_id);
      const data = await posService.getCatalog(query.outlet_id, {
        role: req.user!.role,
        allowedOutletIds: req.userOutlets || [],
      });
      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  async checkout(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const body = posCheckoutSchema.parse(req.body);
      verifyOutletScope(req, body.outlet_id);
      const data = await posService.checkout(
        req.user!.id,
        { ...body, cashier_id: (req.body as { cashier_id?: string }).cashier_id },
        { role: req.user!.role, allowedOutletIds: req.userOutlets || [] }
      );
      res.status(201).json({ data });
    } catch (err) {
      next(err);
    }
  }

  async voidTransaction(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const body = posVoidSchema.parse(req.body);
      if (body.outlet_id) verifyOutletScope(req, body.outlet_id);
      const data = await posService.voidTransaction(
        body.transaction_id,
        req.user!.id,
        body.reason,
        req.user!.role
      );
      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }
}

export const posController = new PosController();
