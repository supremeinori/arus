import { Router } from 'express';
import { inventoryController } from './inventory.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// Terapkan requireAuth spesifik pada path /inventory
router.use('/inventory', requireAuth);

// 1. GET /api/inventory/ingredients - Daftar bahan baku cabang (Owner & Manager only)
router.get('/inventory/ingredients', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.getIngredients(req, res, next));

// 1b. GET /api/inventory/stocks - Alias kompatibilitas backward (Owner & Manager only)
router.get('/inventory/stocks', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.getIngredients(req, res, next));

// 2. POST /api/inventory/ingredients - Buat bahan baku baru
router.post('/inventory/ingredients', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.createIngredient(req, res, next));

// 3. PUT & PATCH /api/inventory/ingredients/:id - Update bahan baku
router.put('/inventory/ingredients/:id', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.updateIngredient(req, res, next));
router.patch('/inventory/ingredients/:id', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.updateIngredient(req, res, next));

// 4. DELETE /api/inventory/ingredients/:id - Hapus bahan baku
router.delete('/inventory/ingredients/:id', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.deleteIngredient(req, res, next));

// 5. POST /api/inventory/adjustments - Catat restock / opname / waste (Owner & Manager only)
router.post('/inventory/adjustments', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.createAdjustment(req, res, next));

// 6. GET /api/inventory/movements - Riwayat kartu stok bahan baku
router.get('/inventory/movements', requireRole([Role.owner, Role.manager]), (req, res, next) => inventoryController.getMovements(req, res, next));

export default router;
