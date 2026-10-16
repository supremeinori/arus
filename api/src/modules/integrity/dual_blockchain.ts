import crypto from 'node:crypto';

/**
 * Utilitas untuk hashing SHA-256 deterministik (canonical).
 */
export function sha256(data: string): string {
  return crypto.createHash('sha256').update(data).digest('hex');
}

/**
 * Serialisasi JSON secara deterministik (mengurutkan key)
 * agar hash selalu konsisten terlepas dari urutan properti objek.
 */
export function canonicalJson(data: unknown): string {
  if (data === null || typeof data !== 'object') {
    return JSON.stringify(data) ?? 'null';
  }
  if (Array.isArray(data)) {
    return `[${data.map(canonicalJson).join(',')}]`;
  }
  const record = data as Record<string, unknown>;
  const sortedKeys = Object.keys(record).sort();
  const entries = sortedKeys.map((key) => `${JSON.stringify(key)}:${canonicalJson(record[key])}`);
  return `{${entries.join(',')}}`;
}

export const GENESIS_HASH = '0000000000000000000000000000000000000000000000000000000000000000';

/**
 * ============================================================================
 * 1. CHILD BLOCK: TransactionBlock
 * ============================================================================
 * Menyimpan data transaksi harian/individual.
 * Atribut: index, timestamp, data transaksi, previousHash, hash.
 */
export interface TransactionData {
  transactionId: string;
  receiptNo: string;
  cashierId: string;
  totalAmount: number;
  items: Array<{
    name: string;
    qty: number;
    price: number;
  }>;
  eventType?: 'sale' | 'void_return' | 'restock' | 'correction' | 'waste';
  sourceId?: string;
  [key: string]: unknown;
}

export class TransactionBlock {
  public index: number;
  public timestamp: string;
  public data: TransactionData;
  public previousHash: string;
  public hash: string;

  constructor(
    index: number,
    data: TransactionData,
    previousHash: string = GENESIS_HASH,
    timestamp?: string,
    hash?: string
  ) {
    this.index = index;
    this.timestamp = timestamp || new Date().toISOString();
    this.data = data;
    this.previousHash = previousHash;
    this.hash = hash || this.calculateHash();
  }

  /**
   * Menghitung SHA-256 dari seluruh payload blok transaksi
   */
  public calculateHash(): string {
    const payload = `${this.index}|${this.timestamp}|${canonicalJson(this.data)}|${this.previousHash}`;
    return sha256(payload);
  }

  /**
   * Clone objek untuk keperluan backup snapshot
   */
  public clone(): TransactionBlock {
    return new TransactionBlock(
      this.index,
      JSON.parse(JSON.stringify(this.data)),
      this.previousHash,
      this.timestamp,
      this.hash
    );
  }
}

/**
 * ============================================================================
 * 2. PARENT BLOCK: DailyParentBlock ("Daily Chain")
 * ============================================================================
 * Merangkum seluruh transaksi dalam 1 hari menjadi satu blok induk harian
 * yang terhubung secara kriptografis ke Daily Parent Block hari sebelumnya.
 */
export class DailyParentBlock {
  public dayIndex: number;
  public date: string; // Format: YYYY-MM-DD
  public outletId: string;
  public timestamp: string;
  public transactionBlocks: TransactionBlock[];
  public merkleRoot: string;
  public previousHash: string;
  public hash: string;

  constructor(
    dayIndex: number,
    date: string,
    outletId: string,
    transactionBlocks: TransactionBlock[],
    previousHash: string = GENESIS_HASH,
    timestamp?: string,
    merkleRoot?: string,
    hash?: string
  ) {
    this.dayIndex = dayIndex;
    this.date = date;
    this.outletId = outletId;
    this.transactionBlocks = transactionBlocks;
    this.previousHash = previousHash;
    this.timestamp = timestamp || new Date().toISOString();
    this.merkleRoot = merkleRoot || this.calculateMerkleRoot();
    this.hash = hash || this.calculateHash();
  }

