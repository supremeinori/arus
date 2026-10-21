import crypto from 'crypto';
import { PaymentMethod, PrismaClient, Role, TxnStatus } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import { integrityService } from '../integrity/blockchain.service';
import {
  NotificationDraft,
  NotificationsService,
  createNotificationsWithDedup,
  resolveInventoryRecipients,
} from '../notifications/notifications.service';

const notificationsService = new NotificationsService();

export function toValidUuid(val: string): string {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  if (uuidRegex.test(val)) {
    return val.toLowerCase();
  }
  const hash = crypto.createHash('md5').update(val || 'default-req').digest('hex');
  return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-4${hash.slice(13, 16)}-a${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
}

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
   * Membuat transaksi penjualan POS baru berbasis resep dan bahan baku atomik.
   * Dilengkapi proteksi Idempotency (client_request_id), akumulasi kebutuhan bahan baku gabungan di keranjang,
   * pemotongan stok bahan baku atomik, dan pencatatan audit kartu stok (inventory_movements).
   */
  async createTransaction(
    cashierId: string,
    data: CreateTransactionInput,
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (!data.items || data.items.length === 0) {
      throw new AppError('INVALID_INPUT', 400, 'Keranjang transaksi tidak boleh kosong.');
    }

    // Resolusi outlet_id valid (jika dikirim outlet demo seperti out-001, map ke outlet riil di DB)
    const isOutletUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(data.outlet_id);
    let targetOutletId = data.outlet_id;
    if (!isOutletUuid && typeof prisma.outlet.findFirst === 'function') {
      const defaultOutlet = await prisma.outlet.findFirst({ where: { is_active: true } });
      if (defaultOutlet) {
        targetOutletId = defaultOutlet.id;
      }
    }

    if (userScope.role === Role.staff && !userScope.allowedOutletIds.includes(data.outlet_id) && !userScope.allowedOutletIds.includes(targetOutletId)) {
      throw new AppError('FORBIDDEN', 403, 'Anda tidak ditugaskan pada outlet ini.');
    }

    // Resolusi cashier_id valid (jika staff login demo, map ke user riil di DB)
    const isCashierUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(cashierId);
    let targetCashierId = cashierId;
    if (!isCashierUuid && typeof prisma.user.findFirst === 'function') {
      const defaultCashier = await prisma.user.findFirst({ where: { is_active: true } });
      if (defaultCashier) {
        targetCashierId = defaultCashier.id;
      }
    }

    const normalizedClientRequestId = toValidUuid(data.client_request_id);

    // 1. Cek Idempotency: Jika client_request_id sudah pernah diproses, kembalikan transaksi yang ada
    const existingTx = await prisma.transaction.findUnique({
      where: { client_request_id: normalizedClientRequestId },
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
    const pendingPushDrafts: NotificationDraft[] = [];
    const committedTransaction = await prisma.$transaction(async (tx) => {
      let calculatedSubtotal = 0;
      const preparedItems: Array<{
        product_id: string;
        product_name_snapshot: string;
        unit_price_idr: number;
        unit_cost_idr: number | null;
        quantity: number;
        line_total_idr: number;
      }> = [];

      // Map akumulasi kebutuhan bahan baku untuk seluruh keranjang:
      // ingredientId -> total amount needed
      const aggregatedIngredientNeeds = new Map<string, number>();

      for (const item of data.items) {
        if (item.quantity <= 0) {
          throw new AppError('INVALID_INPUT', 400, 'Jumlah item harus lebih dari 0.');
        }

        const product = await tx.product.findUnique({
          where: { id: item.product_id },
          include: {
            recipes: {
              include: {
                ingredient: true,
              },
            },
          },
        });

        if (!product || !product.is_active) {
          throw new AppError('NOT_FOUND', 404, `Produk dengan ID ${item.product_id} tidak aktif atau tidak ditemukan.`);
        }

        // Filter resep yang berlaku di cabang ini
        const relevantRecipes = product.recipes.filter(
          (r) => r.ingredient && r.ingredient.outlet_id === targetOutletId
        );

        // Hitung modal HPP menu dari total modal bahan baku resep
        const unitCostIdr = relevantRecipes.reduce((sum, r) => {
          return sum + r.amount_needed * (r.ingredient?.cost_per_unit ?? 0);
        }, 0);

        // Akumulasikan kebutuhan bahan baku di keranjang
        for (const recipe of relevantRecipes) {
          const needed = recipe.amount_needed * item.quantity;
          const currentTotal = aggregatedIngredientNeeds.get(recipe.ingredient_id) || 0;
          aggregatedIngredientNeeds.set(recipe.ingredient_id, currentTotal + needed);
        }

        const lineTotal = product.price_idr * item.quantity;
        calculatedSubtotal += lineTotal;

        preparedItems.push({
          product_id: product.id,
          product_name_snapshot: product.name,
          unit_price_idr: product.price_idr,
          unit_cost_idr: unitCostIdr,
          quantity: item.quantity,
          line_total_idr: lineTotal,
        });
      }

      // Validasi ketersediaan stok bahan baku gabungan (Atomic Check)
      const ingredientUpdates: Array<{
        ingredient_id: string;
        ingredient_name: string;
        unit: string;
        old_quantity: number;
        amount_needed: number;
        new_quantity: number;
        reorder_level: number;
      }> = [];

      for (const [ingredientId, totalAmountNeeded] of aggregatedIngredientNeeds.entries()) {
        const ingredient = await tx.ingredient.findUnique({
          where: { id: ingredientId },
        });

        if (!ingredient || ingredient.outlet_id !== targetOutletId) {
          throw new AppError(
            'NOT_FOUND',
            404,
            `Bahan baku dengan ID ${ingredientId} tidak ditemukan di cabang ini.`
          );
        }

        if (ingredient.stock_qty < totalAmountNeeded) {
          throw new AppError(
            'INVENTORY_INSUFFICIENT',
            409,
            `Stok bahan baku “${ingredient.name}” tidak mencukupi (tersedia: ${ingredient.stock_qty} ${ingredient.unit}, dibutuhkan total: ${totalAmountNeeded} ${ingredient.unit}). Transaksi dibatalkan.`
          );
        }

        ingredientUpdates.push({
          ingredient_id: ingredient.id,
          ingredient_name: ingredient.name,
          unit: ingredient.unit,
          old_quantity: ingredient.stock_qty,
          amount_needed: totalAmountNeeded,
          new_quantity: ingredient.stock_qty - totalAmountNeeded,
          reorder_level: ingredient.reorder_level,
        });
      }

      const discount = Math.max(0, Number(data.discount_idr ?? 0));
      const total = Math.max(0, calculatedSubtotal - discount);

      const rawPaid = (data as any).paid_idr ?? (data as any).cash_tendered_idr ?? (data as any).paid ?? (data.payment_method === PaymentMethod.cash ? total : total);
      const paid = Math.max(0, Number(rawPaid) || 0);

      if (data.payment_method === PaymentMethod.cash && paid < total) {
        throw new AppError(
          'PAYMENT_INSUFFICIENT',
          400,
          `Jumlah uang tunai kurang (total: Rp ${total}, dibayar: Rp ${paid}).`
        );
      }

      const finalPaid = data.payment_method === PaymentMethod.cash ? paid : total;
      const change = Math.max(0, finalPaid - total);

      // Generate Receipt No: INV-YYYYMMDD-XXXX
      const today = new Date();
      const datePart = today.toISOString().slice(0, 10).replace(/-/g, '');
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);
      const receiptNo = `INV-${datePart}-${randomSuffix}`;

      // 3. Simpan record Transaction & Transaction Items
      const newTransaction = await tx.transaction.create({
        data: {
          receipt_no: receiptNo,
          outlet_id: targetOutletId,
          cashier_id: targetCashierId,
          client_request_id: normalizedClientRequestId,
          subtotal_idr: calculatedSubtotal,
          discount_idr: discount,
          total_idr: total,
          payment_method: data.payment_method,
          paid_idr: finalPaid,
          change_idr: change,
          status: TxnStatus.completed,
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

      // 4. Potong stok bahan baku & catat riwayat mutasi (MovementType.sale)
      for (const update of ingredientUpdates) {
        await tx.ingredient.update({
          where: { id: update.ingredient_id },
          data: {
            stock_qty: update.new_quantity,
          },
        });

        await tx.inventoryMovement.create({
          data: {
            outlet_id: targetOutletId,
            ingredient_id: update.ingredient_id,
            movement_type: 'sale',
            quantity_delta: -update.amount_needed,
            quantity_after: update.new_quantity,
            transaction_id: newTransaction.id,
            note: `Penjualan kasir #${newTransaction.receipt_no}`,
            created_by: targetCashierId,
          },
        });

        // 4b. Jika stok bahan baku turun <= reorder_level, picu notifikasi
        //     Hook notifikasi (tidak mengubah logika stok/POS). Penerima
        //     dibatasi per cabang: Owner (semua cabang) + Manager(UserOutlet).
        if (update.new_quantity <= update.reorder_level) {
          const recipients = await resolveInventoryRecipients(tx, targetOutletId);
          const todayStr = new Date().toISOString().slice(0, 10);

          const drafts: NotificationDraft[] = recipients.map((userId) => ({
            user_id: userId,
            type: 'low_stock',
            title: `Peringatan: Stok ${update.ingredient_name} Menipis`,
            body: `Sisa bahan baku ${update.ingredient_name} di cabang kini tinggal ${update.new_quantity} ${update.unit} (batas aman minimum: ${update.reorder_level}). Segera lakukan restock.`,
            // Identifier record: bahan baku + cabang + periode. Sama dengan path
            // evaluate sehingga notifikasi tidak dobel antar trigger.
            dedup_key: `low_stock:${update.ingredient_id}:${targetOutletId}:${todayStr}`,
            data: {
              type: 'low_stock',
              outlet_id: targetOutletId,
              ingredient_id: update.ingredient_id,
            },
          }));

          const fresh = await createNotificationsWithDedup(tx, drafts);
          pendingPushDrafts.push(...fresh);
        }
      }

      await integrityService.appendEvent(tx, targetOutletId, {
        eventId: `sale:${newTransaction.id}`,
        eventType: 'sale',
        transactionId: newTransaction.id,
        eventData: {
          transaction_id: newTransaction.id,
          receipt_no: newTransaction.receipt_no,
          outlet_id: newTransaction.outlet_id,
          cashier_id: targetCashierId,
          subtotal_idr: newTransaction.subtotal_idr,
          discount_idr: newTransaction.discount_idr,
          total_idr: newTransaction.total_idr,
          payment_method: newTransaction.payment_method,
          status: newTransaction.status,
          items: preparedItems.map((item) => ({
            product_id: item.product_id,
            product_name: item.product_name_snapshot,
            quantity: item.quantity,
            unit_price_idr: item.unit_price_idr,
            line_total_idr: item.line_total_idr,
          })),
        },
      }, newTransaction.created_at);

      return newTransaction;
    }, {
      maxWait: 10000,
      timeout: 25000,
    });

    // Push dikirim SETELAH commit sukses. Kegagalan FCM tidak pernah menggagalkan
    // transaksi bisnis yang sudah ter-commit.
    if (pendingPushDrafts.length > 0) {
      try {
        await notificationsService.dispatchPush(pendingPushDrafts);
      } catch (err) {
        console.warn('[TransactionsService] Push low_stock gagal (diabaikan):', err);
      }
    }

    return committedTransaction;
  }

  /**
   * Pembatalan Transaksi (Void / Refund).
   * Hanya Owner dan Manager yang memiliki wewenang Void (SRS Section 7 & 17).
   * Mengembalikan stok bahan baku ke tabel ingredients sesuai takaran resep.
   */
  async voidTransaction(
    transactionId: string,
    voidedByUserId: string,
    reason: string,
    userRole?: Role
  ) {
    if (!reason || reason.trim().length === 0) {
      throw new AppError('INVALID_INPUT', 400, 'Alasan pembatalan (void reason) wajib diisi.');
    }

    const voidedTransaction = await prisma.$transaction(async (tx) => {
      const transaction = await tx.transaction.findUnique({
        where: { id: transactionId },
        include: { items: true },
      });

      if (!transaction) {
        throw new AppError('NOT_FOUND', 404, 'Transaksi tidak ditemukan.');
      }

      if (transaction.status === TxnStatus.voided) {
        throw new AppError('TRANSACTION_ALREADY_VOIDED', 400, 'Transaksi ini sudah pernah dibatalkan.');
      }

      // SRS Section 2.2: Manager hanya berhak void maksimal 24 jam sejak transaksi terbit
      if (userRole === Role.manager) {
        const diffMs = Date.now() - transaction.created_at.getTime();
        const diffHours = diffMs / (1000 * 60 * 60);
        if (diffHours > 24) {
          throw new AppError(
            'FORBIDDEN',
            403,
            'Manager hanya diizinkan membatalkan transaksi maksimal 24 jam setelah transaksi terbit. Silakan hubungi Owner.'
          );
        }
      }

      // 1. Update status transaksi menjadi voided
      const updated = await tx.transaction.update({
        where: { id: transactionId },
        data: {
          status: TxnStatus.voided,
        },
        include: {
          items: true,
          outlet: { select: { id: true, name: true } },
          cashier: { select: { id: true, name: true } },
        },
      });

      // 2. Akumulasikan bahan baku yang harus dikembalikan sesuai resep
      const ingredientReturns = new Map<string, number>();

      for (const item of transaction.items) {
        const product = await tx.product.findUnique({
          where: { id: item.product_id },
          include: {
            recipes: {
              where: {
                ingredient: { outlet_id: transaction.outlet_id },
              },
            },
          },
        });

        for (const recipe of product?.recipes || []) {
          const returnQty = recipe.amount_needed * item.quantity;
          const currentTotal = ingredientReturns.get(recipe.ingredient_id) || 0;
          ingredientReturns.set(recipe.ingredient_id, currentTotal + returnQty);
        }
      }

      // 3. Kembalikan stok ke tabel ingredients dan catat void_return di inventory_movements
      for (const [ingredientId, returnAmount] of ingredientReturns.entries()) {
        const ing = await tx.ingredient.findUnique({
          where: { id: ingredientId },
        });

        const currentQty = ing?.stock_qty ?? 0;
        const newQty = currentQty + returnAmount;

        await tx.ingredient.update({
          where: { id: ingredientId },
          data: {
            stock_qty: newQty,
          },
        });

        await tx.inventoryMovement.create({
          data: {
            outlet_id: transaction.outlet_id,
            ingredient_id: ingredientId,
            movement_type: 'void_return',
            quantity_delta: returnAmount,
            quantity_after: newQty,
            transaction_id: transaction.id,
            note: `Pengembalian Void #${transaction.receipt_no}: ${reason.trim()}`,
            created_by: voidedByUserId,
          },
        });
      }

      await integrityService.appendEvent(tx, transaction.outlet_id, {
        eventId: `void:${transaction.id}`,
        eventType: 'void_return',
        transactionId: transaction.id,
        eventData: {
          transaction_id: transaction.id,
          receipt_no: transaction.receipt_no,
          outlet_id: transaction.outlet_id,
          voided_by: voidedByUserId,
          reason: reason.trim(),
          total_idr: transaction.total_idr,
          items: transaction.items.map((item) => ({
            product_id: item.product_id,
            product_name: item.product_name_snapshot,
            quantity: item.quantity,
            unit_price_idr: item.unit_price_idr,
          })),
          returned_ingredients: [...ingredientReturns.entries()].map(([ingredientId, quantity]) => ({
            ingredient_id: ingredientId,
            quantity,
          })),
        },
      });

      return updated;
    }, {
      maxWait: 10000,
      timeout: 25000,
    });

    return voidedTransaction;
  }

  /**
   * Menampilkan daftar transaksi (dengan filter outlet, status, dan pagination).
   */
  async listTransactions(
    query: {
      outlet_id?: string;
      status?: TxnStatus;
      receipt_no?: string;
      from?: string;
      to?: string;
      page?: number;
      page_size?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 20, 100);
    const skip = (page - 1) * pageSize;

    const where: any = {};

    // RBAC: seluruh role selain owner terkunci ke outlet yang di-assign.
    // Manipulasi query outlet_id di luar wewenang ditolak (bukan diabaikan diam-diam).
    if (userScope.role !== Role.owner) {
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

    // Filter periode waktu (YYYY-MM-DD), inklusif sampai akhir hari.
    if (query.from || query.to) {
      where.created_at = {};
      if (query.from) where.created_at.gte = new Date(`${query.from}T00:00:00.000Z`);
      if (query.to) where.created_at.lte = new Date(`${query.to}T23:59:59.999Z`);
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
