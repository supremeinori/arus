import { PrismaClient, Role, MovementType } from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 19456, // 19 MiB
    timeCost: 2,
    parallelism: 1,
  });
}

export async function main() {
  console.log('🚀 Memulai Database Seeder ARUS...');

  // 0. VERIFIKASI ENVIRONMENT & KEAMANAN TARGET DATABASE
  const nodeEnv = process.env.NODE_ENV || 'development';
  console.log(`🔍 Memeriksa environment target database: ${nodeEnv}`);
  if (nodeEnv === 'production' && !process.env.FORCE_RESET_CONFIRMATION) {
    throw new Error(
      '❌ OPERASI DIBATALKAN: Target database terdeteksi sebagai PRODUCTION tanpa konfirmasi eksplisit! Harap set FORCE_RESET_CONFIRMATION=true jika benar-benar dikehendaki.'
    );
  }

  // 1. BERSIHKAN DATA SEBELUM SEEDING
  console.log('🧹 Membersihkan database lama...');
  await prisma.gameSession.deleteMany();
  await prisma.aiChatLog.deleteMany();
  await prisma.feedback.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.deviceToken.deleteMany();
  await prisma.refreshToken.deleteMany();
  // 🛡️ PROTEKSI KEAMANAN DATA SUPABASE:
  // Jangan pernah menghapus data transaksi riil secara otomatis kecuali diizinkan secara eksplisit
  const existingTxCount = await prisma.transaction.count();
  if (existingTxCount > 0 && process.env.CONFIRM_WIPE_TRANSACTIONS !== 'true') {
    console.log(`🛡️ KEAMANAN AKTIF: Ditemukan ${existingTxCount} data transaksi riil di database.`);
    console.log('🛡️ Penghapusan data transaksi, blockchain, dan kartu stok DILEWATI agar data tidak hilang.');
  } else {
    await prisma.blockchainRecord.deleteMany();
    await prisma.transactionItem.deleteMany();
    await prisma.transaction.deleteMany();
    await prisma.inventoryMovement.deleteMany();
  }
  await prisma.productRecipe.deleteMany();
  await prisma.ingredient.deleteMany();
  await prisma.product.deleteMany();
  await prisma.productCategory.deleteMany();
  await prisma.userOutlet.deleteMany();
  await prisma.user.deleteMany();
  await prisma.outlet.deleteMany();

  // 2. BUAT EMPAT CABANG (OUTLETS)
  console.log('🏢 Membuat 4 cabang resmi dengan IANA Timezone...');
  const outletYogyakarta = await prisma.outlet.create({
    data: {
      name: 'Yogyakarta',
      address: 'Jl. Malioboro No. 12, Sosromenduran, Gedong Tengen, Kota Yogyakarta, D.I. Yogyakarta 55271',
      latitude: -7.7956,
      longitude: 110.3695,
      timezone: 'Asia/Jakarta',
      is_active: true,
    },
  });

  const outletDenpasar = await prisma.outlet.create({
    data: {
      name: 'Denpasar',
      address: 'Jl. Raya Puputan No. 88, Renon, Denpasar Selatan, Kota Denpasar, Bali 80239',
      latitude: -8.6705,
      longitude: 115.2126,
      timezone: 'Asia/Makassar',
      is_active: true,
    },
  });

  const outletJayapura = await prisma.outlet.create({
    data: {
      name: 'Jayapura',
      address: 'Jl. Sam Ratulangi No. 45, Gurabesi, Jayapura Utara, Kota Jayapura, Papua 99111',
      latitude: -2.5337,
      longitude: 140.7181,
      timezone: 'Asia/Jayapura',
      is_active: true,
    },
  });

  const outletLondon = await prisma.outlet.create({
    data: {
      name: 'London',
      address: '107 Fleet Street, City of London, London EC4A 2AB, United Kingdom',
      latitude: 51.5074,
      longitude: -0.1278,
      timezone: 'Europe/London',
      is_active: true,
    },
  });

  const outlets = [outletYogyakarta, outletDenpasar, outletJayapura, outletLondon];
  console.log('✅ 4 Cabang berhasil dibuat.');

  // 3. BUAT ENAM AKUN PENGGUNA (Argon2id, Password: 12345678)
  console.log('👥 Membuat 6 akun autentikasi dengan format email @arus.com...');
  const passwordHash = await hashPassword('12345678');

  const owner = await prisma.user.create({
    data: {
      name: 'Owner ARUS',
      email: 'owner@arus.com',
      password_hash: passwordHash,
      role: Role.owner,
      display_currency: 'IDR',
      is_active: true,
    },
  });

  const manager1 = await prisma.user.create({
    data: {
      name: 'Manager 1',
      email: 'manager1@arus.com',
      password_hash: passwordHash,
      role: Role.manager,
      display_currency: 'IDR',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: manager1.id, outlet_id: outletYogyakarta.id },
  });

  const kasir1 = await prisma.user.create({
    data: {
      name: 'Kasir 1 (Yogyakarta)',
      email: 'kasir1@arus.com',
      password_hash: passwordHash,
      role: Role.staff,
      display_currency: 'IDR',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: kasir1.id, outlet_id: outletYogyakarta.id },
  });

  const kasir2 = await prisma.user.create({
    data: {
      name: 'Kasir 2 (Denpasar)',
      email: 'kasir2@arus.com',
      password_hash: passwordHash,
      role: Role.staff,
      display_currency: 'IDR',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: kasir2.id, outlet_id: outletDenpasar.id },
  });

  const kasir3 = await prisma.user.create({
    data: {
      name: 'Kasir 3 (Jayapura)',
      email: 'kasir3@arus.com',
      password_hash: passwordHash,
      role: Role.staff,
      display_currency: 'IDR',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: kasir3.id, outlet_id: outletJayapura.id },
  });

  const kasir4 = await prisma.user.create({
    data: {
      name: 'Kasir 4 (London)',
      email: 'kasir4@arus.com',
      password_hash: passwordHash,
      role: Role.staff,
      display_currency: 'GBP',
      is_active: true,
    },
  });
  await prisma.userOutlet.create({
    data: { user_id: kasir4.id, outlet_id: outletLondon.id },
  });
  console.log('✅ 6 Akun berhasil dibuat.');

  // 4. BUAT KATEGORI PRODUK
  console.log('📂 Membuat kategori produk...');
  const catCoffee = await prisma.productCategory.create({
    data: { name: 'Coffee' },
  });
  const catNonCoffee = await prisma.productCategory.create({
    data: { name: 'Non-Coffee' },
  });
  const catPastry = await prisma.productCategory.create({
    data: { name: 'Pastry & Food' },
  });

  // 5. BUAT BAHAN BAKU (INGREDIENTS) UNTUK SETIAP CABANG
  console.log('📦 Membuat bahan baku logis per cabang & inisialisasi mutasi stok...');
  const ingredientTemplates = [
    { name: 'Biji Kopi Arabika', unit: 'gram', stock_qty: 10000, cost_per_unit: 120, reorder_level: 1000 },
    { name: 'Susu Fresh Milk', unit: 'ml', stock_qty: 20000, cost_per_unit: 20, reorder_level: 2000 },
    { name: 'Sirup Karamel', unit: 'ml', stock_qty: 3000, cost_per_unit: 70, reorder_level: 500 },
    { name: 'Gula Aren Cair', unit: 'ml', stock_qty: 5000, cost_per_unit: 40, reorder_level: 500 },
    { name: 'Bubuk Matcha Premium', unit: 'gram', stock_qty: 2000, cost_per_unit: 250, reorder_level: 300 },
    { name: 'Bubuk Cokelat Murni', unit: 'gram', stock_qty: 3000, cost_per_unit: 100, reorder_level: 500 },
    { name: 'Air Mineral', unit: 'ml', stock_qty: 50000, cost_per_unit: 5, reorder_level: 5000 },
    { name: 'Cup Dingin / Panas', unit: 'pcs', stock_qty: 500, cost_per_unit: 600, reorder_level: 50 },
    { name: 'Paper Cup Espresso', unit: 'pcs', stock_qty: 300, cost_per_unit: 400, reorder_level: 30 },
    { name: 'Adonan Croissant Mentah', unit: 'pcs', stock_qty: 80, cost_per_unit: 7000, reorder_level: 15 },
    { name: 'Mentega Unsalted', unit: 'gram', stock_qty: 2500, cost_per_unit: 150, reorder_level: 300 },
    { name: 'Adonan Muffin Cokelat', unit: 'pcs', stock_qty: 60, cost_per_unit: 6000, reorder_level: 10 },
    { name: 'Choco Chips', unit: 'gram', stock_qty: 2000, cost_per_unit: 100, reorder_level: 200 },
  ];

  // Map: outletId -> { [ingredientName]: Ingredient }
  const outletIngredientsMap = new Map<string, Map<string, any>>();

  for (const outlet of outlets) {
    const ingMap = new Map<string, any>();
    for (const t of ingredientTemplates) {
      const ing = await prisma.ingredient.create({
        data: {
          outlet_id: outlet.id,
          name: t.name,
          unit: t.unit,
          stock_qty: t.stock_qty,
          cost_per_unit: t.cost_per_unit,
          reorder_level: t.reorder_level,
        },
      });

      // Audit trail: Catat mutasi awal restock
      await prisma.inventoryMovement.create({
        data: {
          outlet_id: outlet.id,
          ingredient_id: ing.id,
          movement_type: MovementType.restock,
          quantity_delta: t.stock_qty,
          quantity_after: t.stock_qty,
          note: 'Saldo awal bahan baku dari seeder sistem',
          created_by: owner.id,
        },
      });

      ingMap.set(t.name, ing);
    }
    outletIngredientsMap.set(outlet.id, ingMap);
  }
  console.log(`✅ ${ingredientTemplates.length * outlets.length} Bahan baku berhasil dibuat di 4 cabang.`);

  // 6. BUAT 10 MENU PRODUK & RELASI RESEP (PRODUCT RECIPES)
  console.log('☕ Membuat 10 menu produk dengan resep logis...');
  const menuDefinitions = [
    {
      sku: 'COF-ESP-01',
      name: 'Espresso Single Origin',
      category_id: catCoffee.id,
      price_idr: 18000,
      image_url: 'https://images.unsplash.com/photo-1510591509098-f4fdc6d0ff04?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Biji Kopi Arabika', amount: 18 },
        { name: 'Paper Cup Espresso', amount: 1 },
      ],
    },
    {
      sku: 'COF-AME-02',
      name: 'Americano Ice/Hot',
      category_id: catCoffee.id,
      price_idr: 22000,
      image_url: 'https://images.unsplash.com/photo-1551030173-122aabc4489c?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Biji Kopi Arabika', amount: 18 },
        { name: 'Air Mineral', amount: 150 },
        { name: 'Cup Dingin / Panas', amount: 1 },
      ],
    },
    {
      sku: 'COF-LAT-03',
      name: 'Caffe Latte',
      category_id: catCoffee.id,
      price_idr: 28000,
      image_url: 'https://images.unsplash.com/photo-1570968915860-54d5c301fa9f?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Biji Kopi Arabika', amount: 18 },
        { name: 'Susu Fresh Milk', amount: 200 },
        { name: 'Cup Dingin / Panas', amount: 1 },
      ],
    },
    {
      sku: 'COF-CAP-04',
      name: 'Cappuccino Foam',
      category_id: catCoffee.id,
      price_idr: 28000,
      image_url: 'https://images.unsplash.com/photo-1534778101976-62847782c213?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Biji Kopi Arabika', amount: 18 },
        { name: 'Susu Fresh Milk', amount: 150 },
        { name: 'Cup Dingin / Panas', amount: 1 },
      ],
    },
    {
      sku: 'COF-CRM-05',
      name: 'Caramel Macchiato',
      category_id: catCoffee.id,
      price_idr: 32000,
      image_url: 'https://images.unsplash.com/photo-1485808191679-5f86510681a2?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Biji Kopi Arabika', amount: 18 },
        { name: 'Susu Fresh Milk', amount: 180 },
        { name: 'Sirup Karamel', amount: 20 },
        { name: 'Cup Dingin / Panas', amount: 1 },
      ],
    },
    {
      sku: 'COF-KSG-06',
      name: 'Kopi Susu Gula Aren',
      category_id: catCoffee.id,
      price_idr: 25000,
      image_url: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Biji Kopi Arabika', amount: 18 },
        { name: 'Susu Fresh Milk', amount: 150 },
        { name: 'Gula Aren Cair', amount: 25 },
        { name: 'Cup Dingin / Panas', amount: 1 },
      ],
    },
    {
      sku: 'NCH-MAT-07',
      name: 'Matcha Latte Uji',
      category_id: catNonCoffee.id,
      price_idr: 30000,
      image_url: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Bubuk Matcha Premium', amount: 15 },
        { name: 'Susu Fresh Milk', amount: 200 },
        { name: 'Cup Dingin / Panas', amount: 1 },
      ],
    },
    {
      sku: 'NCH-CHO-08',
      name: 'Signature Chocolate',
      category_id: catNonCoffee.id,
      price_idr: 26000,
      image_url: 'https://images.unsplash.com/photo-1542990253-0d0f5be5f0ed?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Bubuk Cokelat Murni', amount: 25 },
        { name: 'Susu Fresh Milk', amount: 180 },
        { name: 'Cup Dingin / Panas', amount: 1 },
      ],
    },
    {
      sku: 'BAK-CRO-09',
      name: 'Golden Butter Croissant',
      category_id: catPastry.id,
      price_idr: 24000,
      image_url: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Adonan Croissant Mentah', amount: 1 },
        { name: 'Mentega Unsalted', amount: 15 },
      ],
    },
    {
      sku: 'BAK-MUF-10',
      name: 'Double Chocolate Muffin',
      category_id: catPastry.id,
      price_idr: 22000,
      image_url: 'https://images.unsplash.com/photo-1607958996333-41aef7caefaa?w=500&auto=format&fit=crop&q=80',
      recipes: [
        { name: 'Adonan Muffin Cokelat', amount: 1 },
        { name: 'Choco Chips', amount: 10 },
      ],
    },
  ];

  for (const item of menuDefinitions) {
    const product = await prisma.product.create({
      data: {
        sku: item.sku,
        name: item.name,
        category_id: item.category_id,
        price_idr: item.price_idr,
        image_url: item.image_url,
        is_active: true,
      },
    });

    // Hubungkan resep ke seluruh cabang
    for (const outlet of outlets) {
      const ingMap = outletIngredientsMap.get(outlet.id)!;
      for (const r of item.recipes) {
        const ingredient = ingMap.get(r.name);
        if (ingredient) {
          await prisma.productRecipe.create({
            data: {
              product_id: product.id,
              ingredient_id: ingredient.id,
              amount_needed: r.amount,
            },
          });
        }
      }
    }
  }

  console.log(`✅ ${menuDefinitions.length} Menu produk & seluruh resep cabang berhasil dikonfigurasi.`);

  // 7. VERIFIKASI KEBERSIHAN & KESIAPAN DATA
  console.log('\n📊 Ringkasan Jumlah Data Database Setelah Seeding:');
  const counts = {
    outlets: await prisma.outlet.count(),
    users: await prisma.user.count(),
    userOutlets: await prisma.userOutlet.count(),
    categories: await prisma.productCategory.count(),
    products: await prisma.product.count(),
    ingredients: await prisma.ingredient.count(),
    recipes: await prisma.productRecipe.count(),
    movements: await prisma.inventoryMovement.count(),
    transactions: await prisma.transaction.count(),
    transactionItems: await prisma.transactionItem.count(),
    blockchainRecords: await prisma.blockchainRecord.count(),
  };

  console.table(counts);

  if (
    counts.outlets === 4 &&
    counts.users === 6 &&
    counts.products === 10 &&
    counts.categories === 3 &&
    counts.transactions >= 0
  ) {
    console.log('🎉 SEEDER BERHASIL: 4 cabang, 6 akun, 10 menu produk & bahan baku lengkap siap digunakan!');
  } else {
    throw new Error('❌ Verifikasi seeder gagal: Jumlah record tidak sesuai target!');
  }
}

main()
  .catch((e) => {
    console.error('❌ Gagal menjalankan database seeder:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