  /**
   * Menghitung Merkle Root dari seluruh hash transaksi pada hari tersebut.
   * Menggunakan binary tree pairwise hashing.
   */
  public calculateMerkleRoot(): string {
    if (this.transactionBlocks.length === 0) {
      return sha256(`EMPTY_DAY:${this.date}`);
    }

    let hashes = this.transactionBlocks.map((tx) => tx.hash);

    while (hashes.length > 1) {
      const nextLevel: string[] = [];
      for (let i = 0; i < hashes.length; i += 2) {
        if (i + 1 < hashes.length) {
          nextLevel.push(sha256(hashes[i] + hashes[i + 1]));
        } else {
          // Jika jumlah ganjil, gandakan hash terakhir sesuai standar Bitcoin Merkle Tree
          nextLevel.push(sha256(hashes[i] + hashes[i]));
        }
      }
      hashes = nextLevel;
    }

    return hashes[0];
  }

  /**
   * Menghitung hash Parent Block harian
   */
  public calculateHash(): string {
    const payload = `${this.dayIndex}|${this.date}|${this.outletId}|${this.timestamp}|${this.merkleRoot}|${this.previousHash}`;
    return sha256(payload);
  }

  /**
   * Clone objek untuk cadangan/backup snapshot
   */
  public clone(): DailyParentBlock {
    const clonedTxs = this.transactionBlocks.map((tx) => tx.clone());
    return new DailyParentBlock(
      this.dayIndex,
      this.date,
      this.outletId,
      clonedTxs,
      this.previousHash,
      this.timestamp,
      this.merkleRoot,
      this.hash
    );
  }
}

/**
 * Hasil validasi integritas rantai
 */
export interface ValidationResult {
  isValid: boolean;
  status: 'VALID' | 'TAMPERED' | 'BROKEN_CHAIN';
  message: string;
  details?: {
    scope: 'PARENT_DAILY_CHAIN' | 'CHILD_TRANSACTION_CHAIN';
    dayIndex?: number;
    blockIndex?: number;
    expectedHash?: string;
    actualHash?: string;
  };
}

/**
 * ============================================================================
 * 3. DUAL LOCAL BLOCKCHAIN MANAGER
 * ============================================================================
 * Mengelola rantai ganda:
 * - Mempool transaksi hari berjalan
 * - Rantai Parent Block harian
 * - Validasi, Simulasi Manipulasi, dan Pemulihan (Recovery)
 */
export class DualLocalBlockchain {
  public outletId: string;
  public dailyChain: DailyParentBlock[] = [];
  public currentDayTransactions: TransactionBlock[] = [];
  
  // Penyimpanan cadangan terpercaya (Backup Store / Immutable Mirror)
  // Mensimulasikan snapshot SQLite/Cold Backup untuk pemulihan data tamper
  private backupStore: Map<number, DailyParentBlock> = new Map();

  constructor(outletId: string) {
    this.outletId = outletId;
  }

  /**
   * Menambah transaksi baru pada hari berjalan (Child Block)
   */
  public addTransaction(data: TransactionData, timestamp?: string): TransactionBlock {
    const index = this.currentDayTransactions.length;
    const previousHash =
      index === 0
        ? GENESIS_HASH
        : this.currentDayTransactions[index - 1].hash;

    const newBlock = new TransactionBlock(index, data, previousHash, timestamp);
    this.currentDayTransactions.push(newBlock);
    return newBlock;
  }

  /**
   * Tutup buku harian (Daily Settlement):
   * Mengemas seluruh transaksi hari ini menjadi 1 Parent Block,
   * lalu menghubungkannya ke Parent Block hari sebelumnya.
   */
  public closeDay(dateStr: string): DailyParentBlock {
    const dayIndex = this.dailyChain.length;
    const previousHash =
      dayIndex === 0
        ? GENESIS_HASH
        : this.dailyChain[dayIndex - 1].hash;

    const parentBlock = new DailyParentBlock(
      dayIndex,
      dateStr,
      this.outletId,
      [...this.currentDayTransactions],
      previousHash
    );

    this.dailyChain.push(parentBlock);

    // Simpan cadangan snapshot yang valid ke backupStore
    this.backupStore.set(dayIndex, parentBlock.clone());

    // Reset transaksi harian untuk hari baru berikutnya
    this.currentDayTransactions = [];

    return parentBlock;
  }

