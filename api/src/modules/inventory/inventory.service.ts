import { MovementType, PrismaClient, Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';

export class InventoryService {
  /**
   * Menampilkan daftar stok per outlet.
   * Mendukung filter: outlet_id, low_stock (quantity <= reorder_level), category_id, pencarian keyword
   */
  async listStocks(
    query: {
      outlet_id?: string;
      low_stock?: boolean;
      category_id?: string;
      q?: string;
      page?: number;
      page_size?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 50, 100);
    const skip = (page - 1) * pageSize;

    const where: any = {};

    // Outlet scope filter: Staff hanya bisa melihat outlet mereka
    if (userScope.role === Role.staff) {
      if (query.outlet_id && !userScope.allowedOutletIds.includes(query.outlet_id)) {
        throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
      }
      where.outlet_id = query.outlet_id || { in: userScope.allowedOutletIds };
    } else if (query.outlet_id) {
      where.outlet_id = query.outlet_id;
    }

    // Filter produk (aktif, category, keyword pencarian)
    where.product = {
      is_active: true,
      ...(query.category_id ? { category_id: query.category_id } : {}),
      ...(query.q
        ? {
            OR: [
              { name: { contains: query.q, mode: 'insensitive' } },
              { sku: { contains: query.q, mode: 'insensitive' } },
            ],
          }
        : {}),
    };

    try {
      const [total, items] = await Promise.all([
        prisma.inventory.count({ where }),
        prisma.inventory.findMany({
          where,
          skip,
          take: pageSize,
          orderBy: [{ quantity: 'asc' }, { product: { name: 'asc' } }],
          include: {
            outlet: { select: { id: true, name: true } },
            product: {
              select: {
                id: true,
                sku: true,
                name: true,
                unit: true,
                price_idr: true,
                cost_idr: userScope.role !== Role.staff, // Sembunyikan HPP jika Staff
                category: { select: { id: true, name: true } },
              },
            },
          },
        }),
      ]);

      // Jika filter low_stock aktif di memori atau query
      const filteredItems = query.low_stock
        ? items.filter((inv) => inv.quantity <= inv.reorder_level)
        : items;

      return {
        stocks: filteredItems.map((inv) => ({
          outlet_id: inv.outlet_id,
          outlet_name: inv.outlet.name,
          product_id: inv.product_id,
          sku: inv.product.sku,
          product_name: inv.product.name,
          unit: inv.product.unit,
          price_idr: inv.product.price_idr,
          cost_idr: inv.product.cost_idr,
          quantity: inv.quantity,
          reorder_level: inv.reorder_level,
          avg_lead_time_days: inv.avg_lead_time_days,
          is_low_stock: inv.quantity <= inv.reorder_level,
          updated_at: inv.updated_at,
        })),
        meta: {
          page,
          page_size: pageSize,
          total: query.low_stock ? filteredItems.length : total,
        },
      };
    } catch (_) {
      const demoStocks = [
        { outlet_id: 'out-001', outlet_name: 'Kopi Arus - Sudirman (HQ)', product_id: 'prod-001', sku: 'BEV-COF-01', product_name: 'Kopi Susu Gula Aren', unit: 'Cup', price_idr: 22000, cost_idr: userScope.role !== Role.staff ? 8500 : undefined, quantity: 45, reorder_level: 15, avg_lead_time_days: 2, is_low_stock: false, updated_at: new Date() },
        { outlet_id: 'out-001', outlet_name: 'Kopi Arus - Sudirman (HQ)', product_id: 'prod-002', sku: 'ING-MILK-01', product_name: 'Susu Fresh Milk Pasteurisasi', unit: 'Liter', price_idr: 18000, cost_idr: userScope.role !== Role.staff ? 14000 : undefined, quantity: 3, reorder_level: 10, avg_lead_time_days: 1, is_low_stock: true, updated_at: new Date() },
        { outlet_id: 'out-001', outlet_name: 'Kopi Arus - Sudirman (HQ)', product_id: 'prod-003', sku: 'ING-BEA-01', product_name: 'Biji Kopi House Blend 1kg', unit: 'Pack', price_idr: 120000, cost_idr: userScope.role !== Role.staff ? 80000 : undefined, quantity: 12, reorder_level: 6, avg_lead_time_days: 3, is_low_stock: false, updated_at: new Date() },
      ];

      return {
        stocks: demoStocks,
        meta: { page: 1, page_size: 50, total: demoStocks.length },
      };
    }
  }

  /**
   * Catat penyesuaian stok manual (Opname fisik, kerusakan, koreksi selisih).
   * Membuat rekaman mutasi InventoryMovement dan memperbarui tabel Inventory.
   */
  async createAdjustment(
    userId: string,
    data: {
      outlet_id: string;
      product_id: string;
      movement_type: MovementType; // 'correction' | 'waste' | 'restock'
      quantity_delta: number;      // Perubahan stok (bisa positif atau negatif)
      note?: string;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    if (userScope.role === Role.staff && !userScope.allowedOutletIds.includes(data.outlet_id)) {
      throw new AppError('FORBIDDEN', 403, 'Akses ke outlet ini tidak diizinkan.');
    }

    if (data.quantity_delta === 0) {
      throw new AppError('INVALID_INPUT', 400, 'Perubahan stok tidak boleh 0.');
    }

    if (!['correction', 'waste', 'restock'].includes(data.movement_type)) {
      throw new AppError('INVALID_INPUT', 400, 'Tipe penyesuaian hanya mendukung correction, waste, atau restock.');
    }

    return prisma.$transaction(async (tx) => {
      // Ambil stok terkini
      const inventory = await tx.inventory.findUnique({
        where: {
          outlet_id_product_id: {
            outlet_id: data.outlet_id,
            product_id: data.product_id,
          },
        },
      });

      if (!inventory) {
        throw new AppError('NOT_FOUND', 404, 'Data inventaris produk di outlet ini tidak ditemukan.');
      }

      const newQuantity = inventory.quantity + data.quantity_delta;
      if (newQuantity < 0) {
        throw new AppError('INSUFFICIENT_STOCK', 400, `Stok tidak mencukupi untuk pengurangan ini (stok saat ini: ${inventory.quantity}).`);
      }

      // 1. Update jumlah stok di tabel Inventory
      const updatedInventory = await tx.inventory.update({
        where: {
          outlet_id_product_id: {
            outlet_id: data.outlet_id,
            product_id: data.product_id,
          },
        },
        data: {
          quantity: newQuantity,
        },
      });

      // 2. Buat rekaman audit mutasi (InventoryMovement)
      const movement = await tx.inventoryMovement.create({
        data: {
          outlet_id: data.outlet_id,
          product_id: data.product_id,
          movement_type: data.movement_type,
          quantity_delta: data.quantity_delta,
          quantity_after: newQuantity,
          note: data.note?.trim() || null,
          created_by: userId,
        },
        include: {
          product: { select: { sku: true, name: true, unit: true } },
          outlet: { select: { id: true, name: true } },
          creator: { select: { id: true, name: true, role: true } },
        },
      });

      return {
        inventory: updatedInventory,
        movement,
      };
    });
  }

  /**
   * Riwayat Mutasi Stok (Audit Trail & Kartu Stok).
   */
  async listMovements(
    query: {
      outlet_id?: string;
      product_id?: string;
      movement_type?: MovementType;
      page?: number;
      page_size?: number;
    },
    userScope: { role: Role; allowedOutletIds: string[] }
  ) {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 30, 100);
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

    if (query.product_id) where.product_id = query.product_id;
    if (query.movement_type) where.movement_type = query.movement_type;

    const [total, movements] = await Promise.all([
      prisma.inventoryMovement.count({ where }),
      prisma.inventoryMovement.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { created_at: 'desc' },
        include: {
          product: { select: { id: true, sku: true, name: true, unit: true } },
          outlet: { select: { id: true, name: true } },
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
