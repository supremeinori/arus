import { describe, it, expect, beforeEach } from 'vitest';
import { DualLocalBlockchain, GENESIS_HASH } from '../src/modules/integrity/dual_blockchain';

describe('Dual Local Blockchain Module (ARUS Integrity)', () => {
  let blockchain: DualLocalBlockchain;
  const outletId = 'out-bdg-001';

  beforeEach(() => {
    blockchain = new DualLocalBlockchain(outletId);
  });

  describe('1. Struktur Blockchain Ganda (Block dalam Block)', () => {
    it('harus membuat TransactionBlock individu dengan enkripsi SHA-256 dan hash valid', () => {
      const tx = blockchain.addTransaction({
        transactionId: 'tx-1',
        receiptNo: 'TXN-001',
        cashierId: 'cashier-1',
        totalAmount: 50000,
        items: [{ name: 'Kopi', qty: 2, price: 25000 }],
      });

      expect(tx.index).toBe(0);
      expect(tx.previousHash).toBe(GENESIS_HASH);
      expect(tx.hash).toBe(tx.calculateHash());
      expect(tx.hash.length).toBe(64); // SHA-256 hex length
    });

    it('harus merangkum seluruh transaksi dalam 1 hari menjadi DailyParentBlock', () => {
      blockchain.addTransaction({
        transactionId: 'tx-1',
        receiptNo: 'TXN-001',
        cashierId: 'c1',
        totalAmount: 20000,
        items: [],
      });
      blockchain.addTransaction({
        transactionId: 'tx-2',
        receiptNo: 'TXN-002',
        cashierId: 'c1',
        totalAmount: 30000,
        items: [],
      });

      const day1 = blockchain.closeDay('2026-10-15');

      expect(day1.dayIndex).toBe(0);
      expect(day1.transactionBlocks.length).toBe(2);
      expect(day1.previousHash).toBe(GENESIS_HASH);
      expect(day1.hash).toBe(day1.calculateHash());
      expect(day1.merkleRoot).toBe(day1.calculateMerkleRoot());
      expect(blockchain.currentDayTransactions.length).toBe(0); // Mempool harus bersih setelah closeDay
    });

    it('harus menghubungkan Parent Block hari ke-2 ke Parent Block hari ke-1', () => {
      blockchain.addTransaction({ transactionId: 'tx-1', receiptNo: 'T1', cashierId: 'c1', totalAmount: 10000, items: [] });
      const day1 = blockchain.closeDay('2026-10-15');

      blockchain.addTransaction({ transactionId: 'tx-2', receiptNo: 'T2', cashierId: 'c1', totalAmount: 20000, items: [] });
      const day2 = blockchain.closeDay('2026-10-16');

      expect(day2.dayIndex).toBe(1);
      expect(day2.previousHash).toBe(day1.hash);
      expect(day2.hash).toBe(day2.calculateHash());
    });
  });

  describe('2. Validasi & Integritas Rantai (isChainValid)', () => {
    it('harus menghasilkan status VALID jika rantai tidak dimanipulasi', () => {
      blockchain.addTransaction({ transactionId: 'tx-1', receiptNo: 'T1', cashierId: 'c1', totalAmount: 15000, items: [] });
      blockchain.closeDay('2026-10-15');

      blockchain.addTransaction({ transactionId: 'tx-2', receiptNo: 'T2', cashierId: 'c1', totalAmount: 25000, items: [] });
      blockchain.closeDay('2026-10-16');

      const result = blockchain.isChainValid();
      expect(result.isValid).toBe(true);
      expect(result.status).toBe('VALID');
    });
  });

  describe('3. Simulasi Manipulasi & Pemulihan (Tamper Detection & Recovery)', () => {
    beforeEach(() => {
      blockchain.addTransaction({ transactionId: 'tx-1', receiptNo: 'T1', cashierId: 'c1', totalAmount: 15000, items: [] });
      blockchain.addTransaction({ transactionId: 'tx-2', receiptNo: 'T2', cashierId: 'c1', totalAmount: 30000, items: [] });
      blockchain.closeDay('2026-10-15');
    });

    it('harus mendeteksi modifikasi data di tengah transaksi dan berstatus TAMPERED', () => {
      // Manipulasi totalAmount transaksi #1
      blockchain.simulateTampering(0, 1, 99999999);

      const check = blockchain.isChainValid();
      expect(check.isValid).toBe(false);
      expect(check.status).toBe('TAMPERED');
      expect(check.details?.dayIndex).toBe(0);
      expect(check.details?.blockIndex).toBe(1);
    });

    it('harus berhasil memulihkan integritas data dari snapshot cadangan (Recovery & Resync)', () => {
      // 1. Rusak data
      blockchain.simulateTampering(0, 1, 99999999);
      expect(blockchain.isChainValid().isValid).toBe(false);

      // 2. Pulihkan
      const recovery = blockchain.recoverAndResync(0);
      expect(recovery.success).toBe(true);
      expect(recovery.validation.isValid).toBe(true);
      expect(recovery.validation.status).toBe('VALID');

      // 3. Pastikan data transaksi kembali normal
      expect(blockchain.dailyChain[0].transactionBlocks[1].data.totalAmount).toBe(30000);
    });
  });

  describe('4. Struktur Data Visualisasi', () => {
    it('harus menghasilkan representasi pohon terstruktur untuk UI', () => {
      blockchain.addTransaction({ transactionId: 'tx-1', receiptNo: 'T1', cashierId: 'c1', totalAmount: 10000, items: [] });
      blockchain.closeDay('2026-10-15');

      const tree = blockchain.getVisualizationTree();
      expect(tree.outletId).toBe(outletId);
      expect(tree.totalDays).toBe(1);
      expect(tree.days[0].transactions.length).toBe(1);
      expect(tree.days[0].transactions[0].receiptNo).toBe('T1');
    });
  });
});
