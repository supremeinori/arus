import { z } from 'zod';

export const createCategorySchema = z.object({
  name: z.string().min(1).max(100),
});

export const updateCategorySchema = z.object({
  name: z.string().min(1).max(100),
});

export const recipeItemSchema = z.object({
  ingredient_id: z.string().min(1),
  amount_needed: z.number().int().positive('Takaran bahan per porsi harus lebih dari 0'),
});

export const createProductSchema = z.object({
  name: z.string().min(1).max(120),
  sku: z.string().min(1).max(40),
  price_idr: z.number().int().positive('Harga jual harus lebih dari 0'),
  category_id: z.string().min(1).optional(),
  image_url: z.string().url().or(z.literal('')).optional(),
  recipes: z.array(recipeItemSchema).min(1, 'Minimal 1 bahan baku').max(50).optional(),
});

export const updateProductSchema = z.object({
  name: z.string().min(1).max(120).optional(),
  sku: z.string().min(1).max(40).optional(),
  price_idr: z.number().int().positive().optional(),
  category_id: z.string().min(1).nullable().optional(),
  image_url: z.string().url().or(z.literal('')).nullable().optional(),
  is_active: z.boolean().optional(),
  recipes: z.array(recipeItemSchema).optional(),
});

export const productQuerySchema = z.object({
  outlet_id: z.string().min(1).optional(),
  category_id: z.string().min(1).optional(),
  is_active: z.enum(['true', 'false', 'all']).optional(),
  q: z.string().optional(),
  sort: z.enum(['name', 'price_asc', 'price_desc', 'created_at']).default('name'),
  page: z.coerce.number().int().positive().default(1),
  page_size: z.coerce.number().int().positive().max(100).default(50),
});
