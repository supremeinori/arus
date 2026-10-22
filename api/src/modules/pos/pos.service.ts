import { Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import { transactionsService } from '../transactions/transactions.service';
import type { PosCheckoutInput } from './pos.schema';

/**
 * Modul POS — thin layer di atas TransactionsService & Catalog.
 * Seluruh logika atomik (stok, mutasi, blockchain) tetap di
 * TransactionsService agar tidak ada duplikasi alur kasir.
 */
export class PosService {
  /**
   * GET /api/pos/catalog?outlet_id=...
   * Produk aktif + flag is_available & max_portions per sisa stok cabang.
   */
  async getCatalog(outletId: string, userScope: { role: Role; allowedOutletIds: string[] }) {
    if (userScope.role === Role.staff && !userScope.allowedOutletIds.includes(outletId)) {
      throw new AppError('FORBIDDEN', 403, 'Anda tidak ditugaskan pada outlet ini.');
    }

    const products = await prisma.product.findMany({
      where: { is_active: true },
      orderBy: { name: 'asc' },
      include: {
        category: { select: { id: true, name: true } },
        recipes: {
          include: {
            ingredient: {
              select: {
                id: true,
                outlet_id: true,
                name: true,
                unit: true,
                stock_qty: true,
                cost_per_unit: true,
              },
            },
          },
        },
      },
    });

    return products.map((p) => {
      const recipes = p.recipes ?? [];
      // If product has any recipe, ALL required ingredients must exist at this outlet
      const relevant = recipes.filter(
        (r) => r.ingredient && r.ingredient.outlet_id === outletId
      );

      // Product unavailable if it has recipes but some required ingredient missing at this branch
      const hasMissingIngredient = recipes.length > 0 && relevant.length < recipes.length;

      let maxPortions = 0;
      let unitCostIdr = 0;
      if (!hasMissingIngredient && relevant.length > 0) {
        const portions = relevant.map((r) =>
          r.amount_needed > 0 ? Math.floor(r.ingredient.stock_qty / r.amount_needed) : 0
        );
        maxPortions = Math.max(0, Math.min(...portions));
        unitCostIdr = relevant.reduce(
          (sum, r) => sum + r.amount_needed * (r.ingredient?.cost_per_unit ?? 0),
          0
        );
      }

      return {
        id: p.id,
        sku: p.sku,
        name: p.name,
        price_idr: p.price_idr,
        image_url: p.image_url,
        category_id: p.category_id,
        category: p.category,
        is_available: maxPortions > 0 && !hasMissingIngredient,
        max_portions: maxPortions,
        unit_cost_idr: userScope.role !== Role.staff ? unitCostIdr : undefined,
      };
    });
  }

  /**
   * POST /api/pos/checkout
   * Delegasi penuh ke TransactionsService.createTransaction (atomik + blockchain).
   * cashier_id opsional di payload — default dari token auth (lebih aman).
   */
  async checkout(
    authCashierId: string,
    data: PosCheckoutInput & { cashier_id?: string },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    try {
      return await transactionsService.createTransaction(
        data.cashier_id?.trim() ? data.cashier_id : authCashierId,
        {
          client_request_id: data.client_request_id,
          outlet_id: data.outlet_id,
          payment_method: data.payment_method as never,
          paid_idr: data.paid_idr,
          discount_idr: data.discount_idr ?? 0,
          items: data.items,
        },
        userScope
      );
    } catch (err: unknown) {
      // Spek kasir: stok kurang → 400 agar mudah ditangani UI.
      if (err instanceof AppError && err.code === 'INVENTORY_INSUFFICIENT') {
        throw new AppError('BAD_REQUEST', 400, err.message);
      }
      throw err;
    }
  }

  /**
   * POST /api/pos/void
   * Delegasi ke TransactionsService.voidTransaction (stok kembali + blok void_return).
   */
  async voidTransaction(
    transactionId: string,
    voidedByUserId: string,
    reason: string,
    userRole?: Role
  ) {
    return transactionsService.voidTransaction(transactionId, voidedByUserId, reason, userRole);
  }
}

export const posService = new PosService();
