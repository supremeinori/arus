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
  (req, res, next) => integrityController.getChain(req, res, next)
);

router.get(
  '/integrity/blockchain/verify/:outletId',
  (req, res, next) => integrityController.validateChain(req, res, next)
);

router.post(
  '/integrity/blockchain/simulate-tamper',
  (req, res, next) => integrityController.simulateTamper(req, res, next)
);

router.post(
  '/integrity/blockchain/recover',
  (req, res, next) => integrityController.recoverChain(req, res, next)
);

export default router;
