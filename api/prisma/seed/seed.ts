import { PrismaClient, Role, PaymentMethod, TxnStatus, MovementType, GameMode } from '@prisma/client';
import * as argon2 from 'argon2';
import * as crypto from 'crypto';

const prisma = new PrismaClient();

async function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, {
    type: argon2.argon2id,
    memoryCost: 19456, // 19 MiB
    timeCost: 2,
    parallelism: 1,
  });
}

function sha256(data: string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

export async function main() {
  console.log('🌱 Memulai proses seeding database ARUS (Recipe-Driven Architecture)...');

  // 1. CLEANUP (Idempotency)
  console.log('🧹 Membersihkan database Supabase...');
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

  // 2. USERS
  console.log('👥 Mengisi data pengguna (Owner, Manager, Staff)...');
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

  // 3. OUTLETS (3 Domestik + 1 London)
  console.log('🏢 Mengisi data Outlet (3 Domestik + 1 London)...');
  const outletJogja = await prisma.outlet.create({
    data: {
      name: 'ARUS Jogja Malioboro',
      address: 'Jl. Malioboro No. 45, Danurejan, Yogyakarta',
      latitude: -7.7828,
      longitude: 110.3670,
      timezone: 'Asia/Jakarta',
    },
  });

  const outletSolo = await prisma.outlet.create({
    data: {
      name: 'ARUS Solo Slamet Riyadi',
      address: 'Jl. Slamet Riyadi No. 120, Banjarsari, Surakarta',
      latitude: -7.5561,
      longitude: 110.8316,
      timezone: 'Asia/Jakarta',
    },
  });

  const outletBali = await prisma.outlet.create({
    data: {
      name: 'ARUS Bali Kuta Sunset',
      address: 'Jl. Sunset Road No. 88, Kuta, Badung, Bali',
      latitude: -8.6705,
      longitude: 115.2126,
      timezone: 'Asia/Makassar',
    },
  });

  const outletLondon = await prisma.outlet.create({
    data: {
      name: 'ARUS London Oxford',
      address: '14 Oxford Street, London W1D 1BS, United Kingdom',
      latitude: 51.5074,
      longitude: -0.1278,
      timezone: 'Europe/London',
    },
  });

  const outlets = [outletJogja, outletSolo, outletBali, outletLondon];

  await prisma.userOutlet.createMany({
    data: [
      { user_id: manager.id, outlet_id: outletJogja.id },
      { user_id: manager.id, outlet_id: outletSolo.id },
      { user_id: staff.id, outlet_id: outletJogja.id },
    ],
  });

  // 4. KATEGORI & 10 PRODUK UTAMA LENGKAP DENGAN IMAGE_URL
  console.log('☕ Mengisi 10 Produk Pilihan (lengkap foto menu)...');
  const catCoffee = await prisma.productCategory.create({ data: { name: 'Kopi & Minuman Espresso' } });
  const catTea = await prisma.productCategory.create({ data: { name: 'Teh & Segaran' } });
  const catBakery = await prisma.productCategory.create({ data: { name: 'Pastry & Roti' } });
  const catMeals = await prisma.productCategory.create({ data: { name: 'Makanan Utama' } });
  const catSnacks = await prisma.productCategory.create({ data: { name: 'Camilan & Kudapan' } });

  const rawProducts = [
    // Kopi (2 produk)
    { sku: 'KOP-01', name: 'Es Kopi Susu Gula Aren', price: 22000, catId: catCoffee.id, img: 'https://images.unsplash.com/photo-1517701550927-30cf4ba1dba5?auto=format&fit=crop&w=500&q=80' },
    { sku: 'KOP-02', name: 'Americano Dingin', price: 18000, catId: catCoffee.id, img: 'https://images.unsplash.com/photo-1551030173-122aabc4489c?auto=format&fit=crop&w=500&q=80' },

    // Teh (2 produk)
    { sku: 'TEH-01', name: 'Matcha Green Tea Latte', price: 26000, catId: catTea.id, img: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?auto=format&fit=crop&w=500&q=80' },
    { sku: 'TEH-02', name: 'Lemon Jasmine Tea Segar', price: 18000, catId: catTea.id, img: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?auto=format&fit=crop&w=500&q=80' },

    // Pastry (2 produk)
    { sku: 'PAS-01', name: 'Butter Croissant Premium', price: 24000, catId: catBakery.id, img: 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?auto=format&fit=crop&w=500&q=80' },
    { sku: 'PAS-02', name: 'Pain Au Chocolat', price: 27000, catId: catBakery.id, img: 'https://images.unsplash.com/photo-1530610476181-d83430b64dcd?auto=format&fit=crop&w=500&q=80' },

    // Makanan (2 produk)
    { sku: 'MAK-01', name: 'Nasi Ayam Geprek Sambal Bawang', price: 28000, catId: catMeals.id, img: 'https://images.unsplash.com/photo-1562967914-608f82629710?auto=format&fit=crop&w=500&q=80' },
    { sku: 'MAK-02', name: 'Spaghetti Carbonara Creamy', price: 38000, catId: catMeals.id, img: 'https://images.unsplash.com/photo-1612874742237-6526221588e3?auto=format&fit=crop&w=500&q=80' },

    // Camilan (2 produk)
    { sku: 'CAM-01', name: 'Kentang Goreng Truffle', price: 24000, catId: catSnacks.id, img: 'https://images.unsplash.com/photo-1576107232684-1279f3908594?auto=format&fit=crop&w=500&q=80' },
    { sku: 'CAM-02', name: 'Pisang Goreng Keju Aren', price: 20000, catId: catSnacks.id, img: 'https://images.unsplash.com/photo-1528751014936-863e6e7a319c?auto=format&fit=crop&w=500&q=80' },
  ];

  const createdProducts: any[] = [];
  for (const p of rawProducts) {
    const prod = await prisma.product.create({
      data: {
        sku: p.sku,
        name: p.name,
        price_idr: p.price,
        image_url: p.img,
        category_id: p.catId,
      },
    });
    createdProducts.push(prod);
  }

  // 5. BAHAN BAKU & STOK REALISTIS PER CABANG
  console.log('📦 Mengisi bahan baku realistis di setiap cabang...');
  const ingredientTemplates = [
    { key: 'kopi', name: 'Biji Kopi Arabika House Blend', unit: 'gram', baseStock: 3000, reorder: 500, cost: 150 },
    { key: 'air', name: 'Air Mineral Purified', unit: 'ml', baseStock: 25000, reorder: 3000, cost: 2 },
    { key: 'susu', name: 'Susu UHT Fresh Milk', unit: 'ml', baseStock: 6000, reorder: 1200, cost: 25 },
    { key: 'aren', name: 'Gula Aren Cair Asli', unit: 'ml', baseStock: 4000, reorder: 500, cost: 35 },
    { key: 'matcha', name: 'Bubuk Matcha Premium', unit: 'gram', baseStock: 1200, reorder: 250, cost: 300 },
    { key: 'teh', name: 'Daun Teh Melati Kering', unit: 'gram', baseStock: 1500, reorder: 300, cost: 100 },
    { key: 'lemon', name: 'Lemon Fresh Segar', unit: 'pcs', baseStock: 60, reorder: 15, cost: 2000 },
    { key: 'croissant', name: 'Adonan Croissant Butter', unit: 'pcs', baseStock: 50, reorder: 10, cost: 8000 },
    { key: 'cokelat', name: 'Cokelat Isian Pastry', unit: 'gram', baseStock: 2000, reorder: 400, cost: 60 },
    { key: 'ayam', name: 'Daging Ayam Fillet Segar', unit: 'gram', baseStock: 6000, reorder: 1200, cost: 50 },
    { key: 'beras', name: 'Beras Pulen Organik', unit: 'gram', baseStock: 12000, reorder: 2500, cost: 15 },
    { key: 'pasta', name: 'Spaghetti Pasta Kering', unit: 'gram', baseStock: 5000, reorder: 1000, cost: 30 },
    { key: 'kentang', name: 'Kentang Truffle Beku', unit: 'gram', baseStock: 6000, reorder: 1200, cost: 25 },
    { key: 'pisang', name: 'Pisang Kepok Manis', unit: 'pcs', baseStock: 80, reorder: 20, cost: 1500 },
  ];

  // Map outletId -> { key -> Ingredient }
  const outletIngredients: Record<string, Record<string, any>> = {};

  for (const outlet of outlets) {
    outletIngredients[outlet.id] = {};
    for (const t of ingredientTemplates) {
      let initialStock = t.baseStock;

      // Simulasi trigger demo khusus di Jogja:
      // Susu menipis (low stock) dan Adonan Croissant habis (out of stock)
      if (outlet.id === outletJogja.id && t.key === 'susu') initialStock = 800; // <= 1200
      if (outlet.id === outletJogja.id && t.key === 'croissant') initialStock = 0; // 0 (out of stock)

      const ing = await prisma.ingredient.create({
        data: {
          outlet_id: outlet.id,
          name: t.name,
          unit: t.unit,
          stock_qty: initialStock,
          reorder_level: t.reorder,
          cost_per_unit: t.cost,
        },
      });

      outletIngredients[outlet.id][t.key] = ing;

      if (initialStock > 0) {
        await prisma.inventoryMovement.create({
          data: {
            outlet_id: outlet.id,
            ingredient_id: ing.id,
            movement_type: MovementType.restock,
            quantity_delta: initialStock,
            quantity_after: initialStock,
            note: 'Stok awal bahan baku sistem',
            created_by: owner.id,
          },
        });
      }
    }
  }

  // 6. RESEP MENU (PRODUCT RECIPES: Menu <-> Bahan Baku)
  console.log('📖 Menghubungkan Menu dengan Bahan Baku via Resep (Product Recipes)...');
  const recipeDefinitions: Record<string, Array<{ key: string; amount: number }>> = {
    'KOP-01': [{ key: 'kopi', amount: 20 }, { key: 'susu', amount: 120 }, { key: 'aren', amount: 30 }],
    'KOP-02': [{ key: 'kopi', amount: 20 }, { key: 'air', amount: 180 }],
    'TEH-01': [{ key: 'matcha', amount: 15 }, { key: 'susu', amount: 150 }],
    'TEH-02': [{ key: 'teh', amount: 10 }, { key: 'air', amount: 200 }, { key: 'lemon', amount: 1 }],
    'PAS-01': [{ key: 'croissant', amount: 1 }],
    'PAS-02': [{ key: 'croissant', amount: 1 }, { key: 'cokelat', amount: 30 }],
    'MAK-01': [{ key: 'ayam', amount: 150 }, { key: 'beras', amount: 100 }],
    'MAK-02': [{ key: 'pasta', amount: 120 }, { key: 'susu', amount: 100 }],
    'CAM-01': [{ key: 'kentang', amount: 150 }],
    'CAM-02': [{ key: 'pisang', amount: 2 }, { key: 'aren', amount: 20 }],
  };

  for (const prod of createdProducts) {
    const defs = recipeDefinitions[prod.sku] || [];
    for (const outlet of outlets) {
      for (const def of defs) {
        const ing = outletIngredients[outlet.id][def.key];
        if (ing) {
          await prisma.productRecipe.create({
            data: {
              product_id: prod.id,
              ingredient_id: ing.id,
              amount_needed: def.amount,
            },
          });
        }
      }
    }
  }

  // 7. 10 HARI TRANSAKSI HISTORIS (~120 TRANSAKSI DENGAN BLOCKCHAIN)
  console.log('📊 Menghasilkan 10 hari transaksi (~120 transaksi)...');
  const paymentMethods = [PaymentMethod.cash, PaymentMethod.qris_simulated, PaymentMethod.card_simulated];

  const outletChainState: Record<string, { blockIndex: number; prevHash: string }> = {};
  for (const outlet of outlets) {
    outletChainState[outlet.id] = {
      blockIndex: 0,
      prevHash: '0'.repeat(64),
    };
  }

  let txnSeq = 1;
  const now = new Date();

  // 10 hari ke belakang (10 x 4 outlet x 3 transaksi = 120 transaksi)
  for (let dayOffset = 9; dayOffset >= 0; dayOffset--) {
    const txnDate = new Date(now.getTime() - dayOffset * 24 * 60 * 60 * 1000);
    const dateStr = txnDate.toISOString().slice(0, 10).replace(/-/g, '');

    for (const outlet of outlets) {
      for (let t = 0; t < 3; t++) {
        const hour = 10 + t * 4; // 10:00, 14:00, 18:00
        const currentTxnTime = new Date(txnDate);
        currentTxnTime.setHours(hour, 15, 0, 0);

        const outletCode = outlet.name.substring(5, 8).toUpperCase();
        const receiptNo = `TXN-${outletCode}-${dateStr}-${String(txnSeq++).padStart(4, '0')}`;
        const clientReqId = crypto.randomUUID();

        // 1-2 item per transaksi
        const product = createdProducts[(dayOffset * 3 + t) % createdProducts.length];
        const qty = 1 + (t % 2);
        const subtotal = product.price_idr * qty;
        const discount = 0;
        const total = subtotal;
        const method = paymentMethods[t % paymentMethods.length];
        const paid = method === PaymentMethod.cash ? Math.ceil(total / 10000) * 10000 : total;
        const change = paid - total;

        // Hitung estimasi unit_cost_idr dari resep
        const defs = recipeDefinitions[product.sku] || [];
        const unitCost = defs.reduce((sum, d) => {
          const ing = outletIngredients[outlet.id][d.key];
          return sum + (d.amount * (ing?.cost_per_unit || 0));
        }, 0);

        const transaction = await prisma.transaction.create({
          data: {
            receipt_no: receiptNo,
            outlet_id: outlet.id,
            cashier_id: staff.id,
            client_request_id: clientReqId,
            subtotal_idr: subtotal,
            discount_idr: discount,
            total_idr: total,
            payment_method: method,
            paid_idr: paid,
            change_idr: change,
            status: TxnStatus.completed,
            created_at: currentTxnTime,
            items: {
              create: [
                {
                  product_id: product.id,
                  product_name_snapshot: product.name,
                  unit_price_idr: product.price_idr,
                  unit_cost_idr: unitCost,
                  quantity: qty,
                  line_total_idr: subtotal,
                },
              ],
            },
          },
        });

        // Blockchain SHA-256
        const chainState = outletChainState[outlet.id];
        chainState.blockIndex += 1;

        const canonicalData = {
          cashier_id: staff.id,
          created_at: currentTxnTime.toISOString(),
          discount_idr: discount,
          id: transaction.id,
          items: [{
            line_total_idr: subtotal,
            product_id: product.id,
            quantity: qty,
            unit_price_idr: product.price_idr,
          }],
          outlet_id: outlet.id,
          payment_method: method,
          receipt_no: receiptNo,
          subtotal_idr: subtotal,
          total_idr: total,
        };

        const canonicalJsonStr = JSON.stringify(canonicalData);
        const dataHash = sha256(canonicalJsonStr);
        const blockHash = sha256(`${outlet.id}${chainState.blockIndex}${dataHash}${chainState.prevHash}`);

        await prisma.blockchainRecord.create({
          data: {
            outlet_id: outlet.id,
            block_index: chainState.blockIndex,
            transaction_id: transaction.id,
            data_hash: dataHash,
            prev_hash: chainState.prevHash,
            block_hash: blockHash,
            created_at: currentTxnTime,
          },
        });

        chainState.prevHash = blockHash;
      }
    }
  }

  // 8. FEEDBACK PAM & SAMPLE GAME SESSIONS
  console.log('💬 Mengisi feedback PAM & sample game session...');
  await prisma.feedback.create({
    data: {
      user_id: staff.id,
      kesan: 'Mata kuliah PAM sangat bermanfaat, materi Flutter dan arsitektur REST API-nya aplikatif untuk dunia kerja.',
      saran: 'Semoga praktikum ke depannya tetap fokus pada arsitektur bersih dan teknologi modern seperti Riverpod & Prisma.',
    },
  });

  await prisma.gameSession.createMany({
    data: [
      {
        user_id: staff.id,
        mode: GameMode.guess_name,
        score: 850,
        correct_count: 5,
        total_questions: 5,
        duration_sec: 25,
      },
      {
        user_id: manager.id,
        mode: GameMode.guess_price,
        score: 720,
        correct_count: 4,
        total_questions: 5,
        duration_sec: 32,
      },
    ],
  });

  console.log('✨ SEEDING SUPER CEPAT SELESAI!');
  console.log(`- Users: ${await prisma.user.count()}`);
  console.log(`- Outlets: ${await prisma.outlet.count()}`);
  console.log(`- Kategori: ${await prisma.productCategory.count()}`);
  console.log(`- Produk: ${await prisma.product.count()} menu`);
  console.log(`- Bahan Baku: ${await prisma.ingredient.count()} bahan`);
  console.log(`- Resep Menu: ${await prisma.productRecipe.count()} resep`);
  console.log(`- Transaksi: ${await prisma.transaction.count()} transaksi (10 hari)`);
  console.log(`- Blockchain: ${await prisma.blockchainRecord.count()} blocks`);
}

main()
  .catch((e) => {
    console.error('❌ Gagal menjalankan seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
