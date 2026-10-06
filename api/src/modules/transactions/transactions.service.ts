import { PaymentMethod, PrismaClient, Role, TransactionStatus } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';

export interface CreateTransactionInput {
  client_request_id: string;
  outlet_id: string;
  payment_method: PaymentMethod;
  paid_idr: number;
  discount_idr?: number;
  items: Array<{
    product_id: string;
    quantity: number;
  }>;
}

export class TransactionsService {
  /**
   * Membuat transaksi penjualan POS baru.
   * Dilengkapi proteksi Idempotency (client_request_id), pengurangan stok atomik, dan audit kartu stok.
   */
  async createTransaction(
    cashierId: string,
    data: CreateTransactionInput,
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role === Role.staff && !userScope.allowedOutletIds.includes(data.outlet_id)) {
      throw new AppError('FORBIDDEN', 403, 'Anda tidak ditugaskan pada outlet ini.');
    }

    if (!data.items || data.items.length === 0) {
      throw new AppError('INVALID_INPUT', 400, 'Keranjang transaksi tidak boleh kosong.');
    }

    // 1. Cek Idempotency: Jika client_request_id sudah pernah diproses, kembalikan transaksi yang ada
    const existingTx = await prisma.transaction.findUnique({
      where: { client_request_id: data.client_request_id },
      include: {
        items: true,
        outlet: { select: { id: true, name: true } },
        cashier: { select: { id: true, name: true } },
      },
    });

    if (existingTx) {
      return existingTx;
    }

