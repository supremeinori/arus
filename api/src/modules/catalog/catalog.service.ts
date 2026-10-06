import { PrismaClient, Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { isDbAvailable } from '../../config/db-health';
import { AppError } from '../../shared/errors';

export class CatalogService {
  // ----------------------------------------------------
  // CATEGORIES
  // ----------------------------------------------------
  async listCategories() {
    if (!(await isDbAvailable())) {
      return [
        { id: 'cat-001', name: 'Coffee', _count: { products: 5 } },
        { id: 'cat-002', name: 'Non-Coffee', _count: { products: 3 } },
        { id: 'cat-003', name: 'Pastry & Food', _count: { products: 4 } },
      ];
    }

    try {
      return await prisma.productCategory.findMany({
        orderBy: { name: 'asc' },
        include: {
          _count: {
            select: { products: true },
          },
        },
      });
    } catch (_) {
      return [
        { id: 'cat-001', name: 'Coffee', _count: { products: 5 } },
        { id: 'cat-002', name: 'Non-Coffee', _count: { products: 3 } },
        { id: 'cat-003', name: 'Pastry & Food', _count: { products: 4 } },
      ];
    }
  }

  async createCategory(name: string) {
    const existing = await prisma.productCategory.findUnique({
      where: { name: name.trim() },
    });
    if (existing) {
      throw new AppError('CATALOG_CATEGORY_DUPLICATE', 409, 'Kategori dengan nama tersebut sudah ada.');
    }

    return prisma.productCategory.create({
      data: { name: name.trim() },
    });
  }

  async updateCategory(id: string, name: string) {
    const existing = await prisma.productCategory.findUnique({ where: { id } });
    if (!existing) {
      throw new AppError('NOT_FOUND', 404, 'Kategori tidak ditemukan.');
    }

    return prisma.productCategory.update({
      where: { id },
      data: { name: name.trim() },
    });
  }

  // ----------------------------------------------------
  // PRODUCTS
  // ----------------------------------------------------
  async listProducts(
    userRole: Role,
    query: {
      category_id?: string;
      is_active?: string;
      q?: string;
      sort?: 'name' | 'price_asc' | 'price_desc' | 'created_at';
      page?: number;
      page_size?: number;
    }
  ) {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 20, 100);
    const skip = (page - 1) * pageSize;

    const where: any = {};

    // Filter kategori
    if (query.category_id) {
      where.category_id = query.category_id;
    }

    // Filter status aktif
    if (query.is_active !== undefined) {
      where.is_active = query.is_active === 'true';
    } else if (userRole === Role.staff) {
      // Kasir secara default hanya melihat produk aktif (SRS Section 6.3)
      where.is_active = true;
    }

    // Pencarian SKU atau Nama Produk
    if (query.q && query.q.trim().length > 0) {
      const searchTerm = query.q.trim();
      where.OR = [
        { name: { contains: searchTerm, mode: 'insensitive' } },
        { sku: { contains: searchTerm, mode: 'insensitive' } },
      ];
    }

    // Urutan (Sort)
    let orderBy: any = { name: 'asc' };
    if (query.sort === 'price_asc') orderBy = { price_idr: 'asc' };
    if (query.sort === 'price_desc') orderBy = { price_idr: 'desc' };
    if (query.sort === 'created_at') orderBy = { created_at: 'desc' };

    if (!(await isDbAvailable())) {
      const demoProducts = [
        { id: 'prod-001', name: 'Kopi Susu Gula Aren', sku: 'BEV-COF-01', price_idr: 22000, cost_idr: 8500, category_id: 'cat-001', is_active: true, category: { id: 'cat-001', name: 'Coffee' } },
        { id: 'prod-002', name: 'Americano Double Shot', sku: 'BEV-COF-02', price_idr: 18000, cost_idr: 5000, category_id: 'cat-001', is_active: true, category: { id: 'cat-001', name: 'Coffee' } },
        { id: 'prod-003', name: 'Matcha Latte Oatmilk', sku: 'BEV-NCH-01', price_idr: 28000, cost_idr: 11000, category_id: 'cat-002', is_active: true, category: { id: 'cat-002', name: 'Non-Coffee' } },
        { id: 'prod-004', name: 'Croissant Butter Original', sku: 'FOD-PST-01', price_idr: 25000, cost_idr: 12000, category_id: 'cat-003', is_active: true, category: { id: 'cat-003', name: 'Pastry & Food' } },
      ];

      return {
        products: demoProducts.map((p) => {
          const { cost_idr, ...rest } = p;
          return {
            ...rest,
            ...(userRole !== Role.staff ? { cost_idr } : {}),
          };
        }),
        meta: { page: 1, page_size: 20, total: demoProducts.length },
      };
    }

    try {
      const [total, products] = await Promise.all([
        prisma.product.count({ where }),
        prisma.product.findMany({
          where,
          skip,
          take: pageSize,
          orderBy,
          include: {
            category: {
              select: { id: true, name: true },
            },
          },
        }),
      ]);

      // PROTEKSI HPP: Sembunyikan cost_idr jika pemanggil adalah Staff (SRS Section 17)
      const sanitizedProducts = products.map((p) => {
        const { cost_idr, ...rest } = p;
        return {
          ...rest,
          ...(userRole !== Role.staff ? { cost_idr } : {}),
        };
      });

      return {
        products: sanitizedProducts,
        meta: {
          page,
          page_size: pageSize,
          total,
        },
      };
    } catch (_) {
      const demoProducts = [
        { id: 'prod-001', name: 'Kopi Susu Gula Aren', sku: 'BEV-COF-01', price_idr: 22000, cost_idr: 8500, category_id: 'cat-001', is_active: true, category: { id: 'cat-001', name: 'Coffee' } },
        { id: 'prod-002', name: 'Americano Double Shot', sku: 'BEV-COF-02', price_idr: 18000, cost_idr: 5000, category_id: 'cat-001', is_active: true, category: { id: 'cat-001', name: 'Coffee' } },
        { id: 'prod-003', name: 'Matcha Latte Oatmilk', sku: 'BEV-NCH-01', price_idr: 28000, cost_idr: 11000, category_id: 'cat-002', is_active: true, category: { id: 'cat-002', name: 'Non-Coffee' } },
        { id: 'prod-004', name: 'Croissant Butter Original', sku: 'FOD-PST-01', price_idr: 25000, cost_idr: 12000, category_id: 'cat-003', is_active: true, category: { id: 'cat-003', name: 'Pastry & Food' } },
      ];

      return {
        products: demoProducts.map((p) => {
          const { cost_idr, ...rest } = p;
          return {
            ...rest,
            ...(userRole !== Role.staff ? { cost_idr } : {}),
          };
        }),
        meta: { page: 1, page_size: 20, total: demoProducts.length },
      };
    }
  }

  async getProductById(id: string, userRole: Role) {
    const product = await prisma.product.findUnique({
      where: { id },
      include: {
        category: { select: { id: true, name: true } },
        inventory: {
          include: {
            outlet: { select: { id: true, name: true } },
          },
        },
      },
    });

    if (!product) {
      throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');
    }

    const { cost_idr, ...rest } = product;
    return {
      ...rest,
      ...(userRole !== Role.staff ? { cost_idr } : {}),
    };
  }

  async createProduct(
    userId: string,
    data: {
      name: string;
      sku: string;
      unit: string;
      price_idr: number;
      cost_idr?: number;
      category_id?: string;
    }
  ) {
    const existingSku = await prisma.product.findUnique({
      where: { sku: data.sku.trim() },
    });
    if (existingSku) {
      throw new AppError('CATALOG_SKU_DUPLICATE', 409, `SKU “${data.sku}” sudah digunakan.`);
    }

    if (data.category_id) {
      const categoryExists = await prisma.productCategory.findUnique({
        where: { id: data.category_id },
      });
      if (!categoryExists) {
        throw new AppError('NOT_FOUND', 404, 'Kategori yang dipilih tidak valid.');
      }
    }

    return prisma.$transaction(async (tx) => {
      const product = await tx.product.create({
        data: {
          name: data.name.trim(),
          sku: data.sku.trim().toUpperCase(),
          unit: data.unit.trim(),
          price_idr: data.price_idr,
          cost_idr: data.cost_idr,
          category_id: data.category_id,
          created_by: userId,
        },
        include: {
          category: true,
        },
      });

      // Inisialisasi baris inventory untuk seluruh outlet aktif (qty: 0)
      const outlets = await tx.outlet.findMany({
        where: { is_active: true },
        select: { id: true },
      });

      if (outlets.length > 0) {
        await tx.inventory.createMany({
          data: outlets.map((o) => ({
            outlet_id: o.id,
            product_id: product.id,
            quantity: 0,
            reorder_level: 5,
            avg_lead_time_days: 3,
          })),
        });
      }

      return product;
    });
  }

  async updateProduct(
    id: string,
    data: {
      name?: string;
      sku?: string;
      unit?: string;
      price_idr?: number;
      cost_idr?: number;
      category_id?: string | null;
      is_active?: boolean;
    }
  ) {
    const existing = await prisma.product.findUnique({ where: { id } });
    if (!existing) {
      throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');
    }

    if (data.sku && data.sku.trim().toUpperCase() !== existing.sku) {
      const duplicate = await prisma.product.findUnique({
        where: { sku: data.sku.trim().toUpperCase() },
      });
      if (duplicate) {
        throw new AppError('CATALOG_SKU_DUPLICATE', 409, `SKU “${data.sku}” sudah digunakan.`);
      }
    }

    return prisma.product.update({
      where: { id },
      data: {
        name: data.name?.trim(),
        sku: data.sku?.trim().toUpperCase(),
        unit: data.unit?.trim(),
        price_idr: data.price_idr,
        cost_idr: data.cost_idr,
        category_id: data.category_id,
        is_active: data.is_active,
      },
      include: {
        category: true,
      },
    });
  }
}

export const catalogService = new CatalogService();
