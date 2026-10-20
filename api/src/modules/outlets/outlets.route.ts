import { Router } from 'express';
import { OutletsController } from './outlets.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();
const outletsController = new OutletsController();

// Seluruh endpoint outlet memerlukan autentikasi
router.use('/outlets', requireAuth);

// 1. GET /api/outlets/performance - Metrik performa cabang untuk coloring peta LBS
router.get('/outlets/performance', (req, res, next) =>
  outletsController.performance(req, res, next)
);

// 2. GET /api/outlets/nearest - Cari cabang terdekat via Haversine LBS
router.get('/outlets/nearest', (req, res, next) =>
  outletsController.nearest(req, res, next)
);

// 3. GET /api/outlets - Daftar outlet (scoped by user role)
router.get('/outlets', (req, res, next) => outletsController.list(req, res, next));

// 4. GET /api/outlets/:id - Detail cabang
router.get('/outlets/:id', (req, res, next) => outletsController.getById(req, res, next));

// 5. POST /api/outlets - Buat outlet baru (Owner only)
router.post(
  '/outlets',
  requireRole([Role.owner]),
  (req, res, next) => outletsController.create(req, res, next)
);

// 6. PATCH /api/outlets/:id - Perbarui data cabang (Owner only)
router.patch(
  '/outlets/:id',
  requireRole([Role.owner]),
  (req, res, next) => outletsController.update(req, res, next)
);

// 7. DELETE /api/outlets/:id - Nonaktifkan cabang (Soft Delete, Owner only)
router.delete(
  '/outlets/:id',
  requireRole([Role.owner]),
  (req, res, next) => outletsController.deactivate(req, res, next)
);

export default router;
