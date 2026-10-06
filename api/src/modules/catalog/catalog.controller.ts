import { Request, Response, NextFunction } from 'express';
import { catalogService } from './catalog.service';
import {
  createCategorySchema,
  updateCategorySchema,
  createProductSchema,
  updateProductSchema,
  productQuerySchema,
} from './catalog.schema';

// ----------------------------------------------------
// CATEGORIES
// ----------------------------------------------------
export async function listCategories(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await catalogService.listCategories();
    res.status(200).json({ data });
  } catch (err) {
    next(err);
  }
}

export async function createCategory(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const body = createCategorySchema.parse(req.body);
    const data = await catalogService.createCategory(body.name);
    res.status(201).json({ data });
  } catch (err) {
    next(err);
  }
}

export async function updateCategory(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const body = updateCategorySchema.parse(req.body);
    const data = await catalogService.updateCategory(req.params.id, body.name);
    res.status(200).json({ data });
  } catch (err) {
    next(err);
  }
}

// ----------------------------------------------------
// PRODUCTS
// ----------------------------------------------------
export async function listProducts(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const query = productQuerySchema.parse(req.query);
    const result = await catalogService.listProducts(req.user!.role, query);
    res.status(200).json({ data: result.products, meta: result.meta });
  } catch (err) {
    next(err);
  }
}

export async function getProductById(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const data = await catalogService.getProductById(req.params.id, req.user!.role);
    res.status(200).json({ data });
  } catch (err) {
    next(err);
  }
}

export async function createProduct(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const body = createProductSchema.parse(req.body);
    const data = await catalogService.createProduct(req.user!.id, body);
    res.status(201).json({ data });
  } catch (err) {
    next(err);
  }
}

export async function updateProduct(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const body = updateProductSchema.parse(req.body);
    const data = await catalogService.updateProduct(req.params.id, body);
    res.status(200).json({ data });
  } catch (err) {
    next(err);
  }
}
