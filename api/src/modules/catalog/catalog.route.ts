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

// Categories (Public read, Owner/Manager write)
router.get('/categories', optionalAuth, listCategories);
router.post('/categories', requireAuth, requireRole([Role.owner, Role.manager]), createCategory);
router.patch('/categories/:id', requireAuth, requireRole([Role.owner, Role.manager]), updateCategory);

// Products (Public read with optional auth for cost info, Owner/Manager write)
router.get('/products', optionalAuth, listProducts);
router.get('/products/:id', optionalAuth, getProductById);
router.post('/products', requireAuth, requireRole([Role.owner, Role.manager]), createProduct);
router.put('/products/:id', requireAuth, requireRole([Role.owner, Role.manager]), updateProduct);
router.patch('/products/:id', requireAuth, requireRole([Role.owner, Role.manager]), updateProduct);
router.delete('/products/:id', requireAuth, requireRole([Role.owner, Role.manager]), deleteProduct);

export default router;
