import { PrismaClient, PaymentMethod, TxnStatus } from '@prisma/client';
import * as crypto from 'crypto';

const prisma = new PrismaClient();

// Fungsi helper buat bikin hash SHA-256
function generateHash(data: string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

async function main() {
  console.log('🚀 Memulai proses seeding ARUS...');

  // 1. CARI USER DAN OUTLET YANG UDAH ADA (Biar nggak ngerusak data awal)
  const outlet = await prisma.outlet.findFirst();
  const cashier = await prisma.user.findFirst({ where: { role: 'staff' } });

  if (!outlet || !cashier) {
    throw new Error('❌ Gagal: Pastikan minimal ada 1 Outlet dan 1 User (role: staff) di database sebelum seeding.');
  }

  // 2. BERSIHIN DATA LAMA (Hati-hati, dari paling child ke parent, USER & OUTLET AMAN)
  console.log('🧹 Membersihkan data transaksi dan katalog lama...');
  await prisma.blockchainRecord.deleteMany();
  await prisma.transactionItem.deleteMany();
  await prisma.transaction.deleteMany();
  await prisma.inventoryMovement.deleteMany();
  await prisma.productRecipe.deleteMany();
  await prisma.product.deleteMany();
  await prisma.ingredient.deleteMany();
  await prisma.productCategory.deleteMany();

  // 3. BIKIN KATEGORI PRODUK
  const catMinuman = await prisma.productCategory.create({ data: { name: 'Minuman' } });
  const catMakanan = await prisma.productCategory.create({ data: { name: 'Makanan' } });

  // 4. BIKIN BAHAN BAKU (Ingredients)
  console.log('📦 Membuat data Bahan Baku...');
  const ingredientsData = [
    { name: 'Biji Kopi Arabica', unit: 'gram', stock_qty: 5000, cost_per_unit: 200, outlet_id: outlet.id },
    { name: 'Susu Segar', unit: 'ml', stock_qty: 20000, cost_per_unit: 15, outlet_id: outlet.id },
    { name: 'Gula Aren', unit: 'gram', stock_qty: 5000, cost_per_unit: 10, outlet_id: outlet.id },
    { name: 'Es Batu', unit: 'pcs', stock_qty: 1000, cost_per_unit: 500, outlet_id: outlet.id },
    { name: 'Daging Ayam', unit: 'pcs', stock_qty: 200, cost_per_unit: 15000, outlet_id: outlet.id },
    { name: 'Nasi Putih', unit: 'porsi', stock_qty: 300, cost_per_unit: 3000, outlet_id: outlet.id },
    { name: 'Cabai Rawit', unit: 'gram', stock_qty: 2000, cost_per_unit: 50, outlet_id: outlet.id },
    { name: 'Teh Hitam', unit: 'gram', stock_qty: 1000, cost_per_unit: 100, outlet_id: outlet.id },
    { name: 'Kentang Goreng', unit: 'gram', stock_qty: 15000, cost_per_unit: 20, outlet_id: outlet.id },
    { name: 'Minyak Goreng', unit: 'ml', stock_qty: 10000, cost_per_unit: 15, outlet_id: outlet.id },
  ];

  const createdIngredients = await Promise.all(
    ingredientsData.map(ing => prisma.ingredient.create({ data: ing }))
  );
  
  // Helper biar gampang nyari ID bahan baku waktu bikin resep
  const getIngId = (name: string) => createdIngredients.find(i => i.name === name)!.id;

  // 5. BIKIN 10 MENU PRODUK BERSERTA RESEPNYA
  console.log('🍔 Membuat 10 Menu Produk beserta Resepnya...');
  const productsData = [
    { sku: 'MNM-001', name: 'Kopi Susu Gula Aren', price_idr: 25000, catId: catMinuman.id, img: '/images/kopsus.png', recipes: [{ name: 'Biji Kopi Arabica', qty: 18 }, { name: 'Susu Segar', qty: 150 }, { name: 'Gula Aren', qty: 30 }, { name: 'Es Batu', qty: 1 }] },
    { sku: 'MNM-002', name: 'Iced Americano', price_idr: 20000, catId: catMinuman.id, img: '/images/americano.png', recipes: [{ name: 'Biji Kopi Arabica', qty: 18 }, { name: 'Es Batu', qty: 1 }] },
    { sku: 'MNM-003', name: 'Hot Latte', price_idr: 28000, catId: catMinuman.id, img: '/images/latte.png', recipes: [{ name: 'Biji Kopi Arabica', qty: 18 }, { name: 'Susu Segar', qty: 200 }] },
    { sku: 'MNM-004', name: 'Es Teh Manis', price_idr: 10000, catId: catMinuman.id, img: '/images/esteh.png', recipes: [{ name: 'Teh Hitam', qty: 5 }, { name: 'Gula Aren', qty: 15 }, { name: 'Es Batu', qty: 1 }] },
    { sku: 'MNM-005', name: 'Teh Tawar Panas', price_idr: 5000, catId: catMinuman.id, img: '/images/tehtawar.png', recipes: [{ name: 'Teh Hitam', qty: 5 }] },
    { sku: 'MKN-001', name: 'Ayam Geprek Original', price_idr: 25000, catId: catMakanan.id, img: '/images/geprek.png', recipes: [{ name: 'Daging Ayam', qty: 1 }, { name: 'Cabai Rawit', qty: 15 }, { name: 'Minyak Goreng', qty: 50 }] },
    { sku: 'MKN-002', name: 'Paket Nasi Ayam Geprek', price_idr: 30000, catId: catMakanan.id, img: '/images/paket-geprek.png', recipes: [{ name: 'Nasi Putih', qty: 1 }, { name: 'Daging Ayam', qty: 1 }, { name: 'Cabai Rawit', qty: 15 }] },
    { sku: 'MKN-003', name: 'French Fries', price_idr: 18000, catId: catMakanan.id, img: '/images/fries.png', recipes: [{ name: 'Kentang Goreng', qty: 150 }, { name: 'Minyak Goreng', qty: 100 }] },
    { sku: 'MKN-004', name: 'Ayam Goreng Polos', price_idr: 20000, catId: catMakanan.id, img: '/images/ayamgoreng.png', recipes: [{ name: 'Daging Ayam', qty: 1 }, { name: 'Minyak Goreng', qty: 50 }] },
    { sku: 'MKN-005', name: 'Nasi Putih Ekstra', price_idr: 6000, catId: catMakanan.id, img: '/images/nasiputih.png', recipes: [{ name: 'Nasi Putih', qty: 1 }] },
  ];

  const products = [];
  for (const p of productsData) {
    const prod = await prisma.product.create({
      data: {
        sku: p.sku,
        name: p.name,
        price_idr: p.price_idr,
        category_id: p.catId,
        image_url: p.img,
        recipes: {
          create: p.recipes.map(r => ({
            ingredient_id: getIngId(r.name),
            amount_needed: r.qty // Mengisi takaran resep
          }))
        }
      }
    });
    products.push(prod);
  }

  // 6. BIKIN 50 TRANSAKSI + BLOCKCHAIN
  console.log('🔗 Meng-generate 50 Transaksi POS dan Merangkai Blockchain...');
  
  // Genesis Hash (Block Awal, isi angka nol semua 64 digit)
  let previousHash = "".padStart(64, "0"); 
  
  let baseDate = new Date();
  baseDate.setHours(baseDate.getHours() - 50); // Mundurin 50 jam buat efek kronologis

  for (let i = 1; i <= 50; i++) {
    const product = products[Math.floor(Math.random() * products.length)];
    const qty = Math.floor(Math.random() * 3) + 1; // 1 sampai 3 qty
    const totalAmount = product.price_idr * qty;
    const trxDate = new Date(baseDate.getTime() + (i * 60 * 60 * 1000)); // Tambah 1 jam tiap transaksi

    // A. Bikin Transaksi & Itemnya
    const txn = await prisma.transaction.create({
      data: {
        receipt_no: `INV-${trxDate.getTime().toString().slice(-6)}-${i}`,
        outlet_id: outlet.id,
        cashier_id: cashier.id,
        client_request_id: crypto.randomUUID(), // Simulasi UUID request dari HP
        subtotal_idr: totalAmount,
        total_idr: totalAmount,
        payment_method: i % 3 === 0 ? PaymentMethod.qris_simulated : PaymentMethod.cash, // Selang-seling QRIS/Cash
        paid_idr: totalAmount,
        status: TxnStatus.completed,
        created_at: trxDate,
        items: {
          create: {
            product_id: product.id,
            product_name_snapshot: product.name,
            unit_price_idr: product.price_idr,
            quantity: qty,
            line_total_idr: totalAmount
          }
        }
      }
    });

    // B. Langsung Rangkai ke Blockchain
    // Kita simpan data penting aja di dalam payload block
    const eventDataPayload = {
      txn_id: txn.id,
      receipt_no: txn.receipt_no,
      total: txn.total_idr,
      method: txn.payment_method
    };
    
    const dataHash = generateHash(JSON.stringify(eventDataPayload));
    
    // Hash akhir block = SHA-256 dari (Index + Data Hash + Previous Hash)
    const blockHash = generateHash(`${i}${dataHash}${previousHash}`);

    await prisma.blockchainRecord.create({
      data: {
        outlet_id: outlet.id,
        block_index: i,
        event_type: 'sale',
        transaction_id: txn.id,
        event_data: eventDataPayload,
        data_hash: dataHash,
        prev_hash: previousHash,
        block_hash: blockHash,
        // Karena ini blok valid bawaan (bukan editan), data backup kita samain sama data aslinya untuk Self-Healing.
        backup_event_data: eventDataPayload,
        backup_data_hash: dataHash,
        backup_prev_hash: previousHash,
        backup_block_hash: blockHash,
        created_at: trxDate
      }
    });

    // Update previousHash buat transaksi/block selanjutnya
    previousHash = blockHash;
  }

  console.log('✅ SEEDING SELESAI! 50 transaksi sukses masuk Blockchain tanpa nyentuh tabel User.');
}

main()
  .catch((e) => {
    console.error('❌ Error saat seeding:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });