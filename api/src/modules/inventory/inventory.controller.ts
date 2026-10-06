import { Request, Response, NextFunction } from 'express';
import { inventoryService } from './inventory.service';
import { MovementType } from '@prisma/client';

export class InventoryController {
  async getStocks(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, low_stock, category_id, q, page, page_size } = req.query;

      const result = await inventoryService.listStocks(
        {
          outlet_id: outlet_id as string,
          low_stock: low_stock === 'true',
          category_id: category_id as string,
          q: q as string,
          page: page ? parseInt(page as string, 10) : undefined,
          page_size: page_size ? parseInt(page_size as string, 10) : undefined,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data: result.stocks, meta: result.meta });
    } catch (err) {
      next(err);
    }
  }

  async createAdjustment(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, product_id, movement_type, quantity_delta, note } = req.body;

      const result = await inventoryService.createAdjustment(
        user.id,
        {
          outlet_id,
          product_id,
          movement_type: movement_type as MovementType,
          quantity_delta: Number(quantity_delta),
          note,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async getMovements(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, product_id, movement_type, page, page_size } = req.query;

      const result = await inventoryService.listMovements(
        {
          outlet_id: outlet_id as string,
          product_id: product_id as string,
          movement_type: movement_type as MovementType,
          page: page ? parseInt(page as string, 10) : undefined,
          page_size: page_size ? parseInt(page_size as string, 10) : undefined,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data: result.movements, meta: result.meta });
    } catch (err) {
      next(err);
    }
  }
}

export const inventoryController = new InventoryController();
