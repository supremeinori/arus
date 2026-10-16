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

interface InMemoryProduct {
  id: string;
  name: string;
  sku: string;
  price_idr: number;
  category_id?: string | null;
  image_url?: string | null;
  is_active: boolean;
  category?: { id: string; name: string } | null;
  recipes: Array<{
    id: string;
    product_id: string;
    ingredient_id: string;
    amount_needed: number;
    ingredient?: {
      id: string;
      outlet_id: string;
      name: string;
      unit: string;
      stock_qty: number;
      reorder_level: number;
      cost_per_unit: number;
    };
  }>;
  created_at: Date;
  updated_at: Date;
}

const inMemoryProducts: InMemoryProduct[] = [
  {
    id: 'prod-001',
    name: 'Es Kopi Susu Gula Aren',
    sku: 'BEV-COF-01',
    price_idr: 22000,
    category_id: 'cat-001',
    image_url: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=500&q=80',
    is_active: true,
    category: { id: 'cat-001', name: 'Coffee' },
    recipes: [
      {
        id: 'rec-001',
        product_id: 'prod-001',
        ingredient_id: 'ing-001',
        amount_needed: 20,
        ingredient: { id: 'ing-001', outlet_id: 'out-001', name: 'Biji Kopi Arabika House Blend', unit: 'gram', stock_qty: 2400, reorder_level: 500, cost_per_unit: 150 },
      },
      {
        id: 'rec-002',
        product_id: 'prod-001',
        ingredient_id: 'ing-002',
        amount_needed: 120,
        ingredient: { id: 'ing-002', outlet_id: 'out-001', name: 'Susu Fresh Milk UHT', unit: 'ml', stock_qty: 350, reorder_level: 1000, cost_per_unit: 20 },
      },
    ],
    created_at: new Date(),
    updated_at: new Date(),
  },
  {
    id: 'prod-002',
    name: 'Americano Dingin',
    sku: 'BEV-COF-02',
    price_idr: 18000,
    category_id: 'cat-001',
    image_url: 'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80',
    is_active: true,
    category: { id: 'cat-001', name: 'Coffee' },
    recipes: [
      {
        id: 'rec-003',
        product_id: 'prod-002',
        ingredient_id: 'ing-001',
        amount_needed: 20,
        ingredient: { id: 'ing-001', outlet_id: 'out-001', name: 'Biji Kopi Arabika House Blend', unit: 'gram', stock_qty: 2400, reorder_level: 500, cost_per_unit: 150 },
      },
      {
        id: 'rec-004',
        product_id: 'prod-002',
        ingredient_id: 'ing-003',
        amount_needed: 150,
        ingredient: { id: 'ing-003', outlet_id: 'out-001', name: 'Air Mineral Purified', unit: 'ml', stock_qty: 15000, reorder_level: 2000, cost_per_unit: 2 },
      },
    ],
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
  // PRODUCTS & ESTIMATED PORTIONS
  // ----------------------------------------------------
  /**
   * Menghitung estimasi porsi produk berdasarkan stok bahan baku di cabang:
   * estimated_portions = min(floor(stock_qty / amount_needed))
   * Jika tidak ada resep di cabang tersebut: estimated_portions = 0
   */
  private computeProductPortions(
    recipes: Array<{
      amount_needed: number;
      ingredient: { outlet_id: string; stock_qty: number; cost_per_unit: number };
    }>,
    targetOutletId?: string
  ): { estimated_portions: number; cost_idr: number } {
    const relevant = targetOutletId
      ? recipes.filter((r) => r.ingredient && r.ingredient.outlet_id === targetOutletId)
      : recipes;

    if (relevant.length === 0) {
      return { estimated_portions: 0, cost_idr: 0 };
    }

    const portions = relevant.map((r) => {
      const stock = r.ingredient ? r.ingredient.stock_qty : 0;
      if (r.amount_needed <= 0) return 0;
      return Math.floor(stock / r.amount_needed);
    });

    const costIdr = relevant.reduce((sum, r) => {
      const unitCost = r.ingredient ? r.ingredient.cost_per_unit : 0;
      return sum + r.amount_needed * unitCost;
    }, 0);

    const minPortion = Math.max(0, Math.min(...portions));
    return { estimated_portions: minPortion, cost_idr: costIdr };
  }

  async listProducts(
    userRole: Role | undefined,
    query: {
      outlet_id?: string;
      category_id?: string;
      is_active?: string;
      q?: string;
      sort?: 'name' | 'price_asc' | 'price_desc' | 'created_at';
      page?: number;
      page_size?: number;
    },
    allowedOutletIds: string[] = []
  ) {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 50, 100);
    const skip = (page - 1) * pageSize;

    // Tentukan outlet_id efektif:
    // Jika user adalah Staff, mereka harus melihat stok cabang tugas mereka
    let effectiveOutletId = query.outlet_id;
    if (!effectiveOutletId && allowedOutletIds.length > 0) {
      effectiveOutletId = allowedOutletIds[0];
    }

    if (!(await isDbAvailable())) {
      let filtered = [...inMemoryProducts];

      if (query.category_id) {
        filtered = filtered.filter((p) => p.category_id === query.category_id);
      }

      if (query.is_active !== undefined) {
        filtered = filtered.filter((p) => String(p.is_active) === query.is_active);
      } else if (userRole === Role.staff || !userRole) {
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

      const mapped = paginated.map((p) => {
        const { estimated_portions, cost_idr } = this.computeProductPortions(
          p.recipes as any,
          effectiveOutletId
        );

        const sanitizedRecipes = (p.recipes || []).map((r) => ({
          id: r.id,
          ingredient_id: r.ingredient_id,
          amount_needed: r.amount_needed,
          ingredient_name: r.ingredient?.name,
          ingredient_unit: r.ingredient?.unit,
          stock_qty: r.ingredient?.stock_qty,
          cost_per_unit: userRole !== Role.staff ? r.ingredient?.cost_per_unit : undefined,
        }));

        return {
          id: p.id,
          name: p.name,
          sku: p.sku,
          price_idr: p.price_idr,
          image_url: p.image_url,
          category_id: p.category_id,
          category: p.category,
          is_active: p.is_active,
          estimated_portions,
          cost_idr: userRole !== Role.staff ? cost_idr : undefined,
          recipes: sanitizedRecipes,
          created_at: p.created_at,
          updated_at: p.updated_at,
        };
      });

      return {
        products: mapped,
        meta: { page, page_size: pageSize, total: filtered.length },
      };
    }

    const where: any = {};

    if (query.category_id) {
      where.category_id = query.category_id;
    }

    if (query.is_active !== undefined) {
      where.is_active = query.is_active === 'true';
    } else if (userRole === Role.staff || !userRole) {
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
            recipes: {
              include: {
                ingredient: {
                  select: {
                    id: true,
                    outlet_id: true,
                    name: true,
                    unit: true,
                    stock_qty: true,
                    reorder_level: true,
                    cost_per_unit: true,
                  },
                },
              },
            },
          },
        }),
      ]);

      const mapped = products.map((p) => {
        const { estimated_portions, cost_idr } = this.computeProductPortions(
          p.recipes as any,
          effectiveOutletId
        );

        const sanitizedRecipes = (p.recipes || []).map((r) => ({
          id: r.id,
          ingredient_id: r.ingredient_id,
          amount_needed: r.amount_needed,
          ingredient_name: r.ingredient.name,
          ingredient_unit: r.ingredient.unit,
          stock_qty: r.ingredient.stock_qty,
          cost_per_unit: userRole !== Role.staff ? r.ingredient.cost_per_unit : undefined,
        }));

        return {
          id: p.id,
          name: p.name,
          sku: p.sku,
          price_idr: p.price_idr,
          image_url: p.image_url,
          category_id: p.category_id,
          category: p.category,
          is_active: p.is_active,
          estimated_portions,
          cost_idr: userRole !== Role.staff ? cost_idr : undefined,
          recipes: sanitizedRecipes,
          created_at: p.created_at,
          updated_at: p.updated_at,
        };
      });

      return {
        products: mapped,
        meta: {
          page,
          page_size: pageSize,
          total,
        },
      };
    } catch (_) {
      return {
        products: [],
        meta: { page: 1, page_size: pageSize, total: 0 },
      };
    }
  }

  async getProductById(id: string, userRole?: Role, targetOutletId?: string) {
    if (!(await isDbAvailable())) {
      const product = inMemoryProducts.find((p) => p.id === id);
      if (!product) {
        throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');
      }
      const { estimated_portions, cost_idr } = this.computeProductPortions(
        product.recipes as any,
        targetOutletId
      );
      return {
        ...product,
        estimated_portions,
        cost_idr: userRole !== Role.staff ? cost_idr : undefined,
      };
    }

    const product = await prisma.product.findUnique({
      where: { id },
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
                reorder_level: true,
                cost_per_unit: true,
              },
            },
          },
        },
      },
    });

    if (!product) {
      throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');
    }

    const { estimated_portions, cost_idr } = this.computeProductPortions(
      product.recipes as any,
      targetOutletId
    );

    const sanitizedRecipes = (product.recipes || []).map((r) => ({
      id: r.id,
      ingredient_id: r.ingredient_id,
      amount_needed: r.amount_needed,
      ingredient_name: r.ingredient.name,
      ingredient_unit: r.ingredient.unit,
      stock_qty: r.ingredient.stock_qty,
      cost_per_unit: userRole !== Role.staff ? r.ingredient.cost_per_unit : undefined,
    }));

    return {
      id: product.id,
      name: product.name,
      sku: product.sku,
      price_idr: product.price_idr,
      image_url: product.image_url,
      category_id: product.category_id,
      category: product.category,
      is_active: product.is_active,
      estimated_portions,
      cost_idr: userRole !== Role.staff ? cost_idr : undefined,
      recipes: sanitizedRecipes,
      created_at: product.created_at,
      updated_at: product.updated_at,
    };
  }

  async createProduct(
    userId: string,
    data: {
      name: string;
      sku: string;
      price_idr: number;
      category_id?: string;
      image_url?: string;
      recipes?: Array<{ ingredient_id: string; amount_needed: number }>;
    }
  ) {
    if (!(await isDbAvailable())) {
      const existingSku = inMemoryProducts.find((p) => p.sku.toLowerCase() === data.sku.trim().toLowerCase());
      if (existingSku) {
        throw new AppError('CATALOG_SKU_DUPLICATE', 409, `SKU “${data.sku}” sudah digunakan.`);
      }

      const cat = inMemoryCategories.find((c) => c.id === data.category_id);
      const newProduct: InMemoryProduct = {
        id: `prod-${Date.now()}`,
        name: data.name.trim(),
        sku: data.sku.trim().toUpperCase(),
        price_idr: data.price_idr,
        category_id: data.category_id || null,
        image_url: data.image_url || null,
        is_active: true,
        category: cat ? { id: cat.id, name: cat.name } : null,
        recipes: (data.recipes || []).map((r, idx) => ({
          id: `rec-${Date.now()}-${idx}`,
          product_id: `prod-${Date.now()}`,
          ingredient_id: r.ingredient_id,
          amount_needed: r.amount_needed,
        })),
        created_at: new Date(),
        updated_at: new Date(),
      };

      inMemoryProducts.unshift(newProduct);
      return newProduct;
    }

    const existingSku = await prisma.product.findUnique({
      where: { sku: data.sku.trim().toUpperCase() },
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
          price_idr: data.price_idr,
          category_id: data.category_id,
          image_url: data.image_url,
        },
        include: {
          category: true,
        },
      });

      if (data.recipes && data.recipes.length > 0) {
        await tx.productRecipe.createMany({
          data: data.recipes.map((r) => ({
            product_id: product.id,
            ingredient_id: r.ingredient_id,
            amount_needed: r.amount_needed,
          })),
        });
      }

      const withRecipes = await tx.product.findUnique({
        where: { id: product.id },
        include: {
          category: true,
          recipes: {
            include: {
              ingredient: true,
            },
          },
        },
      });

      return withRecipes;
    });
  }

  async updateProduct(
    id: string,
    data: {
      name?: string;
      sku?: string;
      price_idr?: number;
      category_id?: string | null;
      image_url?: string | null;
      is_active?: boolean;
      recipes?: Array<{ ingredient_id: string; amount_needed: number }>;
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
      if (data.price_idr !== undefined) existing.price_idr = data.price_idr;
      if (data.category_id !== undefined) {
        existing.category_id = data.category_id;
        const cat = inMemoryCategories.find((c) => c.id === data.category_id);
        existing.category = cat ? { id: cat.id, name: cat.name } : null;
      }
      if (data.image_url !== undefined) existing.image_url = data.image_url;
      if (data.is_active !== undefined) existing.is_active = data.is_active;

      if (data.recipes !== undefined) {
        existing.recipes = data.recipes.map((r, idx) => ({
          id: `rec-${Date.now()}-${idx}`,
          product_id: id,
          ingredient_id: r.ingredient_id,
          amount_needed: r.amount_needed,
        }));
      }

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

    return prisma.$transaction(async (tx) => {
      const updated = await tx.product.update({
        where: { id },
        data: {
          name: data.name?.trim(),
          sku: data.sku?.trim().toUpperCase(),
          price_idr: data.price_idr,
          category_id: data.category_id,
          image_url: data.image_url,
          is_active: data.is_active,
        },
        include: {
          category: true,
        },
      });

      if (data.recipes !== undefined) {
        // Hapus resep lama dan masukkan resep baru
        await tx.productRecipe.deleteMany({
          where: { product_id: id },
        });

        if (data.recipes.length > 0) {
          await tx.productRecipe.createMany({
            data: data.recipes.map((r) => ({
              product_id: id,
              ingredient_id: r.ingredient_id,
              amount_needed: r.amount_needed,
            })),
          });
        }
      }

      return tx.product.findUnique({
        where: { id },
        include: {
          category: true,
          recipes: {
            include: {
              ingredient: true,
            },
          },
        },
      });
    });
  }

  async deleteProduct(id: string) {
    if (!(await isDbAvailable())) {
      const prod = inMemoryProducts.find((p) => p.id === id);
      if (!prod) throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');
      prod.is_active = false;
      return { success: true, message: `Produk “${prod.name}” dinonaktifkan.` };
    }

    const prod = await prisma.product.findUnique({ where: { id } });
    if (!prod) throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');

    await prisma.product.update({
      where: { id },
      data: { is_active: false },
    });

    return { success: true, message: `Produk “${prod.name}” dinonaktifkan.` };
  }
}

export const catalogService = new CatalogService();