  /**
   * Memeriksa validasi dan integritas seluruh struktur rantai (Parent & Child).
   */
  public isChainValid(): ValidationResult {
    // 1. Validasi Rantai Parent Harian
    for (let d = 0; d < this.dailyChain.length; d++) {
      const currentParent = this.dailyChain[d];

      // A. Cek integritas hash Parent Block itu sendiri
      const recalculatedParentHash = currentParent.calculateHash();
      if (currentParent.hash !== recalculatedParentHash) {
        return {
          isValid: false,
          status: 'TAMPERED',
          message: `Parent Block hari ke-${d} (${currentParent.date}) telah dimanipulasi! Hash tidak cocok.`,
          details: {
            scope: 'PARENT_DAILY_CHAIN',
            dayIndex: d,
            expectedHash: recalculatedParentHash,
            actualHash: currentParent.hash,
          },
        };
      }

      // B. Cek sambungan rantai harian (previousHash)
      if (d === 0) {
        if (currentParent.previousHash !== GENESIS_HASH) {
          return {
            isValid: false,
            status: 'BROKEN_CHAIN',
            message: `Genesis Parent Block memiliki previousHash yang tidak valid.`,
            details: { scope: 'PARENT_DAILY_CHAIN', dayIndex: 0 },
          };
        }
      } else {
        const prevParent = this.dailyChain[d - 1];
        if (currentParent.previousHash !== prevParent.hash) {
          return {
            isValid: false,
            status: 'BROKEN_CHAIN',
            message: `Rantai Parent Block terputus antara hari ke-${d - 1} dan hari ke-${d}!`,
            details: {
              scope: 'PARENT_DAILY_CHAIN',
              dayIndex: d,
              expectedHash: prevParent.hash,
              actualHash: currentParent.previousHash,
            },
          };
        }
      }

      // C. Cek Merkle Root parent terhadap transaksi-transaksi di dalamnya
      const recalculatedMerkleRoot = currentParent.calculateMerkleRoot();
      if (currentParent.merkleRoot !== recalculatedMerkleRoot) {
        return {
          isValid: false,
          status: 'TAMPERED',
          message: `Merkle Root Parent Block hari ke-${d} (${currentParent.date}) tidak cocok dengan transaksi internalnya! Terindikasi modifikasi data transaksi.`,
          details: {
            scope: 'PARENT_DAILY_CHAIN',
            dayIndex: d,
            expectedHash: recalculatedMerkleRoot,
            actualHash: currentParent.merkleRoot,
          },
        };
      }

      // D. Validasi Child Blocks (Transaksi di dalam Parent Block)
      for (let t = 0; t < currentParent.transactionBlocks.length; t++) {
        const txBlock = currentParent.transactionBlocks[t];

        // Cek apakah data transaksi dimanipulasi
        const recalculatedTxHash = txBlock.calculateHash();
        if (txBlock.hash !== recalculatedTxHash) {
          return {
            isValid: false,
            status: 'TAMPERED',
            message: `Transaksi [Index #${t}] pada hari ke-${d} dimodifikasi secara ilegal!`,
            details: {
              scope: 'CHILD_TRANSACTION_CHAIN',
              dayIndex: d,
              blockIndex: t,
              expectedHash: recalculatedTxHash,
              actualHash: txBlock.hash,
            },
          };
        }

        // Cek apakah rantai transaksi dalam hari itu putus
        if (t === 0) {
          if (txBlock.previousHash !== GENESIS_HASH) {
            return {
              isValid: false,
              status: 'BROKEN_CHAIN',
              message: `Transaksi awal [Index #0] pada hari ke-${d} memiliki previousHash salah.`,
              details: { scope: 'CHILD_TRANSACTION_CHAIN', dayIndex: d, blockIndex: 0 },
            };
          }
        } else {
          const prevTxBlock = currentParent.transactionBlocks[t - 1];
          if (txBlock.previousHash !== prevTxBlock.hash) {
            return {
              isValid: false,
              status: 'BROKEN_CHAIN',
              message: `Rantai transaksi terputus pada hari ke-${d} antara transaksi #${t - 1} dan #${t}!`,
              details: {
                scope: 'CHILD_TRANSACTION_CHAIN',
                dayIndex: d,
                blockIndex: t,
                expectedHash: prevTxBlock.hash,
                actualHash: txBlock.previousHash,
              },
            };
          }
        }
      }
    }

    // 2. Validasi transaksi yang sedang berlangsung pada hari berjalan (jika ada)
    for (let t = 0; t < this.currentDayTransactions.length; t++) {
      const txBlock = this.currentDayTransactions[t];
      if (txBlock.hash !== txBlock.calculateHash()) {
        return {
          isValid: false,
          status: 'TAMPERED',
          message: `Transaksi aktif hari ini [Index #${t}] dimanipulasi!`,
          details: {
            scope: 'CHILD_TRANSACTION_CHAIN',
            blockIndex: t,
          },
        };
      }
      if (t === 0 && txBlock.previousHash !== GENESIS_HASH) {
        return {
          isValid: false,
          status: 'BROKEN_CHAIN',
          message: 'Transaksi pertama pada hari berjalan tidak terhubung ke genesis hash.',
          details: {
            scope: 'CHILD_TRANSACTION_CHAIN',
            blockIndex: 0,
            expectedHash: GENESIS_HASH,
            actualHash: txBlock.previousHash,
          },
        };
      }
      if (t > 0 && txBlock.previousHash !== this.currentDayTransactions[t - 1].hash) {
        return {
          isValid: false,
          status: 'BROKEN_CHAIN',
          message: `Rantai transaksi aktif hari ini terputus di #${t}!`,
          details: { scope: 'CHILD_TRANSACTION_CHAIN', blockIndex: t },
        };
      }
    }

    return {
      isValid: true,
      status: 'VALID',
      message: 'Seluruh struktur rantai Blockchain (Parent & Child) utuh dan valid secara kriptografis.',
    };
  }

