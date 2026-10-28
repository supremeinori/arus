import { Router } from 'express';
import { Role } from '@prisma/client';
import { integrityController } from './integrity.controller';
import { requireAuth, requireRole } from '../../middleware/auth';

const router = Router();

/**
 * Verifikasi Publik Smart Contract Sepolia (Bisa diakses tanpa login oleh siapapun/konsumen)
 */
router.get(
  '/integrity/web3/public-verify/:receiptNo',
  (req, res, next) => integrityController.verifyWeb3Receipt(req, res, next)
);

// Seluruh endpoint integritas di bawah ini wajib terautentikasi
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

// ==========================================
// MODUL WEB3 PUBLIC BLOCKCHAIN (ETHEREUM SEPOLIA)
// ==========================================
router.get(
  '/integrity/web3/status',
  (req, res, next) => integrityController.getWeb3Status(req, res, next)
);

router.get(
  '/integrity/web3/verify/:receiptNo',
  (req, res, next) => integrityController.verifyWeb3Receipt(req, res, next)
);

router.post(
  '/integrity/web3/anchor',
  (req, res, next) => integrityController.anchorWeb3Receipt(req, res, next)
);

export default router;
