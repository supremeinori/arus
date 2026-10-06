import { Router } from 'express';
import { insightsController } from './insights.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// Proteksi token untuk seluruh endpoint insights
router.use('/insights', requireAuth);

// 1. POST /api/insights/generate - Evaluasi Rule Engine on-demand (Owner/Manager)
router.post(
  '/insights/generate',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => insightsController.generate(req, res, next)
);

// 2. GET /api/insights - Daftar insight aktif
router.get('/insights', (req, res, next) => insightsController.list(req, res, next));

// 3. PATCH /api/insights/:id/status - Update status insight (acknowledged / dismissed)
router.patch('/insights/:id/status', (req, res, next) => insightsController.updateStatus(req, res, next));

export default router;