    // Jalankan seluruh proses pembuatan transaksi dalam Prisma $transaction
    return prisma.$transaction(async (tx) => {
      // 2. Validasi produk & stok outlet
      let calculatedSubtotal = 0;
      const preparedItems: Array<{
        product_id: string;
        product_name_snapshot: string;
        unit_price_idr: number;
        unit_cost_idr: number | null;
        quantity: number;
        line_total_idr: number;
      }> = [];

      const inventoryUpdates: Array<{
        product_id: string;
        new_quantity: number;
      }> = [];

      for (const item of data.items) {
        if (item.quantity <= 0) {
          throw new AppError('INVALID_INPUT', 400, 'Jumlah item harus lebih dari 0.');
        }

        const product = await tx.product.findUnique({
          where: { id: item.product_id },
        });

        if (!product || !product.is_active) {
          throw new AppError('NOT_FOUND', 404, `Produk dengan ID ${item.product_id} tidak aktif atau tidak ditemukan.`);
        }

        const inventory = await tx.inventory.findUnique({
          where: {
            outlet_id_product_id: {
              outlet_id: data.outlet_id,
              product_id: item.product_id,
            },
          },
        });

        const currentQty = inventory?.quantity ?? 0;
        if (currentQty < item.quantity) {
          throw new AppError(
            'INSUFFICIENT_STOCK',
            400,
            `Stok untuk “${product.name}” tidak mencukupi (tersedia: ${currentQty}, diminta: ${item.quantity}).`
          );
        }

        const lineTotal = product.price_idr * item.quantity;
        calculatedSubtotal += lineTotal;

        preparedItems.push({
          product_id: product.id,
          product_name_snapshot: product.name,
          unit_price_idr: product.price_idr,
          unit_cost_idr: product.cost_idr,
          quantity: item.quantity,
          line_total_idr: lineTotal,
        });

        inventoryUpdates.push({
          product_id: product.id,
          new_quantity: currentQty - item.quantity,
        });
      }

      const discount = Math.max(0, data.discount_idr ?? 0);
      const total = Math.max(0, calculatedSubtotal - discount);

      if (data.payment_method === PaymentMethod.cash && data.paid_idr < total) {
        throw new AppError(
          'PAYMENT_INSUFFICIENT',
          400,
          `Jumlah uang tunai kurang (total: Rp ${total}, dibayar: Rp ${data.paid_idr}).`
        );
      }

      const paid = data.payment_method === PaymentMethod.cash ? data.paid_idr : total;
      const change = Math.max(0, paid - total);

      // Generate Receipt No: misal ARUS-YYYYMMDD-XXXXX
      const today = new Date();
      const datePart = today.toISOString().slice(0, 10).replace(/-/g, '');
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);
      const receiptNo = `INV-${datePart}-${randomSuffix}`;

      // 3. Simpan record Transaction
      const newTransaction = await tx.transaction.create({
        data: {
          receipt_no: receiptNo,
          outlet_id: data.outlet_id,
          cashier_id: cashierId,
          client_request_id: data.client_request_id,
          subtotal_idr: calculatedSubtotal,
          discount_idr: discount,
          total_idr: total,
          payment_method: data.payment_method,
          paid_idr: paid,
          change_idr: change,
          status: TransactionStatus.completed,
          items: {
            create: preparedItems,
          },
        },
        include: {
          items: true,
          outlet: { select: { id: true, name: true } },
          cashier: { select: { id: true, name: true } },
        },
      });

      // 4. Update stok inventaris & buat audit pergerakan stok (MovementType.sale)
      for (const update of inventoryUpdates) {
        await tx.inventory.update({
          where: {
            outlet_id_product_id: {
              outlet_id: data.outlet_id,
              product_id: update.product_id,
            },
          },
          data: {
            quantity: update.new_quantity,
          },
        });

        const itemDetail = preparedItems.find((p) => p.product_id === update.product_id)!;
        await tx.inventoryMovement.create({
          data: {
            outlet_id: data.outlet_id,
            product_id: update.product_id,
            movement_type: 'sale',
            quantity_delta: -itemDetail.quantity,
            quantity_after: update.new_quantity,
            transaction_id: newTransaction.id,
            note: `Penjualan kasir #${newTransaction.receipt_no}`,
            created_by: cashierId,
          },
        });
      }

      return newTransaction;
    });
  }

  /**
   * Pembatalan Transaksi (Void / Refund).
   * Hanya Owner dan Manager yang memiliki wewenang Void (SRS Section 7 & 17).
   */
  async voidTransaction(
    transactionId: string,
    voidedByUserId: string,
    reason: string
  ) {
    if (!reason || reason.trim().length === 0) {
      throw new AppError('INVALID_INPUT', 400, 'Alasan pembatalan (void reason) wajib diisi.');
    }

    return prisma.$transaction(async (tx) => {
      const transaction = await tx.transaction.findUnique({
        where: { id: transactionId },
        include: { items: true },
      });

      if (!transaction) {
        throw new AppError('NOT_FOUND', 404, 'Transaksi tidak ditemukan.');
      }

      if (transaction.status === TransactionStatus.voided) {
        throw new AppError('TRANSACTION_ALREADY_VOIDED', 400, 'Transaksi ini sudah pernah dibatalkan.');
      }

      // 1. Ubah status transaksi menjadi voided
      const updated = await tx.transaction.update({
        where: { id: transactionId },
        data: {
          status: TransactionStatus.voided,
          voided_at: new Date(),
          voided_by: voidedByUserId,
          void_reason: reason.trim(),
        },
        include: {
          items: true,
          outlet: { select: { id: true, name: true } },
          cashier: { select: { id: true, name: true } },
        },
      });

      // 2. Kembalikan stok yang sebelumnya terpotong (void_return)
      for (const item of transaction.items) {
        const inv = await tx.inventory.findUnique({
          where: {
            outlet_id_product_id: {
              outlet_id: transaction.outlet_id,
              product_id: item.product_id,
            },
          },
        });

        const currentQty = inv?.quantity ?? 0;
        const newQty = currentQty + item.quantity;

        await tx.inventory.update({
          where: {
            outlet_id_product_id: {
              outlet_id: transaction.outlet_id,
              product_id: item.product_id,
            },
          },
          data: {
            quantity: newQty,
          },
        });

        await tx.inventoryMovement.create({
          data: {
            outlet_id: transaction.outlet_id,
            product_id: item.product_id,
            movement_type: 'void_return',
            quantity_delta: item.quantity,
            quantity_after: newQty,
            transaction_id: transaction.id,
            note: `Pengembalian Void #${transaction.receipt_no}: ${reason.trim()}`,
            created_by: voidedByUserId,
          },
        });
      }

      return updated;
    });
  }

  /**
   * Menampilkan daftar transaksi (dengan filter outlet, status, dan pagination).
   */
  async listTransactions(
    query: {
      outlet_id?: string;
      status?: TransactionStatus;
      receipt_no?: string;
      page?: number;
      page_size?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 20, 100);
    const skip = (page - 1) * pageSize;

    const where: any = {};

    if (userScope.role === Role.staff) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
      }
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    if (query.status) where.status = query.status;
    if (query.receipt_no) {
      where.receipt_no = { contains: query.receipt_no, mode: 'insensitive' };
    }

    const [total, transactions] = await Promise.all([
      prisma.transaction.count({ where }),
      prisma.transaction.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { created_at: 'desc' },
        include: {
          items: true,
          outlet: { select: { id: true, name: true } },
          cashier: { select: { id: true, name: true } },
        },
      }),
    ]);

    return {
      transactions,
      meta: {
        page,
        page_size: pageSize,
        total,
      },
    };
  }
}

export const transactionsService = new TransactionsService();