  /**
   * Simulasi manipulasi data transaksi secara ilegal di database.
   * Contoh: Mengubah totalAmount dari Rp 50.000 menjadi Rp 5.000.000 tanpa memperbarui hash.
   */
  public simulateTampering(dayIndex: number, txIndex: number, fakeAmount: number) {
    if (!this.dailyChain[dayIndex]) {
      throw new Error(`Parent Block untuk dayIndex ${dayIndex} tidak ditemukan.`);
    }

    const parentBlock = this.dailyChain[dayIndex];
    if (!parentBlock.transactionBlocks[txIndex]) {
      throw new Error(`Transaksi index ${txIndex} pada dayIndex ${dayIndex} tidak ditemukan.`);
    }

    const targetTx = parentBlock.transactionBlocks[txIndex];
    const originalAmount = targetTx.data.totalAmount;

    // Mutasi ilegal data payload
    targetTx.data.totalAmount = fakeAmount;

    return {
      dayIndex,
      txIndex,
      originalAmount,
      tamperedAmount: fakeAmount,
      receiptNo: targetTx.data.receiptNo,
      action: 'DATA_TAMPERED_IN_MEMORY',
    };
  }

  /**
   * Pemulihan (Rollback / Resync) dari Cadangan Valid.
   * Mengembalikan blok yang rusak ke keadaan semula dari backup store terpercaya.
   */
  public recoverAndResync(dayIndex: number): { success: boolean; message: string; validation: ValidationResult } {
    const backup = this.backupStore.get(dayIndex);
    if (!backup) {
      return {
        success: false,
        message: `Cadangan snapshot untuk hari ke-${dayIndex} tidak ditemukan di Backup Store.`,
        validation: this.isChainValid(),
      };
    }

    // Timpa ulang rantai yang rusak dengan clone snapshot bersih
    this.dailyChain[dayIndex] = backup.clone();

    // Jalankan validasi ulang penuh
    const validation = this.isChainValid();

    return {
      success: validation.isValid,
      message: validation.isValid
        ? `Hari ke-${dayIndex} berhasil dipulihkan secara sempurna dari Cadangan Snapshot Valid.`
        : `Gagal memulihkan integritas penuh pada hari ke-${dayIndex}.`,
      validation,
    };
  }

  /**
   * Format representasi data terstruktur untuk visualisasi di UI (Mobile/Web)
   */
  public getVisualizationTree() {
    return {
      outletId: this.outletId,
      totalDays: this.dailyChain.length,
      currentActiveTxCount: this.currentDayTransactions.length,
      days: this.dailyChain.map((parent) => ({
        dayIndex: parent.dayIndex,
        date: parent.date,
        parentHash: parent.hash,
        previousParentHash: parent.previousHash,
        merkleRoot: parent.merkleRoot,
        timestamp: parent.timestamp,
        transactionCount: parent.transactionBlocks.length,
        transactions: parent.transactionBlocks.map((tx) => ({
          index: tx.index,
          timestamp: tx.timestamp,
          hash: tx.hash,
          previousHash: tx.previousHash,
          receiptNo: tx.data.receiptNo,
          totalAmount: tx.data.totalAmount,
          cashierId: tx.data.cashierId,
          eventType: tx.data.eventType ?? 'sale',
          sourceId: tx.data.sourceId ?? tx.data.transactionId,
        })),
      })),
    };
  }
}
