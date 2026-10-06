import { z } from 'zod';

export const createCategorySchema = z.object({
  name: z.string().min(1).max(100),
});

export const updateCategorySchema = z.object({
  name: z.string().min(1).max(100),
});

export const createProductSchema = z.object({
  name: z.string().min(1).max(120),
  sku: z.string().min(1).max(40),
  unit: z.string().min(1).max(20).default('pcs'),
  price_idr: z.number().int().positive('Harga jual harus lebih dari 0'),
  cost_idr: z.number().int().nonnegative('HPP tidak boleh negatif').optional(),
  category_id: z.string().uuid().optional(),
});

export const updateProductSchema = z.object({
  name: z.string().min(1).max(120).optional(),
  sku: z.string().min(1).max(40).optional(),
  unit: z.string().min(1).max(20).optional(),
  price_idr: z.number().int().positive().optional(),
  cost_idr: z.number().int().nonnegative().optional(),
  category_id: z.string().uuid().nullable().optional(),
  is_active: z.boolean().optional(),
});

export const productQuerySchema = z.object({
  category_id: z.string().uuid().optional(),
  is_active: z.enum(['true', 'false']).optional(),
  q: z.string().optional(),
  sort: z.enum(['name', 'price_asc', 'price_desc', 'created_at']).default('name'),
  page: z.coerce.number().int().positive().default(1),
  page_size: z.coerce.number().int().positive().max(100).default(20),
});
