import { Router } from 'express';
import { posController } from './pos.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// Seluruh endpoint POS butuh token auth
router.use('/pos', requireAuth);

// 1. GET /api/pos/catalog?outlet_id=... — katalog kasir + ketersediaan stok
router.get('/pos/catalog', (req, res, next) => posController.getCatalog(req, res, next));

// 2. POST /api/pos/checkout — eksekusi checkout atomik (kasir, manager, owner)
router.post('/pos/checkout', (req, res, next) => posController.checkout(req, res, next));

// 3. POST /api/pos/void — void transaksi (khusus owner & manager)
router.post(
  '/pos/void',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => posController.voidTransaction(req, res, next)
);

export default router;
