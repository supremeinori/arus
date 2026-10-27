import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import { Role, TxnStatus } from '@prisma/client';
import { CreateOutletInput, UpdateOutletInput } from './outlets.schema';

export function calculateHaversineDistanceKm(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // Radius bumi dalam km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Number((R * c).toFixed(2));
}

export class OutletsService {
  async listOutlets(user: { id: string; role: Role }, userOutlets: string[]) {
    const isOwner = user.role === Role.owner;
    const where: any = {};

    if (!isOwner) {
      where.is_active = true;
      if (user.role !== Role.manager) {
        where.id = { in: userOutlets };
      }
    }

    try {
      const outlets = await prisma.outlet.findMany({
        where,
        orderBy: { name: 'asc' },
        include: {
          _count: {
            select: {
              ingredients: true,
              users: true,
            },
          },
        },
      });

      return outlets.map((o) => ({
        id: o.id,
        name: o.name,
        address: o.address,
        latitude: Number(o.latitude),
        longitude: Number(o.longitude),
        timezone: o.timezone,
        is_active: o.is_active,
        inventory_count: o._count.ingredients,
        assigned_users_count: o._count.users,
        created_at: o.created_at,
      }));
    } catch (err: unknown) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 500, 'Gagal mengambil data outlet dari database.');
    }
  }

  async getOutletById(id: string) {
    const outlet = await prisma.outlet.findUnique({
      where: { id },
      include: {
        users: {
          include: {
            user: { select: { id: true, name: true, email: true, role: true } },
          },
        },
        _count: {
          select: {
            ingredients: true,
            transactions: true,
          },
        },
      },
    });

    if (!outlet) {
      throw new AppError('NOT_FOUND', 404, 'Outlet tidak ditemukan.');
    }

    return {
      id: outlet.id,
      name: outlet.name,
      address: outlet.address,
      latitude: Number(outlet.latitude),
      longitude: Number(outlet.longitude),
      timezone: outlet.timezone,
      is_active: outlet.is_active,
      assigned_staff: outlet.users.map((uo) => uo.user),
      inventory_count: outlet._count.ingredients,
      transaction_count: outlet._count.transactions,
      created_at: outlet.created_at,
    };
  }

  async createOutlet(input: CreateOutletInput) {
    const existing = await prisma.outlet.findUnique({
      where: { name: input.name },
    });

    if (existing) {
      throw new AppError('OUTLET_NAME_DUPLICATE', 409, `Outlet dengan nama “${input.name}” sudah ada.`);
    }

    const outlet = await prisma.outlet.create({
      data: {
        name: input.name,
        address: input.address,
        latitude: input.latitude,
        longitude: input.longitude,
        timezone: input.timezone || 'Asia/Jakarta',
        is_active: input.is_active ?? true,
      },
    });

    return {
      ...outlet,
      latitude: Number(outlet.latitude),
      longitude: Number(outlet.longitude),
    };
  }

  async updateOutlet(id: string, input: UpdateOutletInput) {
    const outlet = await prisma.outlet.findUnique({ where: { id } });
    if (!outlet) {
      throw new AppError('NOT_FOUND', 404, 'Outlet tidak ditemukan.');
    }

    if (input.name && input.name !== outlet.name) {
      const existing = await prisma.outlet.findUnique({ where: { name: input.name } });
      if (existing) {
        throw new AppError('OUTLET_NAME_DUPLICATE', 409, `Outlet dengan nama “${input.name}” sudah ada.`);
      }
    }

    const updated = await prisma.outlet.update({
      where: { id },
      data: input,
    });

    return {
      ...updated,
      latitude: Number(updated.latitude),
      longitude: Number(updated.longitude),
    };
  }

  /**
   * Menghitung indikator performa untuk pewarnaan peta LBS (optimal / warning / critical).
   */
  async deactivateOutlet(id: string) {
    const outlet = await prisma.outlet.findUnique({ where: { id } });
    if (!outlet) {
      throw new AppError('NOT_FOUND', 404, 'Outlet tidak ditemukan.');
    }

    const updated = await prisma.outlet.update({
      where: { id },
      data: { is_active: false },
    });

    return {
      ...updated,
      latitude: Number(updated.latitude),
      longitude: Number(updated.longitude),
    };
  }

  async getOutletsPerformance() {
    const outlets = await prisma.outlet.findMany({
      where: { is_active: true },
      include: {
        ingredients: {
          select: { stock_qty: true, reorder_level: true },
        },
      },
    });

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const results = [];

    for (const o of outlets) {
      const txAgg = await prisma.transaction.aggregate({
        where: {
          outlet_id: o.id,
          status: TxnStatus.completed,
          created_at: { gte: thirtyDaysAgo },
        },
        _sum: { total_idr: true },
        _count: { id: true },
      });

      const totalRevenue = txAgg._sum.total_idr || 0;
      const txCount = txAgg._count.id || 0;

      // Hitung stok menipis
      const lowStockCount = (o.ingredients || []).filter((inv) => inv.stock_qty <= inv.reorder_level).length;

      // Pewarnaan status performa (Optimal: green, Warning: amber, Critical: red)
      let performanceStatus: 'optimal' | 'warning' | 'critical' = 'optimal';
      if (lowStockCount > 5 || totalRevenue === 0) {
        performanceStatus = 'critical';
      } else if (lowStockCount > 0 || totalRevenue < 5000000) {
        performanceStatus = 'warning';
      }

      results.push({
        outlet_id: o.id,
        name: o.name,
        address: o.address,
        latitude: Number(o.latitude),
        longitude: Number(o.longitude),
        timezone: o.timezone,
        revenue_30d_idr: totalRevenue,
        transaction_count_30d: txCount,
        low_stock_count: lowStockCount,
        performance_status: performanceStatus,
      });
    }

    return results;
  }

  /**
   * Menghitung cabang terdekat berdasarkan koordinat pengguna (Haversine Distance).
   */
  async getNearestOutlet(userLat: number, userLng: number) {
    const outlets = await prisma.outlet.findMany({
      where: { is_active: true },
    });

    if (outlets.length === 0) {
      throw new AppError('NOT_FOUND', 404, 'Tidak ada outlet aktif yang ditemukan.');
    }

    const calculated = outlets.map((o) => {
      const distKm = calculateHaversineDistanceKm(
        userLat,
        userLng,
        Number(o.latitude),
        Number(o.longitude)
      );

      return {
        id: o.id,
        name: o.name,
        address: o.address,
        latitude: Number(o.latitude),
        longitude: Number(o.longitude),
        timezone: o.timezone,
        distance_km: distKm,
      };
    });

    calculated.sort((a, b) => a.distance_km - b.distance_km);

    return {
      user_coordinates: { latitude: userLat, longitude: userLng },
      nearest_outlet: calculated[0],
      all_outlets_sorted: calculated,
    };
  }
}

export const outletsService = new OutletsService();
