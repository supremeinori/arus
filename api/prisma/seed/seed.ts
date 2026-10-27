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
  console.log('🌱 Menjalankan Seeder Ringkas ARUS (Minimal & Cepat)...');

  // 1. CLEANUP DATABASE
  console.log('🧹 Membersihkan tabel database...');
  await prisma.gameSession.deleteMany();
  await prisma.aiChatLog.deleteMany();
  await prisma.feedback.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.blockchainRecord.deleteMany();
  await prisma.transactionItem.deleteMany();
  await prisma.transaction.deleteMany();
  await prisma.inventoryMovement.deleteMany();
  await prisma.productRecipe.deleteMany();
  await prisma.ingredient.deleteMany();
  await prisma.product.deleteMany();
  await prisma.productCategory.deleteMany();
  await prisma.userOutlet.deleteMany();
  await prisma.outlet.deleteMany();
  await prisma.user.deleteMany();

  // 2. USERS (1 Owner, 1 Manager, 1 Staff)
  console.log('👥 Membuat pengguna utama...');
  const passwordHash = await hashPassword('Demo1234');

  const owner = await prisma.user.create({
    data: {
      name: 'Rina Kartika (Owner)',
      email: 'owner@arus.demo',
      password_hash: passwordHash,
      role: Role.owner,
      avatar_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=400&q=80',
    },
  });

  const manager = await prisma.user.create({
    data: {
      name: 'Budi Santoso (Manager)',
      email: 'manager@arus.demo',
      password_hash: passwordHash,
      role: Role.manager,
      avatar_url: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=400&q=80',
    },
  });

  const staff = await prisma.user.create({
    data: {
      name: 'Siti Rahma (Kasir)',
      email: 'staff@arus.demo',
      password_hash: passwordHash,
      role: Role.staff,
      avatar_url: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=400&q=80',
    },
  });

  // 3. OUTLET UTAMA
  console.log('🏢 Membuat Cabang Outlet Utama...');
  const outlet = await prisma.outlet.create({
    data: {
      name: 'ARUS Coffee Sudirman',
      address: 'Jl. Jend. Sudirman No. 45, Jakarta Pusat',
      latitude: -6.2088,
      longitude: 106.8456,
      timezone: 'Asia/Jakarta',
    },
  });

  await prisma.userOutlet.createMany({
    data: [
      { user_id: manager.id, outlet_id: outlet.id },
      { user_id: staff.id, outlet_id: outlet.id },
    ],
  });

  // 4. KATEGORI & 3 MENU UTAMA
  console.log('☕ Membuat 3 Menu Jualan...');
  const catCoffee = await prisma.productCategory.create({ data: { name: 'Kopi & Espresso' } });

  const americano = await prisma.product.create({
    data: {
      sku: 'BEV-AME-01',
      name: 'Americano Dingin',
      price_idr: 18000,
      image_url: 'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80',
      category_id: catCoffee.id,
    },
  });

  const cappuccino = await prisma.product.create({
    data: {
      sku: 'BEV-CAP-01',
      name: 'Cappuccino Hangat',
      price_idr: 24000,
      image_url: 'https://images.unsplash.com/photo-1534778101976-62847782c213?auto=format&fit=crop&w=500&q=80',
      category_id: catCoffee.id,
    },
  });

  const kopiSusu = await prisma.product.create({
    data: {
      sku: 'BEV-AREN-01',
      name: 'Es Kopi Susu Gula Aren',
      price_idr: 22000,
      image_url: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=500&q=80',
      category_id: catCoffee.id,
    },
  });

  // 5. BAHAN BAKU (INGREDIENTS) DI CABANG
  console.log('📦 Membuat 4 Bahan Baku Pokok di Cabang...');
  const ingKopi = await prisma.ingredient.create({
    data: {
      outlet_id: outlet.id,
      name: 'Biji Kopi Arabika House Blend',
      unit: 'gram',
      stock_qty: 3000,
      reorder_level: 500,
      cost_per_unit: 150,
    },
  });

  const ingAir = await prisma.ingredient.create({
    data: {
      outlet_id: outlet.id,
      name: 'Air Mineral Purified',
      unit: 'ml',
      stock_qty: 25000,
      reorder_level: 2000,
      cost_per_unit: 2,
    },
  });

  const ingSusu = await prisma.ingredient.create({
    data: {
      outlet_id: outlet.id,
      name: 'Susu Fresh Milk UHT',
      unit: 'ml',
      stock_qty: 5000,
      reorder_level: 1000,
      cost_per_unit: 20,
    },
  });

  const ingAren = await prisma.ingredient.create({
    data: {
      outlet_id: outlet.id,
      name: 'Gula Aren Cair Asli',
      unit: 'ml',
      stock_qty: 2000,
      reorder_level: 300,
      cost_per_unit: 35,
    },
  });

  // Catat stok awal ke mutasi
  const ings = [ingKopi, ingAir, ingSusu, ingAren];
  for (const ing of ings) {
    await prisma.inventoryMovement.create({
      data: {
        outlet_id: outlet.id,
        ingredient_id: ing.id,
        movement_type: MovementType.restock,
        quantity_delta: ing.stock_qty,
        quantity_after: ing.stock_qty,
        note: 'Stok awal bahan baku sistem',
        created_by: owner.id,
      },
    });
  }

  // 6. RESEP MENU (PRODUCT RECIPES)
  console.log('📖 Menghubungkan Resep Menu...');
  // Americano: 20g Kopi + 180ml Air
  await prisma.productRecipe.createMany({
    data: [
      { product_id: americano.id, ingredient_id: ingKopi.id, amount_needed: 20 },
      { product_id: americano.id, ingredient_id: ingAir.id, amount_needed: 180 },
    ],
  });

  // Cappuccino: 20g Kopi + 150ml Susu
  await prisma.productRecipe.createMany({
    data: [
      { product_id: cappuccino.id, ingredient_id: ingKopi.id, amount_needed: 20 },
      { product_id: cappuccino.id, ingredient_id: ingSusu.id, amount_needed: 150 },
    ],
  });

  // Es Kopi Susu Gula Aren: 20g Kopi + 120ml Susu + 30ml Gula Aren
  await prisma.productRecipe.createMany({
    data: [
      { product_id: kopiSusu.id, ingredient_id: ingKopi.id, amount_needed: 20 },
      { product_id: kopiSusu.id, ingredient_id: ingSusu.id, amount_needed: 120 },
      { product_id: kopiSusu.id, ingredient_id: ingAren.id, amount_needed: 30 },
    ],
  });

  console.log('✅ Seeding ringkas selesai dengan sukses!');
}

main()
  .catch((e) => {
    console.error('❌ Gagal menjalankan seeder:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
