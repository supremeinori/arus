import { PrismaClient, Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { isDbAvailable } from '../../config/db-health';
import { AppError } from '../../shared/errors';

// Data in-memory saat database PostgreSQL offline
const inMemoryCategories = [
  { id: 'cat-001', name: 'Coffee', _count: { products: 5 } },
  { id: 'cat-002', name: 'Non-Coffee', _count: { products: 3 } },
  { id: 'cat-003', name: 'Pastry & Food', _count: { products: 4 } },
];

const inMemoryProducts: Array<{
  id: string;
  name: string;
  sku: string;
  unit: string;
  price_idr: number;
  cost_idr?: number;
  category_id?: string | null;
  is_active: boolean;
  category?: { id: string; name: string } | null;
  created_at: Date;
  updated_at: Date;
}> = [
  {
    id: 'prod-001',
    name: 'Kopi Susu Gula Aren',
    sku: 'BEV-COF-01',
    unit: 'cup',
    price_idr: 22000,
    cost_idr: 8500,
    category_id: 'cat-001',
    is_active: true,
    category: { id: 'cat-001', name: 'Coffee' },
    created_at: new Date(),
    updated_at: new Date(),
  },
  {
    id: 'prod-002',
    name: 'Americano Double Shot',
    sku: 'BEV-COF-02',
    unit: 'cup',
    price_idr: 18000,
    cost_idr: 5000,
    category_id: 'cat-001',
    is_active: true,
    category: { id: 'cat-001', name: 'Coffee' },
    created_at: new Date(),
    updated_at: new Date(),
  },
  {
    id: 'prod-003',
    name: 'Matcha Latte Oatmilk',
    sku: 'BEV-NCH-01',
    unit: 'cup',
    price_idr: 28000,
    cost_idr: 11000,
    category_id: 'cat-002',
    is_active: true,
    category: { id: 'cat-002', name: 'Non-Coffee' },
    created_at: new Date(),
    updated_at: new Date(),
  },
  {
    id: 'prod-004',
    name: 'Croissant Butter Original',
    sku: 'FOD-PST-01',
    unit: 'pcs',
    price_idr: 25000,
    cost_idr: 12000,
    category_id: 'cat-003',
    is_active: true,
    category: { id: 'cat-003', name: 'Pastry & Food' },
    created_at: new Date(),
    updated_at: new Date(),
  },
];

export class CatalogService {
  // ----------------------------------------------------
  // CATEGORIES
  // ----------------------------------------------------
  async listCategories() {
    if (!(await isDbAvailable())) {
      return [...inMemoryCategories];
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
      return [...inMemoryCategories];
    }
  }

  async createCategory(name: string) {
    if (!(await isDbAvailable())) {
      const existing = inMemoryCategories.find((c) => c.name.toLowerCase() === name.trim().toLowerCase());
      if (existing) {
        throw new AppError('CATALOG_CATEGORY_DUPLICATE', 409, 'Kategori dengan nama tersebut sudah ada.');
      }
      const newCat = {
        id: `cat-${Date.now()}`,
        name: name.trim(),
        _count: { products: 0 },
      };
      inMemoryCategories.push(newCat);
      return newCat;
    }

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
    if (!(await isDbAvailable())) {
      const cat = inMemoryCategories.find((c) => c.id === id);
      if (!cat) {
        throw new AppError('NOT_FOUND', 404, 'Kategori tidak ditemukan.');
      }
      cat.name = name.trim();
      return cat;
    }

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

    if (!(await isDbAvailable())) {
      let filtered = [...inMemoryProducts];

      if (query.category_id) {
        filtered = filtered.filter((p) => p.category_id === query.category_id);
      }

      if (query.is_active !== undefined) {
        filtered = filtered.filter((p) => String(p.is_active) === query.is_active);
      } else if (userRole === Role.staff) {
        filtered = filtered.filter((p) => p.is_active);
      }

      if (query.q && query.q.trim().length > 0) {
        const q = query.q.trim().toLowerCase();
        filtered = filtered.filter(
          (p) => p.name.toLowerCase().includes(q) || p.sku.toLowerCase().includes(q)
        );
      }

      if (query.sort === 'price_asc') {
        filtered.sort((a, b) => a.price_idr - b.price_idr);
      } else if (query.sort === 'price_desc') {
        filtered.sort((a, b) => b.price_idr - a.price_idr);
      } else if (query.sort === 'created_at') {
        filtered.sort((a, b) => b.created_at.getTime() - a.created_at.getTime());
      } else {
        filtered.sort((a, b) => a.name.localeCompare(b.name));
      }

      const paginated = filtered.slice(skip, skip + pageSize);

      return {
        products: paginated.map((p) => {
          const { cost_idr, ...rest } = p;
          return {
            ...rest,
            ...(userRole !== Role.staff ? { cost_idr } : {}),
          };
        }),
        meta: { page, page_size: pageSize, total: filtered.length },
      };
    }

    const where: any = {};

    if (query.category_id) {
      where.category_id = query.category_id;
    }

    if (query.is_active !== undefined) {
      where.is_active = query.is_active === 'true';
    } else if (userRole === Role.staff) {
      where.is_active = true;
    }

    if (query.q && query.q.trim().length > 0) {
      const searchTerm = query.q.trim();
      where.OR = [
        { name: { contains: searchTerm, mode: 'insensitive' } },
        { sku: { contains: searchTerm, mode: 'insensitive' } },
      ];
    }

    let orderBy: any = { name: 'asc' };
    if (query.sort === 'price_asc') orderBy = { price_idr: 'asc' };
    if (query.sort === 'price_desc') orderBy = { price_idr: 'desc' };
    if (query.sort === 'created_at') orderBy = { created_at: 'desc' };

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

      return {
        products: products.map((p) => {
          const { cost_idr, ...rest } = p;
          return {
            ...rest,
            ...(userRole !== Role.staff ? { cost_idr } : {}),
          };
        }),
        meta: {
          page,
          page_size: pageSize,
          total,
        },
      };
    } catch (_) {
      return {
        products: inMemoryProducts.map((p) => {
          const { cost_idr, ...rest } = p;
          return {
            ...rest,
            ...(userRole !== Role.staff ? { cost_idr } : {}),
          };
        }),
        meta: { page: 1, page_size: 20, total: inMemoryProducts.length },
      };
    }
  }

  async getProductById(id: string, userRole: Role) {
    if (!(await isDbAvailable())) {
      const product = inMemoryProducts.find((p) => p.id === id);
      if (!product) {
        throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');
      }
      const { cost_idr, ...rest } = product;
      return {
        ...rest,
        inventory: [],
        ...(userRole !== Role.staff ? { cost_idr } : {}),
      };
    }

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
    if (!(await isDbAvailable())) {
      const existingSku = inMemoryProducts.find((p) => p.sku.toLowerCase() === data.sku.trim().toLowerCase());
      if (existingSku) {
        throw new AppError('CATALOG_SKU_DUPLICATE', 409, `SKU “${data.sku}” sudah digunakan.`);
      }

      const cat = inMemoryCategories.find((c) => c.id === data.category_id);
      const newProduct = {
        id: `prod-${Date.now()}`,
        name: data.name.trim(),
        sku: data.sku.trim().toUpperCase(),
        unit: data.unit.trim(),
        price_idr: data.price_idr,
        cost_idr: data.cost_idr,
        category_id: data.category_id || null,
        is_active: true,
        category: cat ? { id: cat.id, name: cat.name } : null,
        created_at: new Date(),
        updated_at: new Date(),
      };

      inMemoryProducts.unshift(newProduct);
      return newProduct;
    }

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
          image_url: (data as any).image_url,
        },
        include: {
          category: true,
        },
      });

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
    if (!(await isDbAvailable())) {
      const existing = inMemoryProducts.find((p) => p.id === id);
      if (!existing) {
        throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');
      }

      if (data.sku && data.sku.trim().toUpperCase() !== existing.sku) {
        const duplicate = inMemoryProducts.find(
          (p) => p.id !== id && p.sku.toLowerCase() === data.sku!.trim().toLowerCase()
        );
        if (duplicate) {
          throw new AppError('CATALOG_SKU_DUPLICATE', 409, `SKU “${data.sku}” sudah digunakan.`);
        }
      }

      if (data.name !== undefined) existing.name = data.name.trim();
      if (data.sku !== undefined) existing.sku = data.sku.trim().toUpperCase();
      if (data.unit !== undefined) existing.unit = data.unit.trim();
      if (data.price_idr !== undefined) existing.price_idr = data.price_idr;
      if (data.cost_idr !== undefined) existing.cost_idr = data.cost_idr;
      if (data.category_id !== undefined) {
        existing.category_id = data.category_id;
        const cat = inMemoryCategories.find((c) => c.id === data.category_id);
        existing.category = cat ? { id: cat.id, name: cat.name } : null;
      }
      if (data.is_active !== undefined) existing.is_active = data.is_active;
      existing.updated_at = new Date();

      return existing;
    }

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
