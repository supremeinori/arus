import { MovementType, PrismaClient, Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { isDbAvailable } from '../../config/db-health';
import { AppError } from '../../shared/errors';

export interface IngredientItem {
  id: string;
  outlet_id: string;
  name: string;
  unit: string;
  stock_qty: number;
  reorder_level: number;
  cost_per_unit: number;
  status: 'ok' | 'low' | 'out';
  updated_at: Date;
  outlet?: { id: string; name: string };
}

// Persistent in-memory demo ingredient data for offline/demo operation
const sharedDemoIngredients: IngredientItem[] = [
  { id: 'ing-001', outlet_id: 'out-001', name: 'Biji Kopi Arabika House Blend', unit: 'gram', stock_qty: 2400, reorder_level: 500, cost_per_unit: 150, status: 'ok', updated_at: new Date(), outlet: { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)' } },
  { id: 'ing-002', outlet_id: 'out-001', name: 'Susu Fresh Milk UHT', unit: 'ml', stock_qty: 350, reorder_level: 1000, cost_per_unit: 20, status: 'low', updated_at: new Date(), outlet: { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)' } },
  { id: 'ing-003', outlet_id: 'out-001', name: 'Air Mineral Purified', unit: 'ml', stock_qty: 15000, reorder_level: 2000, cost_per_unit: 2, status: 'ok', updated_at: new Date(), outlet: { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)' } },
  { id: 'ing-004', outlet_id: 'out-001', name: 'Gula Aren Cair Organik', unit: 'ml', stock_qty: 0, reorder_level: 500, cost_per_unit: 40, status: 'out', updated_at: new Date(), outlet: { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)' } },
  { id: 'ing-005', outlet_id: 'out-001', name: 'Daun Teh Hitam Asli', unit: 'gram', stock_qty: 1200, reorder_level: 300, cost_per_unit: 100, status: 'ok', updated_at: new Date(), outlet: { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)' } },
  { id: 'ing-006', outlet_id: 'out-001', name: 'Adonan Croissant Butter', unit: 'pcs', stock_qty: 25, reorder_level: 10, cost_per_unit: 8000, status: 'ok', updated_at: new Date(), outlet: { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)' } },
];

const sharedDemoMovements: any[] = [];

export class InventoryService {
  /**
   * Helper untuk menghitung status stok bahan baku:
   * 'out' jika 0, 'low' jika <= reorder_level, 'ok' selain itu.
   */
  private calculateStatus(stockQty: number, reorderLevel: number): 'ok' | 'low' | 'out' {
    if (stockQty <= 0) return 'out';
    if (stockQty <= reorderLevel) return 'low';
    return 'ok';
  }

  /**
   * Menampilkan daftar bahan baku per outlet (alias listStocks).
   */
  async listStocks(
    query: {
      outlet_id?: string;
      low_stock?: boolean;
      status?: 'ok' | 'low' | 'out';
      q?: string;
      page?: number;
      page_size?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const status = query.status || (query.low_stock ? 'low' : undefined);
    return this.listIngredients({ ...query, status }, userScope);
  }

  /**
   * Menampilkan daftar bahan baku per outlet.
   * Hanya boleh diakses oleh Owner (semua outlet) dan Manager (hanya outlet penugasan).
   * Staff/Kasir ditolak dengan HTTP 403.
   */
  async listIngredients(
    query: {
      outlet_id?: string;
      status?: 'ok' | 'low' | 'out';
      q?: string;
      page?: number;
      page_size?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role === Role.staff) {
      throw new AppError('FORBIDDEN', 403, 'Role Staff (Kasir) tidak memiliki akses ke manajemen bahan baku.');
    }

    if (userScope.role === Role.manager) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke cabang ini tidak diizinkan untuk Manager.');
      }
    }

    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 50, 100);
    const skip = (page - 1) * pageSize;

    const where: any = {};

    if (userScope.role === Role.manager) {
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    if (query.q && query.q.trim().length > 0) {
      where.name = { contains: query.q.trim(), mode: 'insensitive' };
    }

    if (!(await isDbAvailable())) {
      let filtered = [...sharedDemoIngredients];
      if (query.outlet_id) {
        filtered = filtered.filter((s) => s.outlet_id === query.outlet_id);
      } else if (userScope.role === Role.manager) {
        filtered = filtered.filter((s) => userScope.allowedOutletIds.includes(s.outlet_id));
      }
      if (query.status) {
        filtered = filtered.filter((s) => s.status === query.status);
      }
      if (query.q) {
        const q = query.q.toLowerCase();
        filtered = filtered.filter((s) => s.name.toLowerCase().includes(q));
      }
      return {
        ingredients: filtered.slice(skip, skip + pageSize),
        stocks: filtered.slice(skip, skip + pageSize), // backward-compatible alias
        meta: { page, page_size: pageSize, total: filtered.length },
      };
    }

    try {
      const items = await prisma.ingredient.findMany({
        where,
        orderBy: [{ stock_qty: 'asc' }, { name: 'asc' }],
        include: {
          outlet: { select: { id: true, name: true } },
        },
      });

      const mapped = items.map((ing) => {
        const status = this.calculateStatus(ing.stock_qty, ing.reorder_level);
        return {
          id: ing.id,
          outlet_id: ing.outlet_id,
          name: ing.name,
          unit: ing.unit,
          stock_qty: ing.stock_qty,
          reorder_level: ing.reorder_level,
          cost_per_unit: ing.cost_per_unit,
          status,
          updated_at: ing.updated_at,
          outlet: ing.outlet,
        };
      });

      const filteredByStatus = query.status
        ? mapped.filter((item) => item.status === query.status)
        : mapped;

      const total = filteredByStatus.length;
      const paginated = filteredByStatus.slice(skip, skip + pageSize);

      return {
        ingredients: paginated,
        stocks: paginated, // backward-compatible alias
        meta: {
          page,
          page_size: pageSize,
          total,
        },
      };
    } catch (_) {
      let filtered = [...sharedDemoIngredients];
      if (query.outlet_id) {
        filtered = filtered.filter((s) => s.outlet_id === query.outlet_id);
      }
      return {
        ingredients: filtered,
        stocks: filtered,
        meta: { page: 1, page_size: pageSize, total: filtered.length },
      };
    }
  }

  /**
   * Membuat bahan baku baru di cabang tertentu.
   */
  async createIngredient(
    userId: string,
    data: {
      outlet_id: string;
      name: string;
      unit: string;
      stock_qty?: number;
      reorder_level?: number;
      cost_per_unit?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role === Role.staff) {
      throw new AppError('FORBIDDEN', 403, 'Role Staff (Kasir) tidak diizinkan membuat bahan baku.');
    }

    if (userScope.role === Role.manager && !userScope.allowedOutletIds.includes(data.outlet_id)) {
      throw new AppError('FORBIDDEN', 403, 'Akses ke cabang ini tidak diizinkan untuk Manager.');
    }

    const stockQty = Math.max(0, Number(data.stock_qty ?? 0));
    const reorderLevel = Math.max(0, Number(data.reorder_level ?? 100));
    const costPerUnit = Math.max(0, Number(data.cost_per_unit ?? 0));

    if (!data.name || data.name.trim().length === 0) {
      throw new AppError('INVALID_INPUT', 400, 'Nama bahan baku wajib diisi.');
    }

    if (!data.unit || data.unit.trim().length === 0) {
      throw new AppError('INVALID_INPUT', 400, 'Satuan bahan baku (unit) wajib diisi.');
    }

    if (!(await isDbAvailable())) {
      const existing = sharedDemoIngredients.find(
        (i) => i.outlet_id === data.outlet_id && i.name.toLowerCase() === data.name.trim().toLowerCase()
      );
      if (existing) {
        throw new AppError('DUPLICATE_INGREDIENT', 409, `Bahan baku “${data.name}” sudah ada di cabang ini.`);
      }

      const newIng: IngredientItem = {
        id: `ing-${Date.now()}`,
        outlet_id: data.outlet_id,
        name: data.name.trim(),
        unit: data.unit.trim(),
        stock_qty: stockQty,
        reorder_level: reorderLevel,
        cost_per_unit: costPerUnit,
        status: this.calculateStatus(stockQty, reorderLevel),
        updated_at: new Date(),
      };
      sharedDemoIngredients.unshift(newIng);

      if (stockQty > 0) {
        sharedDemoMovements.unshift({
          id: `mov-${Date.now()}`,
          outlet_id: data.outlet_id,
          ingredient_id: newIng.id,
          movement_type: MovementType.restock,
          quantity_delta: stockQty,
          quantity_after: stockQty,
          note: 'Stok awal bahan baku baru',
          created_by: userId,
          created_at: new Date(),
        });
      }

      return newIng;
    }

    const existing = await prisma.ingredient.findUnique({
      where: {
        outlet_id_name: {
          outlet_id: data.outlet_id,
          name: data.name.trim(),
        },
      },
    });

    if (existing) {
      throw new AppError('DUPLICATE_INGREDIENT', 409, `Bahan baku “${data.name}” sudah ada di cabang ini.`);
    }

    return prisma.$transaction(async (tx) => {
      const ingredient = await tx.ingredient.create({
        data: {
          outlet_id: data.outlet_id,
          name: data.name.trim(),
          unit: data.unit.trim(),
          stock_qty: stockQty,
          reorder_level: reorderLevel,
          cost_per_unit: costPerUnit,
        },
        include: {
          outlet: { select: { id: true, name: true } },
        },
      });

      if (stockQty > 0) {
        await tx.inventoryMovement.create({
          data: {
            outlet_id: data.outlet_id,
            ingredient_id: ingredient.id,
            movement_type: MovementType.restock,
            quantity_delta: stockQty,
            quantity_after: stockQty,
            note: 'Stok awal bahan baku baru',
            created_by: userId,
          },
        });
      }

      return {
        ...ingredient,
        status: this.calculateStatus(ingredient.stock_qty, ingredient.reorder_level),
      };
    });
  }

  /**
   * Update bahan baku.
   */
  async updateIngredient(
    userId: string,
    id: string,
    data: {
      name?: string;
      unit?: string;
      reorder_level?: number;
      cost_per_unit?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role === Role.staff) {
      throw new AppError('FORBIDDEN', 403, 'Role Staff (Kasir) tidak diizinkan mengubah bahan baku.');
    }

    if (!(await isDbAvailable())) {
      const ing = sharedDemoIngredients.find((i) => i.id === id);
      if (!ing) throw new AppError('NOT_FOUND', 404, 'Bahan baku tidak ditemukan.');
      if (userScope.role === Role.manager && !userScope.allowedOutletIds.includes(ing.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke cabang ini tidak diizinkan untuk Manager.');
      }
      if (data.name !== undefined) ing.name = data.name.trim();
      if (data.unit !== undefined) ing.unit = data.unit.trim();
      if (data.reorder_level !== undefined) ing.reorder_level = data.reorder_level;
      if (data.cost_per_unit !== undefined) ing.cost_per_unit = data.cost_per_unit;
      ing.status = this.calculateStatus(ing.stock_qty, ing.reorder_level);
      ing.updated_at = new Date();
      return ing;
    }

    const existing = await prisma.ingredient.findUnique({ where: { id } });
    if (!existing) throw new AppError('NOT_FOUND', 404, 'Bahan baku tidak ditemukan.');

    if (userScope.role === Role.manager && !userScope.allowedOutletIds.includes(existing.outlet_id)) {
      throw new AppError('FORBIDDEN', 403, 'Akses ke cabang ini tidak diizinkan untuk Manager.');
    }

    const updated = await prisma.ingredient.update({
      where: { id },
      data: {
        ...(data.name ? { name: data.name.trim() } : {}),
        ...(data.unit ? { unit: data.unit.trim() } : {}),
        ...(data.reorder_level !== undefined ? { reorder_level: data.reorder_level } : {}),
        ...(data.cost_per_unit !== undefined ? { cost_per_unit: data.cost_per_unit } : {}),
      },
      include: {
        outlet: { select: { id: true, name: true } },
      },
    });

    return {
      ...updated,
      status: this.calculateStatus(updated.stock_qty, updated.reorder_level),
    };
  }

  /**
   * Menghapus bahan baku dari cabang.
   */
  async deleteIngredient(
    userId: string,
    id: string,
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role === Role.staff) {
      throw new AppError('FORBIDDEN', 403, 'Role Staff (Kasir) tidak diizinkan menghapus bahan baku.');
    }

    if (!(await isDbAvailable())) {
      const idx = sharedDemoIngredients.findIndex((i) => i.id === id);
      if (idx === -1) throw new AppError('NOT_FOUND', 404, 'Bahan baku tidak ditemukan.');
      const ing = sharedDemoIngredients[idx];
      if (userScope.role === Role.manager && !userScope.allowedOutletIds.includes(ing.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke cabang ini tidak diizinkan untuk Manager.');
      }
      sharedDemoIngredients.splice(idx, 1);
      return { success: true, message: `Bahan baku “${ing.name}” berhasil dihapus.` };
    }

    const existing = await prisma.ingredient.findUnique({ where: { id } });
    if (!existing) throw new AppError('NOT_FOUND', 404, 'Bahan baku tidak ditemukan.');

    if (userScope.role === Role.manager && !userScope.allowedOutletIds.includes(existing.outlet_id)) {
      throw new AppError('FORBIDDEN', 403, 'Akses ke cabang ini tidak diizinkan untuk Manager.');
    }

    await prisma.ingredient.delete({ where: { id } });
    return { success: true, message: `Bahan baku “${existing.name}” berhasil dihapus.` };
  }

  /**
   * Catat penyesuaian stok bahan baku (Restock, Opname / Koreksi, Waste).
   * Update stock_qty di tabel ingredients dan catat baris baru di inventory_movements secara atomik.
   */
  async createAdjustment(
    userId: string,
    data: {
      outlet_id: string;
      ingredient_id?: string;
      product_id?: string; // backwards compatibility alias
      movement_type: MovementType; // 'restock' | 'correction' | 'waste'
      quantity_delta: number;      // Perubahan stok (positif/negatif)
      note?: string;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role === Role.staff) {
      throw new AppError('FORBIDDEN', 403, 'Staff (Kasir) tidak diizinkan melakukan penyesuaian stok bahan baku.');
    }

    if (userScope.role === Role.manager && !userScope.allowedOutletIds.includes(data.outlet_id)) {
      throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
    }

    const targetIngredientId = data.ingredient_id || data.product_id;
    if (!targetIngredientId) {
      throw new AppError('INVALID_INPUT', 400, 'ingredient_id wajib disertakan.');
    }

    if (data.quantity_delta === 0) {
      throw new AppError('INVALID_INPUT', 400, 'Perubahan stok tidak boleh 0.');
    }

    if (!['correction', 'waste', 'restock'].includes(data.movement_type)) {
      throw new AppError('INVALID_INPUT', 400, 'Tipe penyesuaian hanya mendukung correction, waste, atau restock.');
    }

    const applyDemoAdjustment = () => {
      let targetItem = sharedDemoIngredients.find(
        (s) => s.id === targetIngredientId || s.name.toLowerCase() === targetIngredientId.toLowerCase()
      );
      if (!targetItem) {
        targetItem = {
          id: targetIngredientId,
          outlet_id: data.outlet_id,
          name: targetIngredientId,
          unit: 'pcs',
          stock_qty: 10,
          reorder_level: 5,
          cost_per_unit: 100,
          status: 'ok',
          updated_at: new Date(),
        };
        sharedDemoIngredients.push(targetItem);
      }

      const newQuantity = targetItem.stock_qty + data.quantity_delta;
      if (newQuantity < 0) {
        throw new AppError('INSUFFICIENT_STOCK', 400, `Stok bahan baku tidak mencukupi (stok saat ini: ${targetItem.stock_qty}).`);
      }
      targetItem.stock_qty = newQuantity;
      targetItem.status = this.calculateStatus(newQuantity, targetItem.reorder_level);
      targetItem.updated_at = new Date();

      const movement = {
        id: `mov-${Date.now()}`,
        outlet_id: targetItem.outlet_id,
        ingredient_id: targetItem.id,
        movement_type: data.movement_type,
        quantity_delta: data.quantity_delta,
        quantity_after: targetItem.stock_qty,
        note: data.note?.trim() || null,
        created_by: userId,
        created_at: new Date(),
      };
      sharedDemoMovements.unshift(movement);

      return {
        inventory: {
          ...targetItem,
          quantity: targetItem.stock_qty,
        },
        ingredient: targetItem,
        movement,
      };
    };

    if (!(await isDbAvailable())) {
      return applyDemoAdjustment();
    }

    try {
      return await prisma.$transaction(async (tx) => {
        // Ambil stok bahan baku terkini
        let ingredient = await tx.ingredient.findUnique({
          where: { id: targetIngredientId },
        });

        if (!ingredient) {
          ingredient = await tx.ingredient.findFirst({
            where: { outlet_id: data.outlet_id },
          });
        }

        if (!ingredient) {
          throw new AppError('NOT_FOUND', 404, 'Data bahan baku di cabang ini tidak ditemukan.');
        }

        const newQuantity = ingredient.stock_qty + data.quantity_delta;
        if (newQuantity < 0) {
          throw new AppError('INSUFFICIENT_STOCK', 400, `Stok bahan baku tidak mencukupi untuk pengurangan ini (stok saat ini: ${ingredient.stock_qty} ${ingredient.unit}).`);
        }

        // 1. Update jumlah stok di tabel Ingredient
        const updatedIngredient = await tx.ingredient.update({
          where: { id: ingredient.id },
          data: {
            stock_qty: newQuantity,
          },
          include: {
            outlet: { select: { id: true, name: true } },
          },
        });

        // 2. Buat rekaman audit mutasi (InventoryMovement)
        const movement = await tx.inventoryMovement.create({
          data: {
            outlet_id: data.outlet_id,
            ingredient_id: ingredient.id,
            movement_type: data.movement_type,
            quantity_delta: data.quantity_delta,
            quantity_after: newQuantity,
            note: data.note?.trim() || null,
            created_by: userId,
          },
          include: {
            ingredient: { select: { id: true, name: true, unit: true } },
            creator: { select: { id: true, name: true, role: true } },
          },
        });

        return {
          inventory: {
            ...updatedIngredient,
            quantity: updatedIngredient.stock_qty,
          },
          ingredient: {
            ...updatedIngredient,
            status: this.calculateStatus(updatedIngredient.stock_qty, updatedIngredient.reorder_level),
          },
          movement,
        };
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      return applyDemoAdjustment();
    }
  }

  /**
   * Riwayat Mutasi Bahan Baku (Audit Trail & Kartu Stok).
   */
  async listMovements(
    query: {
      outlet_id?: string;
      ingredient_id?: string;
      product_id?: string; // backwards compatibility
      movement_type?: MovementType;
      page?: number;
      page_size?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role === Role.staff) {
      throw new AppError('FORBIDDEN', 403, 'Role Staff (Kasir) tidak diizinkan melihat riwayat mutasi bahan baku.');
    }

    if (userScope.role === Role.manager) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke cabang ini tidak diizinkan untuk Manager.');
      }
    }

    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 30, 100);
    const skip = (page - 1) * pageSize;

    const where: any = {};

    if (userScope.role === Role.manager) {
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    const targetIngId = query.ingredient_id || query.product_id;
    if (targetIngId) where.ingredient_id = targetIngId;
    if (query.movement_type) where.movement_type = query.movement_type;

    if (!(await isDbAvailable())) {
      let filtered = [...sharedDemoMovements];
      if (query.outlet_id) filtered = filtered.filter((m) => m.outlet_id === query.outlet_id);
      if (targetIngId) filtered = filtered.filter((m) => m.ingredient_id === targetIngId);
      return {
        movements: filtered.slice(skip, skip + pageSize),
        meta: { page: 1, page_size: pageSize, total: filtered.length },
      };
    }

    const [total, movements] = await Promise.all([
      prisma.inventoryMovement.count({ where }),
      prisma.inventoryMovement.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { created_at: 'desc' },
        include: {
          ingredient: { select: { id: true, name: true, unit: true } },
          creator: { select: { id: true, name: true, role: true } },
          transaction: { select: { id: true, receipt_no: true } },
        },
      }),
    ]);

    return {
      movements,
      meta: {
        page,
        page_size: pageSize,
        total,
      },
    };
  }
}

export const inventoryService = new InventoryService();
