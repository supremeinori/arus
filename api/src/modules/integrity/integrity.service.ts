import { AppError } from '../../shared/errors';
import { DualLocalBlockchain, TransactionData, ValidationResult } from './dual_blockchain';

export interface IntegrityBlock {
  block_index: number;
  outlet_id: string;
  previous_hash: string;
  payload_hash: string;
  merkle_root: string;
  record_count: number;
  timestamp: string;
  is_valid: boolean;
}

export class IntegrityService {
  private outletChains: Map<string, DualLocalBlockchain> = new Map();

  /**
   * Mendapatkan atau membuat instance DualLocalBlockchain untuk outlet tertentu
   */
  public getOrCreateChain(outletId: string): DualLocalBlockchain {
    let chain = this.outletChains.get(outletId);
    if (!chain) {
      chain = new DualLocalBlockchain(outletId);
      this.outletChains.set(outletId, chain);
    }
    return chain;
  }

  /** Finalisasi blok harian aktif untuk penutupan operasional. */
  public closeCurrentDay(outletId: string) {
    const chain = this.getOrCreateChain(outletId);
    const firstTransaction = chain.currentDayTransactions[0];
    if (!firstTransaction) {
      throw new AppError('INVALID_INPUT', 400, 'Tidak ada transaksi aktif untuk ditutup.');
    }
    return chain.closeDay(firstTransaction.timestamp.slice(0, 10));
  }

  /**
   * Mendapatkan struktur pohon visualisasi blockchain ganda (Block dalam Block)
   */
  public getVisualizationData(outletId: string) {
    const chain = this.getOrCreateChain(outletId);
    return chain.getVisualizationTree();
  }

  /**
   * Validasi integritas kriptografis rantai blockchain
   */
  public validateChain(outletId: string): ValidationResult {
    const chain = this.getOrCreateChain(outletId);
    return chain.isChainValid();
  }

  /**
   * Simulasi manipulasi data transaksi
   */
  public simulateTampering(outletId: string, dayIndex: number, txIndex: number, fakeAmount: number) {
    const chain = this.getOrCreateChain(outletId);
    return chain.simulateTampering(dayIndex, txIndex, fakeAmount);
  }

  /**
   * Pemulihan (recovery) dari cadangan valid
   */
  public recoverChain(outletId: string, dayIndex: number) {
    const chain = this.getOrCreateChain(outletId);
    return chain.recoverAndResync(dayIndex);
  }

  /**
   * Menambahkan transaksi baru ke dalam rantai aktif
   */
  public recordTransaction(outletId: string, tx: TransactionData, timestamp = new Date().toISOString()) {
    const eventTime = new Date(timestamp);
    if (Number.isNaN(eventTime.getTime())) {
      throw new Error('Timestamp transaksi blockchain tidak valid.');
    }

    const chain = this.getOrCreateChain(outletId);
    const eventDate = eventTime.toISOString().slice(0, 10);
    const activeDate = chain.currentDayTransactions[0]?.timestamp.slice(0, 10);

    if (activeDate && eventDate < activeDate) {
      throw new Error('Transaksi tidak dapat ditambahkan ke rantai setelah hari yang lebih baru.');
    }
    if (activeDate && eventDate > activeDate) {
      chain.closeDay(activeDate);
    }

    return chain.addTransaction(tx, eventTime.toISOString());
  }

  /**
   * Legacy endpoint compatibility
   */
  getChainForOutlet(outletId: string): IntegrityBlock[] {
    const chain = this.getOrCreateChain(outletId);
    return chain.dailyChain.map((parent) => ({
      block_index: parent.dayIndex + 1,
      outlet_id: parent.outletId,
      previous_hash: parent.previousHash,
      payload_hash: parent.hash,
      merkle_root: parent.merkleRoot,
      record_count: parent.transactionBlocks.length,
      timestamp: parent.timestamp,
      is_valid: true,
    }));
  }

  verifyTransaction(transactionId: string) {
    for (const chain of this.outletChains.values()) {
      const committedBlocks = chain.dailyChain.flatMap((day) => day.transactionBlocks);
      const allBlocks = [...committedBlocks, ...chain.currentDayTransactions];
      const block = allBlocks.find((candidate) => candidate.data.transactionId === transactionId);
      if (block) {
        const computedHash = block.calculateHash();
        const isValid = computedHash === block.hash;
        return {
          transaction_id: transactionId,
          is_valid: isValid,
          stored_hash: block.hash,
          computed_hash: computedHash,
          ledger_status: isValid ? 'VALID' : 'TAMPERED',
          block_index: block.index,
          timestamp: block.timestamp,
        };
      }
    }

    return {
      transaction_id: transactionId,
      is_valid: false,
      stored_hash: null,
      computed_hash: null,
      ledger_status: 'NOT_FOUND',
      block_index: null,
      timestamp: null,
    };
  }

  verifyReport(reportId: string) {
    return {
      report_id: reportId,
      is_valid: false,
      stored_hash: null,
      computed_hash: null,
      ledger_status: 'NOT_FOUND',
      block_index: null,
      timestamp: null,
    };
  }
}

export const integrityService = new IntegrityService();
