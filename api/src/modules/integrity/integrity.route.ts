import { Router } from 'express';
import { Role } from '@prisma/client';
import { integrityController } from './integrity.controller';
import { requireAuth, requireRole } from '../../middleware/auth';

const router = Router();

// Seluruh endpoint integritas wajib terautentikasi
router.use('/integrity', requireAuth, requireRole([Role.owner, Role.manager]));

/**
 * MODUL LOCAL BLOCKCHAIN & VISUALISASI INTEGRITAS
 * Hak Akses:
 * - Role "owner" : Dapat mengakses seluruh cabang.
 * - Role "manager": Hanya dapat mengakses cabang yang ditugaskan kepadanya (outlet scoping).
 * - Role "staff"  : Terblokir otomatis (HTTP 403 Forbidden).
 */
router.get(
  '/integrity/blockchain/chain/:outletId',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => integrityController.getDualChain(req, res, next)
);

router.post(
  '/integrity/blockchain/close-day',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => integrityController.closeCurrentDay(req, res, next)
);

router.get(
  '/integrity/blockchain/verify/:outletId',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => integrityController.validateChain(req, res, next)
);

router.post(
  '/integrity/blockchain/simulate-tamper',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => integrityController.simulateTamper(req, res, next)
);

router.post(
  '/integrity/blockchain/recover',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => integrityController.recoverChain(req, res, next)
);

// --- Legacy Compatibility Endpoints ---
router.get('/integrity/chain/:outletId', (req, res, next) => integrityController.getChainForOutlet(req, res, next));
router.get('/integrity/verify/transaction/:id', (req, res, next) => integrityController.verifyTransaction(req, res, next));
router.get('/integrity/verify/report/:id', (req, res, next) => integrityController.verifyReport(req, res, next));

export default router;
