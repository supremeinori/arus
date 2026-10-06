import { Router } from 'express';
import { ReportsController } from './reports.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();
const reportsController = new ReportsController();

// Seluruh endpoint laporan butuh autentikasi sesi
router.use('/reports', requireAuth);

// 1. POST /api/reports - Generate snapshot laporan baru (Owner & Manager)
router.post(
  '/reports',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => reportsController.generateReport(req, res, next)
);

// 2. GET /api/reports - Ambil riwayat laporan berkala
router.get('/reports', (req, res, next) => reportsController.getReports(req, res, next));

// 3. GET /api/reports/:id - Ambil detail laporan beserta status verifikasi hash SHA-256
router.get('/reports/:id', (req, res, next) => reportsController.getReportById(req, res, next));

// 4. POST /api/reports/:id/verify - Verifikasi independen integritas data snapshot terhadap hash
router.post('/reports/:id/verify', (req, res, next) => reportsController.verifyReport(req, res, next));

export default router;
