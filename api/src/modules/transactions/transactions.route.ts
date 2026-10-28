import { Router } from 'express';
import { transactionsController } from './transactions.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// Proteksi token auth untuk seluruh endpoint transaksi
router.use('/transactions', requireAuth);

// 1. POST /api/transactions - Buat transaksi penjualan baru (Kasir, Manager, Owner)
router.post('/transactions', (req, res, next) => transactionsController.createTransaction(req, res, next));

// 2. GET /api/transactions - Riwayat transaksi
router.get('/transactions', (req, res, next) => transactionsController.listTransactions(req, res, next));

// 2b. GET /api/transactions/:id - Detail transaksi spesifik (Semua Role: Owner, Manager, Staff)
router.get('/transactions/:id', (req, res, next) => transactionsController.getTransactionById(req, res, next));

// 3. POST /api/transactions/:id/void - Pembatalan / Refund (Khusus Owner & Manager)
router.post(
  '/transactions/:id/void',
  requireRole([Role.owner, Role.manager]),
  (req, res, next) => transactionsController.voidTransaction(req, res, next)
);

export default router;
