import { Request, Response, NextFunction } from 'express';
import { inventoryService } from './inventory.service';
import { MovementType } from '@prisma/client';

export class InventoryController {
  async getIngredients(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, status, q, page, page_size } = req.query;

      const result = await inventoryService.listIngredients(
        {
          outlet_id: outlet_id as string,
          status: status as 'ok' | 'low' | 'out',
          q: q as string,
          page: page ? parseInt(page as string, 10) : undefined,
          page_size: page_size ? parseInt(page_size as string, 10) : undefined,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data: result.ingredients, stocks: result.stocks, meta: result.meta });
    } catch (err) {
      next(err);
    }
  }

  async createIngredient(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, name, unit, stock_qty, reorder_level, cost_per_unit } = req.body;

      const result = await inventoryService.createIngredient(
        user.id,
        {
          outlet_id,
          name,
          unit,
          stock_qty: stock_qty !== undefined ? Number(stock_qty) : undefined,
          reorder_level: reorder_level !== undefined ? Number(reorder_level) : undefined,
          cost_per_unit: cost_per_unit !== undefined ? Number(cost_per_unit) : undefined,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async updateIngredient(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { id } = req.params;
      const { name, unit, reorder_level, cost_per_unit } = req.body;

      const result = await inventoryService.updateIngredient(
        user.id,
        id,
        {
          name,
          unit,
          reorder_level: reorder_level !== undefined ? Number(reorder_level) : undefined,
          cost_per_unit: cost_per_unit !== undefined ? Number(cost_per_unit) : undefined,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async deleteIngredient(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { id } = req.params;

      const result = await inventoryService.deleteIngredient(user.id, id, {
        role: user.role,
        allowedOutletIds,
      });

      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async createAdjustment(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, ingredient_id, product_id, movement_type, quantity_delta, note } = req.body;

      const result = await inventoryService.createAdjustment(
        user.id,
        {
          outlet_id,
          ingredient_id,
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
      const { outlet_id, ingredient_id, product_id, movement_type, page, page_size } = req.query;

      const result = await inventoryService.listMovements(
        {
          outlet_id: outlet_id as string,
          ingredient_id: ingredient_id as string,
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
