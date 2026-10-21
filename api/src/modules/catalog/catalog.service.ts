import { Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';

export class CatalogService {
  // ----------------------------------------------------
  // CATEGORIES
  // ----------------------------------------------------
  async listCategories() {
    try {
      return await prisma.productCategory.findMany({
        orderBy: { name: 'asc' },
        include: {
          _count: {
            select: { products: true },
          },
        },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memuat kategori produk.');
    }
  }

  async createCategory(name: string) {
    const existing = await prisma.productCategory.findUnique({
      where: { name: name.trim() },
    });
    if (existing) {
      throw new AppError('CATALOG_CATEGORY_DUPLICATE', 409, 'Kategori dengan nama tersebut sudah ada.');
    }

    try {
      return await prisma.productCategory.create({
        data: { name: name.trim() },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal menambahkan kategori.');
    }
  }

  async updateCategory(id: string, name: string) {
    const existing = await prisma.productCategory.findUnique({ where: { id } });
    if (!existing) {
      throw new AppError('NOT_FOUND', 404, 'Kategori tidak ditemukan.');
    }

    try {
      return await prisma.productCategory.update({
        where: { id },
        data: { name: name.trim() },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memperbarui kategori.');
    }
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
    recipes?: Array<{
      amount_needed: number;
      ingredient?: { outlet_id: string; stock_qty: number; cost_per_unit: number };
    }>,
    targetOutletId?: string,
    defaultCost: number = 0
  ): { estimated_portions: number; cost_idr: number } {
    if (!recipes || !Array.isArray(recipes) || recipes.length === 0) {
      return { estimated_portions: 0, cost_idr: defaultCost };
    }

    const relevant = targetOutletId
      ? recipes.filter((r) => r.ingredient && r.ingredient.outlet_id === targetOutletId)
      : recipes;

    if (!relevant || relevant.length === 0) {
      return { estimated_portions: 0, cost_idr: defaultCost };
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
    return { estimated_portions: minPortion, cost_idr: costIdr > 0 ? costIdr : defaultCost };
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

    let effectiveOutletId = query.outlet_id;
    if (!effectiveOutletId && allowedOutletIds.length > 0) {
      effectiveOutletId = allowedOutletIds[0];
    }

    const where: any = {};

    if (query.category_id) {
      where.category_id = query.category_id;
    }

    if (query.is_active !== undefined) {
      if (query.is_active === 'all') {
        // 'all' → tidak ada filter is_active (aktif + nonaktif sekaligus).
        // Staff tetap hanya melihat menu aktif.
        if (userRole === Role.staff || !userRole) {
          where.is_active = true;
        }
      } else {
        where.is_active = query.is_active === 'true';
      }
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
          effectiveOutletId,
          (p as any).cost_idr ?? 0
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
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memuat produk.');
    }
  }

  async getProductById(id: string, userRole?: Role, targetOutletId?: string) {
    try {
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
        targetOutletId,
        (product as any).cost_idr ?? 0
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
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memuat detail produk.');
    }
  }

  async createProduct(
    _userId: string,
    data: {
      name: string;
      sku: string;
      price_idr: number;
      category_id?: string;
      image_url?: string;
      recipes?: Array<{ ingredient_id: string; amount_needed: number }>;
    }
  ) {
    const sku = data.sku.trim().toUpperCase();
    const existingSku = await prisma.product.findUnique({
      where: { sku },
    });
    if (existingSku) {
      throw new AppError('CATALOG_SKU_DUPLICATE', 409, `SKU "${sku}" sudah digunakan.`);
    }

    if (data.category_id) {
      const categoryExists = await prisma.productCategory.findUnique({
        where: { id: data.category_id },
      });
      if (!categoryExists) {
        throw new AppError('NOT_FOUND', 404, 'Kategori yang dipilih tidak valid.');
      }
    }

    // Validasi relasi resep: tak ada duplikat, semua bahan ada, satu outlet
    // (Ingredient per-outlet, Product global — menu tak boleh campur cabang).
    const recipeInputs = data.recipes ?? [];
    const ingredientIds = recipeInputs.map((r) => r.ingredient_id);
    if (new Set(ingredientIds).size !== ingredientIds.length) {
      throw new AppError('BAD_REQUEST', 400, 'Bahan baku duplikat dalam satu resep.');
    }
    if (ingredientIds.length > 0) {
      const found = await prisma.ingredient.findMany({
        where: { id: { in: ingredientIds } },
        select: { id: true, outlet_id: true },
      });
      if (found.length !== ingredientIds.length) {
        throw new AppError('NOT_FOUND', 404, 'Salah satu bahan baku tidak ditemukan.');
      }
      const outlets = new Set(found.map((f) => f.outlet_id));
      if (outlets.size > 1) {
        throw new AppError('BAD_REQUEST', 400, 'Semua bahan baku harus dari outlet yang sama.');
      }
    }

    try {
      const product = await prisma.product.create({
        data: {
          name: data.name.trim(),
          sku,
          price_idr: data.price_idr,
          category_id: data.category_id,
          image_url: data.image_url || null,
          // Nested create: produk + resep tersimpan dalam 1 transaksi database.
          recipes: recipeInputs.length > 0
            ? {
                create: recipeInputs.map((r) => ({
                  ingredient_id: r.ingredient_id,
                  amount_needed: r.amount_needed,
                })),
              }
            : undefined,
        },
        include: {
          category: true,
          recipes: {
            include: {
              ingredient: true,
            },
          },
        },
      });

      // HPP dihitung ulang dari baris DB fresh (anti-manipulasi nilai dari client).
      const hpp = (product.recipes ?? []).reduce(
        (sum, r) => sum + r.amount_needed * (r.ingredient?.cost_per_unit ?? 0),
        0
      );

      return { ...product, cost_idr: hpp };
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal membuat produk.');
    }
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

    try {
      return await prisma.$transaction(async (tx) => {
        await tx.product.update({
          where: { id },
          data: {
            name: data.name?.trim(),
            sku: data.sku?.trim().toUpperCase(),
            price_idr: data.price_idr,
            category_id: data.category_id,
            image_url: data.image_url,
            is_active: data.is_active,
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
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memperbarui produk.');
    }
  }

  async deleteProduct(id: string) {
    const prod = await prisma.product.findUnique({ where: { id } });
    if (!prod) throw new AppError('NOT_FOUND', 404, 'Produk tidak ditemukan.');

    try {
      await prisma.product.update({
        where: { id },
        data: { is_active: false },
      });

      return { success: true, message: `Produk “${prod.name}” dinonaktifkan.` };
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal menonaktifkan produk.');
    }
  }
}

export const catalogService = new CatalogService();
