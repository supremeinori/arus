import { PrismaClient, Role, PaymentMethod, TransactionStatus, MovementType, RecordType } from '@prisma/client';
import * as argon2 from 'argon2';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';

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
  console.log('🌱 Memulai proses seeding database ARUS...');

  // 1. CLEANUP (Idempotency)
  console.log('🧹 Membersihkan data lama untuk memastikan idempotency...');
  await prisma.gameSession.deleteMany();
  await prisma.gameScenario.deleteMany();
  await prisma.feedback.deleteMany();
  await prisma.aiMessage.deleteMany();
  await prisma.aiConversation.deleteMany();
  await prisma.blockchainRecord.deleteMany();
  await prisma.report.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.businessInsight.deleteMany();
  await prisma.transactionItem.deleteMany();
  await prisma.transaction.deleteMany();
  await prisma.inventoryMovement.deleteMany();
  await prisma.inventory.deleteMany();
  await prisma.product.deleteMany();
  await prisma.productCategory.deleteMany();
  await prisma.userSettings.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.userOutlet.deleteMany();
  await prisma.outlet.deleteMany();
  await prisma.user.deleteMany();
  await prisma.exchangeRate.deleteMany();

  // 2. EXCHANGE RATES
  console.log('💱 Mengisi data kurs (Exchange Rates)...');
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  await prisma.exchangeRate.createMany({
    data: [
      { base: 'IDR', quote: 'USD', rate: 0.000062, as_of: today, source: 'seed' },
      { base: 'IDR', quote: 'EUR', rate: 0.000058, as_of: today, source: 'seed' },
    ],
  });

  // 3. USERS & SETTINGS
  console.log('👥 Mengisi data pengguna (Owner, Manager, Staff)...');
  const passwordHash = await hashPassword('Demo1234');

  const owner = await prisma.user.create({
    data: {
      name: 'Rina Kartika (Owner)',
      email: 'owner@arus.demo',
      password_hash: passwordHash,
      role: Role.owner,
      settings: {
        create: {
          display_currency: 'IDR',
          display_timezone: 'Asia/Jakarta',
          daily_revenue_target_idr: 5000000,
        },
      },
    },
  });

  const manager = await prisma.user.create({
    data: {
      name: 'Budi Santoso (Manager)',
      email: 'manager@arus.demo',
      password_hash: passwordHash,
      role: Role.manager,
      settings: {
        create: {
          display_currency: 'IDR',
          display_timezone: 'Asia/Jakarta',
          daily_revenue_target_idr: 2500000,
        },
      },
    },
  });

  const staff = await prisma.user.create({
    data: {
      name: 'Siti Rahma (Kasir)',
      email: 'staff@arus.demo',
      password_hash: passwordHash,
      role: Role.staff,
      settings: {
        create: {
          display_currency: 'IDR',
          display_timezone: 'Asia/Jakarta',
        },
      },
    },
  });

  // 4. OUTLETS
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

  // User Outlet Assignments
  await prisma.userOutlet.createMany({
    data: [
      // Manager assigned to Jogja and Solo
      { user_id: manager.id, outlet_id: outletJogja.id },
      { user_id: manager.id, outlet_id: outletSolo.id },
      // Staff assigned to Jogja
      { user_id: staff.id, outlet_id: outletJogja.id },
    ],
  });

  // 5. PRODUCT CATEGORIES & PRODUCTS (>= 40 Produk)
  console.log('☕ Mengisi data Kategori & 40 Produk...');
  const catCoffee = await prisma.productCategory.create({ data: { name: 'Kopi & Minuman Espresso' } });
  const catTea = await prisma.productCategory.create({ data: { name: 'Teh & Segaran' } });
  const catBakery = await prisma.productCategory.create({ data: { name: 'Pastry & Roti' } });
  const catMeals = await prisma.productCategory.create({ data: { name: 'Makanan Utama' } });
  const catSnacks = await prisma.productCategory.create({ data: { name: 'Camilan & Kudapan' } });

  const rawProducts = [
    // Kopi (10 produk)
    { sku: 'KOP-01', name: 'Es Kopi Susu Gula Aren', unit: 'cup', price: 22000, cost: 9000, catId: catCoffee.id },
    { sku: 'KOP-02', name: 'Americano Dingin', unit: 'cup', price: 18000, cost: 6000, catId: catCoffee.id },
    { sku: 'KOP-03', name: 'Caramel Macchiato', unit: 'cup', price: 28000, cost: 12000, catId: catCoffee.id },
    { sku: 'KOP-04', name: 'Vanilla Latte', unit: 'cup', price: 26000, cost: 11000, catId: catCoffee.id },
    { sku: 'KOP-05', name: 'Cafe Mocha Panas', unit: 'cup', price: 27000, cost: 12000, catId: catCoffee.id },
    { sku: 'KOP-06', name: 'Cappuccino Hangat', unit: 'cup', price: 24000, cost: 10000, catId: catCoffee.id },
    { sku: 'KOP-07', name: 'Kopi Tubruk Nusantara', unit: 'cup', price: 14000, cost: 5000, catId: catCoffee.id },
    { sku: 'KOP-08', name: 'Espresso Double Shot', unit: 'shot', price: 16000, cost: 5500, catId: catCoffee.id },
    { sku: 'KOP-09', name: 'Cold Brew Signature', unit: 'botol', price: 30000, cost: 13000, catId: catCoffee.id },
    { sku: 'KOP-10', name: 'Affogato Es Krim Vanilla', unit: 'cup', price: 25000, cost: 10000, catId: catCoffee.id },

    // Teh & Non Kopi (8 produk)
    { sku: 'TEH-01', name: 'Matcha Green Tea Latte', unit: 'cup', price: 26000, cost: 11000, catId: catTea.id },
    { sku: 'TEH-02', name: 'Earl Grey Milk Tea', unit: 'cup', price: 23000, cost: 9500, catId: catTea.id },
    { sku: 'TEH-03', name: 'Lemon Jasmine Tea Segar', unit: 'cup', price: 18000, cost: 6000, catId: catTea.id },
    { sku: 'TEH-04', name: 'Lychee Iced Tea', unit: 'cup', price: 22000, cost: 8000, catId: catTea.id },
    { sku: 'TEH-05', name: 'Teh Tarik Klasik', unit: 'cup', price: 19000, cost: 7000, catId: catTea.id },
    { sku: 'TEH-06', name: 'Cokelat Panas Belgia', unit: 'cup', price: 25000, cost: 11500, catId: catTea.id },
    { sku: 'TEH-07', name: 'Teh Chamomile Madu', unit: 'cup', price: 21000, cost: 7500, catId: catTea.id },
    { sku: 'TEH-08', name: 'Es Teh Manis Jumbo', unit: 'cup', price: 10000, cost: 3000, catId: catTea.id },

    // Pastry (8 produk)
    { sku: 'PAS-01', name: 'Butter Croissant Premium', unit: 'pcs', price: 24000, cost: 11000, catId: catBakery.id },
    { sku: 'PAS-02', name: 'Pain Au Chocolat', unit: 'pcs', price: 27000, cost: 12500, catId: catBakery.id },
    { sku: 'PAS-03', name: 'Almond Croissant', unit: 'pcs', price: 29000, cost: 13500, catId: catBakery.id },
    { sku: 'PAS-04', name: 'Cinnamon Roll Glaze', unit: 'pcs', price: 22000, cost: 9500, catId: catBakery.id },
    { sku: 'PAS-05', name: 'Donat Gula Klasik', unit: 'pcs', price: 12000, cost: 5000, catId: catBakery.id },
    { sku: 'PAS-06', name: 'Fudgy Brownies Cokelat', unit: 'slice', price: 20000, cost: 8500, catId: catBakery.id },
    { sku: 'PAS-07', name: 'Banana Bread Panggang', unit: 'slice', price: 18000, cost: 7500, catId: catBakery.id },
    { sku: 'PAS-08', name: 'Cheese Danish Gurih', unit: 'pcs', price: 25000, cost: 11000, catId: catBakery.id },

    // Makanan Utama (8 produk)
    { sku: 'MAK-01', name: 'Nasi Ayam Geprek Sambal Bawang', unit: 'porsi', price: 28000, cost: 14000, catId: catMeals.id },
    { sku: 'MAK-02', name: 'Nasi Goreng Spesial ARUS', unit: 'porsi', price: 32000, cost: 15000, catId: catMeals.id },
    { sku: 'MAK-03', name: 'Spaghetti Aglio Olio Tuna', unit: 'porsi', price: 35000, cost: 16500, catId: catMeals.id },
    { sku: 'MAK-04', name: 'Spaghetti Carbonara Creamy', unit: 'porsi', price: 38000, cost: 18000, catId: catMeals.id },
    { sku: 'MAK-05', name: 'Rice Bowl Beef Teriyaki', unit: 'porsi', price: 42000, cost: 21000, catId: catMeals.id },
    { sku: 'MAK-06', name: 'Mie Goreng Dok-dok Jawa', unit: 'porsi', price: 26000, cost: 12000, catId: catMeals.id },
    { sku: 'MAK-07', name: 'Chicken Katsu Curry Bowl', unit: 'porsi', price: 36000, cost: 17500, catId: catMeals.id },
    { sku: 'MAK-08', name: 'Sandwich Smoked Beef & Cheese', unit: 'porsi', price: 30000, cost: 14500, catId: catMeals.id },

    // Camilan (8 produk)
    { sku: 'CAM-01', name: 'Kentang Goreng Truffle', unit: 'porsi', price: 24000, cost: 10000, catId: catSnacks.id },
    { sku: 'CAM-02', name: 'Pisang Goreng Keju Aren', unit: 'porsi', price: 20000, cost: 8000, catId: catSnacks.id },
    { sku: 'CAM-03', name: 'Tahu Cabe Garam Renyah', unit: 'porsi', price: 18000, cost: 7000, catId: catSnacks.id },
    { sku: 'CAM-04', name: 'Cireng Krispi Bumbu Rujak', unit: 'porsi', price: 16000, cost: 6000, catId: catSnacks.id },
    { sku: 'CAM-05', name: 'Platter Sosis & Nugget', unit: 'porsi', price: 28000, cost: 12500, catId: catSnacks.id },
    { sku: 'CAM-06', name: 'Singkong Keju Merekah', unit: 'porsi', price: 17000, cost: 6500, catId: catSnacks.id },
    { sku: 'CAM-07', name: 'Nachos Saus Keju Daging', unit: 'porsi', price: 32000, cost: 14000, catId: catSnacks.id },
    { sku: 'CAM-08', name: 'Churros Gula Kayu Manis', unit: 'porsi', price: 22000, cost: 9000, catId: catSnacks.id },
  ];

  const createdProducts = [];
  for (const p of rawProducts) {
    const prod = await prisma.product.create({
      data: {
        sku: p.sku,
        name: p.name,
        unit: p.unit,
        price_idr: p.price,
        cost_idr: p.cost,
        category_id: p.catId,
        created_by: owner.id,
      },
    });
    createdProducts.push(prod);
  }

  // 6. INVENTORY PER OUTLET
  console.log('📦 Mengisi data inventaris per outlet...');
  for (const outlet of outlets) {
    for (let i = 0; i < createdProducts.length; i++) {
      const prod = createdProducts[i];
      // Tentukan stok variatif (beberapa low stock di outlet Jogja untuk trigger demo low-stock alert)
      let initialQty = 45;
      if (outlet.id === outletJogja.id && i === 0) initialQty = 12; // Es Kopi Susu (Low stock trigger!)
      if (outlet.id === outletJogja.id && i === 3) initialQty = 3;  // Vanilla Latte (Critical!)
      if (outlet.id === outletJogja.id && i === 6) initialQty = 0;  // Out of stock
      if (outlet.id === outletSolo.id && i === 15) initialQty = 50; // Cokelat Panas slow-moving

      await prisma.inventory.create({
        data: {
          outlet_id: outlet.id,
          product_id: prod.id,
          quantity: initialQty,
          reorder_level: 5,
          avg_lead_time_days: 3,
        },
      });

      await prisma.inventoryMovement.create({
        data: {
          outlet_id: outlet.id,
          product_id: prod.id,
          movement_type: MovementType.restock,
          quantity_delta: initialQty,
          quantity_after: initialQty,
          note: 'Stok awal seeding sistem',
          created_by: owner.id,
        },
      });
    }
  }

  // 7. GAME SCENARIOS
  console.log('🎮 Mengisi 12 Skenario Mini Game...');
  const scenariosPath = path.join(__dirname, 'game_scenarios.json');
  if (fs.existsSync(scenariosPath)) {
    const scenariosData = JSON.parse(fs.readFileSync(scenariosPath, 'utf-8'));
    for (const sc of scenariosData) {
      await prisma.gameScenario.create({
        data: {
          code: sc.code,
          difficulty: sc.difficulty,
          title: sc.title,
          situation: sc.situation,
          choices: sc.choices,
          scoring: sc.scoring,
          explanation: sc.explanation,
        },
      });
    }
  }

  // 8. GENERATE 90 DAYS OF TRANSACTIONS & INTEGRITY CHAIN
  console.log('📊 Menghasilkan 90 hari data transaksi historis untuk analitik...');
  const paymentMethods = [PaymentMethod.cash, PaymentMethod.qris_simulated, PaymentMethod.card_simulated];

  // Simpan tracking chain hash per outlet
  const outletChainState: Record<string, { blockIndex: bigint; prevHash: string }> = {};
  for (const outlet of outlets) {
    outletChainState[outlet.id] = {
      blockIndex: BigInt(0),
      prevHash: '0'.repeat(64),
    };
  }

  let txnSeq = 1;
  const now = new Date();

  // Loop 90 hari ke belakang
  for (let dayOffset = 90; dayOffset >= 0; dayOffset--) {
    const txnDate = new Date(now.getTime() - dayOffset * 24 * 60 * 60 * 1000);
    const dateStr = txnDate.toISOString().slice(0, 10).replace(/-/g, '');

    for (const outlet of outlets) {
      // Outlet Jogja dan Bali lebih ramai dibanding Solo dan London
      const txnCount = outlet.id === outletJogja.id ? 8 : (outlet.id === outletBali.id ? 7 : 4);

      for (let t = 0; t < txnCount; t++) {
        // Atur jam transaksi antara 09:00 - 21:00
        const hour = 9 + Math.floor(Math.random() * 12);
        const minute = Math.floor(Math.random() * 60);
        const currentTxnTime = new Date(txnDate);
        currentTxnTime.setHours(hour, minute, 0, 0);

        const outletCode = outlet.name.substring(5, 8).toUpperCase();
        const receiptNo = `TRX-${outletCode}-${dateStr}-${String(txnSeq++).padStart(4, '0')}`;
        const clientReqId = crypto.randomUUID();

        // Pilih 1 - 3 produk
        const itemCount = 1 + Math.floor(Math.random() * 3);
        const itemsToBuy = [];
        let subtotal = 0;

        for (let i = 0; i < itemCount; i++) {
          const product = createdProducts[(t + i * 7) % createdProducts.length];
          const qty = 1 + (t % 3);
          const lineTotal = product.price_idr * qty;
          subtotal += lineTotal;

          itemsToBuy.push({
            product_id: product.id,
            product_name_snapshot: product.name,
            unit_price_idr: product.price_idr,
            unit_cost_idr: product.cost_idr,
            quantity: qty,
            line_total_idr: lineTotal,
          });
        }

        const discount = subtotal > 50000 && t % 4 === 0 ? 5000 : 0;
        const total = subtotal - discount;
        const method = paymentMethods[t % paymentMethods.length];
        const paid = method === PaymentMethod.cash ? Math.ceil(total / 10000) * 10000 + (t % 2 === 0 ? 10000 : 0) : total;
        const change = paid - total;

        // Simpan Transaksi
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
            status: TransactionStatus.completed,
            created_at: currentTxnTime,
            items: {
              create: itemsToBuy,
            },
          },
        });

        // Simpan Blockchain Record (Integrity Chain per Outlet - SRS Section 11)
        const chainState = outletChainState[outlet.id];
        chainState.blockIndex += BigInt(1);

        // Canonical JSON Hash (SRS 11.2)
        const canonicalData = {
          cashier_id: staff.id,
          created_at: currentTxnTime.toISOString(),
          discount_idr: discount,
          id: transaction.id,
          items: itemsToBuy.map(it => ({
            line_total_idr: it.line_total_idr,
            product_id: it.product_id,
            quantity: it.quantity,
            unit_price_idr: it.unit_price_idr,
          })).sort((a, b) => a.product_id.localeCompare(b.product_id)),
          outlet_id: outlet.id,
          payment_method: method,
          receipt_no: receiptNo,
          subtotal_idr: subtotal,
          total_idr: total,
        };

        const canonicalJsonStr = JSON.stringify(canonicalData);
        const dataHash = sha256(canonicalJsonStr);
        const blockHash = sha256(`${chainState.blockIndex}${chainState.prevHash}${dataHash}${currentTxnTime.toISOString()}`);

        await prisma.blockchainRecord.create({
          data: {
            chain_id: outlet.id,
            block_index: chainState.blockIndex,
            record_type: RecordType.transaction,
            record_id: transaction.id,
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

  console.log('✅ Seeding database ARUS selesai dengan sukses!');
  console.log(`- Users: ${await prisma.user.count()} (owner, manager, staff)`);
  console.log(`- Outlets: ${await prisma.outlet.count()} (Jogja, Solo, Bali, London)`);
  console.log(`- Kategori: ${await prisma.productCategory.count()}`);
  console.log(`- Produk: ${await prisma.product.count()} item`);
  console.log(`- Inventaris: ${await prisma.inventory.count()} baris`);
  console.log(`- Transaksi Historis: ${await prisma.transaction.count()} transaksi`);
  console.log(`- Blockchain Blocks: ${await prisma.blockchainRecord.count()} blocks terverifikasi`);
  console.log(`- Game Skenario: ${await prisma.gameScenario.count()} skenario`);
}

main()
  .catch((e) => {
    console.error('❌ Gagal menjalankan seed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
