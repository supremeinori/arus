import { Router } from 'express';
import { inventoryController } from './inventory.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// Terapkan requireAuth spesifik pada path /inventory
router.use('/inventory', requireAuth);

// 1. GET /api/inventory/stocks - Daftar stok outlet (filter outlet, low-stock alert, pencarian)
router.get('/inventory/stocks', (req, res, next) => inventoryController.getStocks(req, res, next));

// 2. POST /api/inventory/adjustments - Catat opname / koreksi stok (Owner & Manager only per SRS 2.2)
router.post('/inventory/adjustments', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.createAdjustment(req, res, next));

// 3. GET /api/inventory/movements - Riwayat kartu stok / audit trail
router.get('/inventory/movements', (req, res, next) => inventoryController.getMovements(req, res, next));

export default router;
