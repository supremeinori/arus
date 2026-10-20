import { Router } from 'express';
import {
  listCategories,
  createCategory,
  updateCategory,
  listProducts,
  getProductById,
  createProduct,
  updateProduct,
  deleteProduct,
} from './catalog.controller';
import { requireAuth, requireRole, optionalAuth } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// Categories (Public read, Owner only write)
router.get('/categories', optionalAuth, listCategories);
router.post('/categories', requireAuth, requireRole([Role.owner]), createCategory);
router.patch('/categories/:id', requireAuth, requireRole([Role.owner]), updateCategory);

// Products (Public read with optional auth for cost info, Owner only write)
router.get('/products', optionalAuth, listProducts);
router.get('/products/:id', optionalAuth, getProductById);
router.post('/products', requireAuth, requireRole([Role.owner]), createProduct);
router.put('/products/:id', requireAuth, requireRole([Role.owner]), updateProduct);
router.patch('/products/:id', requireAuth, requireRole([Role.owner]), updateProduct);
router.delete('/products/:id', requireAuth, requireRole([Role.owner]), deleteProduct);

export default router;
