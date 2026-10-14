import { Request, Response, NextFunction } from 'express';
import { transactionsService, CreateTransactionInput } from './transactions.service';
import { TxnStatus } from '@prisma/client';

export class TransactionsController {
  async createTransaction(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const body = req.body as CreateTransactionInput;

      const transaction = await transactionsService.createTransaction(
        user.id,
        body,
        { role: user.role, allowedOutletIds }
      );

      res.status(201).json({ data: transaction });
    } catch (err) {
      next(err);
    }
  }

  async voidTransaction(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const { id } = req.params;
      const { reason } = req.body;

      const updated = await transactionsService.voidTransaction(id, user.id, reason, user.role);

      res.status(200).json({ data: updated });
    } catch (err) {
      next(err);
    }
  }

  async listTransactions(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const user = req.user!;
      const allowedOutletIds = req.userOutlets || [];
      const { outlet_id, status, receipt_no, page, page_size } = req.query;

      const result = await transactionsService.listTransactions(
        {
          outlet_id: outlet_id as string,
          status: status as TxnStatus,
          receipt_no: receipt_no as string,
          page: page ? parseInt(page as string, 10) : undefined,
          page_size: page_size ? parseInt(page_size as string, 10) : undefined,
        },
        { role: user.role, allowedOutletIds }
      );

      res.status(200).json({ data: result.transactions, meta: result.meta });
    } catch (err) {
      next(err);
    }
  }
}

export const transactionsController = new TransactionsController();
