import { Request, Response, NextFunction } from 'express';
import { integrityService } from './blockchain.service';
import { web3AnchorService } from './web3_anchor.service';
import { verifyOutletScope } from '../../middleware/auth';
import { AppError } from '../../shared/errors';

export class IntegrityController {
  /**
   * Endpoint Visualisasi Pohon Blockchain Ganda (Block-in-Block)
   * Hanya dapat diakses oleh Owner & Manager cabang terkait (dikontrol lewat auth & verifyOutletScope)
   */
  async getChain(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { outletId } = req.params;
      if (!outletId) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId wajib disertakan.');
      }

      // Verifikasi wewenang cabang (Role Manager hanya bisa melihat cabangnya, Owner bisa semua)
      verifyOutletScope(req, outletId);

      const data = await integrityService.getVisualizationData(outletId);
      res.status(200).json({
        success: true,
        data,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Endpoint Validasi Integritas Kriptografis Rantai
   */
  async validateChain(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { outletId } = req.params;
      if (!outletId) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId wajib disertakan.');
      }

      verifyOutletScope(req, outletId);

      const result = await integrityService.validateChain(outletId);
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
  async simulateTamper(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { outletId, blockIndex, fakeAmount } = req.body;
      if (!outletId || blockIndex === undefined) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId dan blockIndex wajib diisi.');
      }

      verifyOutletScope(req, outletId);

      const tamperInfo = await integrityService.simulateTampering(
        outletId,
        Number(blockIndex),
        Number(fakeAmount ?? 99999999)
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
  async recoverChain(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { outletId, blockIndex } = req.body;
      if (!outletId || blockIndex === undefined) {
        throw new AppError('BAD_REQUEST', 400, 'Parameter outletId dan blockIndex wajib diisi.');
      }

      verifyOutletScope(req, outletId);

      const recoveryInfo = await integrityService.recoverBlock(outletId, Number(blockIndex));
      res.status(200).json({
        success: recoveryInfo.success,
        message: recoveryInfo.message,
        data: recoveryInfo,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Status integrasi Web3 Ethereum Sepolia
   */
  async getWeb3Status(_req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      res.status(200).json({
        success: true,
        data: web3AnchorService.getStatus(),
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Verifikasi langsung ke smart contract Sepolia
   */
  async verifyWeb3Receipt(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { receiptNo } = req.params;
      if (!receiptNo) {
        throw new AppError('BAD_REQUEST', 400, 'Nomor struk wajib disertakan.');
      }

      const result = await web3AnchorService.verifyReceiptOnChain(receiptNo);
      res.status(200).json({
        success: true,
        data: result,
      });
    } catch (err) {
      next(err);
    }
  }

  /**
   * Trigger manual untuk anchor struk ke Sepolia
   */
  async anchorWeb3Receipt(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const { receiptNo, transactionId } = req.body;
      if (!receiptNo) {
        throw new AppError('BAD_REQUEST', 400, 'Nomor struk wajib disertakan.');
      }

      await web3AnchorService.anchorReceiptAsync(receiptNo, transactionId);

      res.status(200).json({
        success: true,
        message: `Proses pencatatan struk ${receiptNo} ke Sepolia telah dijadwalkan di background.`,
      });
    } catch (err) {
      next(err);
    }
  }
}

export const integrityController = new IntegrityController();
