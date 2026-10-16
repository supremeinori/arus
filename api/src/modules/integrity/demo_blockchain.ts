import { DualLocalBlockchain } from './dual_blockchain';
import type { TransactionData } from './dual_blockchain';

console.log('================================================================');
console.log('  ARUS LOCAL BLOCKCHAIN: DUAL CHAIN & TAMPER RECOVERY TEST      ');
console.log('================================================================\n');

// 1. Inisialisasi Local Blockchain untuk Cabang Bandung
const outletId = 'out-bdg-001';
const chainManager = new DualLocalBlockchain(outletId);

console.log(`[1] Inisialisasi Rantai Blockchain untuk Outlet: ${outletId}`);

// Simulasi Hari 1: 2026-10-15 (3 Transaksi)
console.log('\n--- Transaksi Hari 1 (2026-10-15) ---');
const tx1: TransactionData = {
  transactionId: 'txn-101',
  receiptNo: 'TXN-BDG-20261015-0001',
  cashierId: 'usr-kasir-1',
  totalAmount: 45000,
  items: [{ name: 'Kopi Susu Gula Aren', qty: 2, price: 22500 }],
};
const tx2: TransactionData = {
  transactionId: 'txn-102',
  receiptNo: 'TXN-BDG-20261015-0002',
  cashierId: 'usr-kasir-1',
  totalAmount: 32000,
  items: [{ name: 'Croissant Cokelat', qty: 1, price: 32000 }],
};
const tx3: TransactionData = {
  transactionId: 'txn-103',
  receiptNo: 'TXN-BDG-20261015-0003',
  cashierId: 'usr-kasir-2',
  totalAmount: 18000,
  items: [{ name: 'Es Teh Manis', qty: 2, price: 9000 }],
};

const blk1 = chainManager.addTransaction(tx1);
const blk2 = chainManager.addTransaction(tx2);
const blk3 = chainManager.addTransaction(tx3);

console.log(`  + Blok Transaksi #0: Hash = ${blk1.hash.substring(0, 16)}... (Prev = ${blk1.previousHash.substring(0, 12)}...)`);
console.log(`  + Blok Transaksi #1: Hash = ${blk2.hash.substring(0, 16)}... (Prev = ${blk2.previousHash.substring(0, 12)}...)`);
console.log(`  + Blok Transaksi #2: Hash = ${blk3.hash.substring(0, 16)}... (Prev = ${blk3.previousHash.substring(0, 12)}...)`);

// Tutup Buku Hari 1 -> Menghasilkan Parent Block Hari 1
const day1Parent = chainManager.closeDay('2026-10-15');
console.log(`\n[+] Tutup Buku Hari 1 Selesai!`);
console.log(`    Parent Block #0 (2026-10-15):`);
console.log(`    - Total Transaksi: ${day1Parent.transactionBlocks.length}`);
console.log(`    - Merkle Root    : ${day1Parent.merkleRoot}`);
console.log(`    - Previous Hash  : ${day1Parent.previousHash.substring(0, 20)}... (Genesis)`);
console.log(`    - Daily Hash     : ${day1Parent.hash}`);

// Simulasi Hari 2: 2026-10-16 (2 Transaksi)
console.log('\n--- Transaksi Hari 2 (2026-10-16) ---');
const tx4: TransactionData = {
  transactionId: 'txn-201',
  receiptNo: 'TXN-BDG-20261016-0001',
  cashierId: 'usr-kasir-1',
  totalAmount: 95000,
  items: [{ name: 'Paket Sarapan Lengkap', qty: 1, price: 95000 }],
};
const tx5: TransactionData = {
  transactionId: 'txn-202',
  receiptNo: 'TXN-BDG-20261016-0002',
  cashierId: 'usr-kasir-2',
  totalAmount: 50000,
  items: [{ name: 'Caramel Macchiato', qty: 2, price: 25000 }],
};

const blk4 = chainManager.addTransaction(tx4);
const blk5 = chainManager.addTransaction(tx5);
console.log(`  + Blok Transaksi #0: Hash = ${blk4.hash.substring(0, 16)}...`);
console.log(`  + Blok Transaksi #1: Hash = ${blk5.hash.substring(0, 16)}...`);

const day2Parent = chainManager.closeDay('2026-10-16');
console.log(`\n[+] Tutup Buku Hari 2 Selesai!`);
console.log(`    Parent Block #1 (2026-10-16):`);
console.log(`    - Total Transaksi: ${day2Parent.transactionBlocks.length}`);
console.log(`    - Merkle Root    : ${day2Parent.merkleRoot}`);
console.log(`    - Previous Hash  : ${day2Parent.previousHash} (Sama dengan Daily Hash Hari 1!)`);
console.log(`    - Daily Hash     : ${day2Parent.hash}`);

// 2. Uji isChainValid() pada Kondisi Normal
console.log('\n================================================================');
console.log('[2] Validasi Integritas Awal (Kondisi Normal)');
let check = chainManager.isChainValid();
console.log(`    Status  : ${check.status}`);
console.log(`    IsValid : ${check.isValid}`);
console.log(`    Pesan   : ${check.message}`);

// 3. Simulasi Manipulasi Data (Tampering)
console.log('\n================================================================');
console.log('[3] Simulasi Serangan / Manipulasi Data (Tampering)');
console.log('    Skenario: Seseorang mengubah data transaksi di database.');
console.log('    Transaksi Hari 1, Struk #TXN-BDG-20261015-0002 diubah totalnya: 32000 -> 99999999');

const tamperInfo = chainManager.simulateTampering(0, 1, 99999999);
console.log(`    Eksekusi Manipulasi:`, tamperInfo);

console.log('\n    -> Menjalankan Audit Integritas isChainValid() pasca manipulasi:');
const tamperCheck = chainManager.isChainValid();
console.log(`    Status  : [${tamperCheck.status}]`);
console.log(`    IsValid : ${tamperCheck.isValid}`);
console.log(`    Pesan   : ${tamperCheck.message}`);
console.log(`    Detail  :`, tamperCheck.details);

// 4. Simulasi Pemulihan Data (Recovery & Resync)
console.log('\n================================================================');
console.log('[4] Simulasi Pemulihan Integritas (Recovery & Resync)');
console.log('    Sistem memulihkan blok rusak dari Cadangan Snapshot Valid...');

const recoveryResult = chainManager.recoverAndResync(0);
console.log(`    Hasil Pemulihan: ${recoveryResult.message}`);
console.log(`    Status Akhir   : [${recoveryResult.validation.status}]`);
console.log(`    IsValid Akhir  : ${recoveryResult.validation.isValid}`);

// 5. Visualisasi Struktur Data untuk Role Owner & Manager
console.log('\n================================================================');
console.log('[5] Struktur Data Siap Render untuk UI Visualisasi (Tree Format)');
const vizData = chainManager.getVisualizationTree();
console.log(`    Outlet ID           : ${vizData.outletId}`);
console.log(`    Total Hari Tercatat : ${vizData.totalDays} hari`);
vizData.days.forEach((d) => {
  console.log(`    * [Parent Day #${d.dayIndex} - ${d.date}] ParentHash: ${d.parentHash.substring(0, 16)}... | Merkle: ${d.merkleRoot.substring(0, 16)}... | ${d.transactionCount} Transaksi:`);
  d.transactions.forEach((t) => {
    console.log(`        - Tx #${t.index}: Struk ${t.receiptNo} | Rp ${t.totalAmount.toLocaleString('id-ID')} | Hash: ${t.hash.substring(0, 16)}...`);
  });
});
console.log('================================================================\n');
