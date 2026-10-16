import { Request, Response, NextFunction } from 'express';
import { integrityService } from './integrity.service';
import { verifyOutletScope } from '../../middleware/auth';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';

export class IntegrityController {
  /**
   * Endpoint Visualisasi Pohon Blockchain Ganda (Block-in-Block)
   * Hanya dapat diakses oleh Owner & Manager cabang terkait (dikontrol lewat auth & verifyOutletScope)
   */
  getDualChain(req: Request, res: Response, next: NextFunction): void {
    try {
      const { outletId } = req.params;
      if (!outletId) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId wajib disertakan.');
      }

      // Verifikasi wewenang cabang (Role Manager hanya bisa melihat cabangnya, Owner bisa semua)
      verifyOutletScope(req, outletId);

      const data = integrityService.getVisualizationData(outletId);
      res.status(200).json({
        success: true,
        data,
      });
    } catch (err) {
      next(err);
    }
  }

  /** Finalisasi rantai transaksi untuk akhir hari. */
  closeCurrentDay(req: Request, res: Response, next: NextFunction): void {
    try {
      const { outletId } = req.body;
      if (!outletId || typeof outletId !== 'string') {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId wajib disertakan.');
      }
      verifyOutletScope(req, outletId);
      const dailyBlock = integrityService.closeCurrentDay(outletId);
      res.status(201).json({ success: true, data: dailyBlock });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Endpoint Validasi Integritas Kriptografis Rantai
   */
  validateChain(req: Request, res: Response, next: NextFunction): void {
    try {
      const { outletId } = req.params;
      if (!outletId) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId wajib disertakan.');
      }

      verifyOutletScope(req, outletId);

      const result = integrityService.validateChain(outletId);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Endpoint Simulasi Manipulasi Data Transaksi (Tamper Trigger)
   */
  simulateTamper(req: Request, res: Response, next: NextFunction): void {
    try {
      const { outletId, dayIndex, txIndex, fakeAmount } = req.body;
      if (!outletId || dayIndex === undefined || txIndex === undefined) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId, dayIndex, dan txIndex wajib diisi.');
      }

      verifyOutletScope(req, outletId);

      const tamperInfo = integrityService.simulateTampering(
        outletId,
        Number(dayIndex),
        Number(txIndex),
        Number(fakeAmount || 99999999)
      );

      res.status(200).json({
        success: true,
        message: 'Manipulasi data transaksi berhasil disimulasikan.',
        data: tamperInfo,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Endpoint Pemulihan / Rollback / Resync dari Snapshot Cadangan
   */
  recoverChain(req: Request, res: Response, next: NextFunction): void {
    try {
      const { outletId, dayIndex } = req.body;
      if (!outletId || dayIndex === undefined) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId dan dayIndex wajib diisi.');
      }

      verifyOutletScope(req, outletId);

      const recoveryInfo = integrityService.recoverChain(outletId, Number(dayIndex));
      res.status(200).json({
        success: recoveryInfo.success,
        message: recoveryInfo.message,
        data: recoveryInfo,
      });
    } catch (err) {
      next(err);
    }
  }

  // --- Legacy Compatibility Endpoints ---

  getChainForOutlet(req: Request, res: Response, next: NextFunction): void {
    try {
      const { outletId } = req.params;
      if (!outletId) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId wajib disertakan.');
      }
      verifyOutletScope(req, outletId);
      const chain = integrityService.getChainForOutlet(outletId);
      res.status(200).json({ data: chain });
    } catch (err) {
      next(err);
    }
  }

  async verifyTransaction(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { id } = req.params;
      const transaction = await prisma.transaction.findUnique({
        where: { id },
        select: { outlet_id: true },
      });
      if (!transaction) {
        throw new AppError('NOT_FOUND', 404, 'Transaksi tidak ditemukan.');
      }
      verifyOutletScope(req, transaction.outlet_id);
      const result = integrityService.verifyTransaction(id);
      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  verifyReport(req: Request, res: Response, next: NextFunction): void {
    try {
      const { id } = req.params;
      const result = integrityService.verifyReport(id);
      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const integrityController = new IntegrityController();
