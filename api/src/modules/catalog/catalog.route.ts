import { Router } from 'express';
import {
  listCategories,
  createCategory,
  updateCategory,
  listProducts,
  getProductById,
  createProduct,
  updateProduct,
} from './catalog.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// Terapkan requireAuth spesifik pada path kategori dan produk
router.use('/categories', requireAuth);
router.use('/products', requireAuth);

// Categories
router.get('/categories', listCategories);
router.post('/categories', requireRole([Role.owner, Role.manager]), createCategory);
router.patch('/categories/:id', requireRole([Role.owner, Role.manager]), updateCategory);

// Products
router.get('/products', listProducts);
router.get('/products/:id', getProductById);
router.post('/products', requireRole([Role.owner, Role.manager]), createProduct);
router.patch('/products/:id', requireRole([Role.owner, Role.manager]), updateProduct);

export default router;
