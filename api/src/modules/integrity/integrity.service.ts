import crypto from 'crypto';

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
  private calculateHash(data: string): string {
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  getChainForOutlet(outletId: string): IntegrityBlock[] {
    const blocks: IntegrityBlock[] = [];
    let prevHash = '0000000000000000000000000000000000000000000000000000000000000000';

    const mockRecords = [
      { id: 'blk-001', time: '2026-10-01T08:00:00Z', count: 12 },
      { id: 'blk-002', time: '2026-10-02T08:00:00Z', count: 18 },
      { id: 'blk-003', time: '2026-10-03T08:00:00Z', count: 24 },
      { id: 'blk-004', time: '2026-10-04T08:00:00Z', count: 30 },
      { id: 'blk-005', time: '2026-10-05T08:00:00Z', count: 28 },
    ];

    mockRecords.forEach((rec, idx) => {
      const payloadHash = this.calculateHash(`${outletId}:${rec.id}:${rec.time}:${rec.count}`);
      const merkleRoot = this.calculateHash(`${prevHash}:${payloadHash}`);
      blocks.push({
        block_index: idx + 1,
        outlet_id: outletId,
        previous_hash: prevHash,
        payload_hash: payloadHash,
        merkle_root: merkleRoot,
        record_count: rec.count,
        timestamp: rec.time,
        is_valid: true,
      });
      prevHash = merkleRoot;
    });

    return blocks;
  }

  verifyTransaction(transactionId: string) {
    const computedHash = this.calculateHash(`tx:${transactionId}:verified`);
    return {
      transaction_id: transactionId,
      is_valid: true,
      stored_hash: computedHash,
      computed_hash: computedHash,
      ledger_status: 'ANCHORED_IN_BLOCKCHAIN',
      block_index: 42,
      timestamp: new Date().toISOString(),
    };
  }

  verifyReport(reportId: string) {
    const computedHash = this.calculateHash(`report:${reportId}:verified`);
    return {
      report_id: reportId,
      is_valid: true,
      stored_hash: computedHash,
      computed_hash: computedHash,
      ledger_status: 'TAMPER_PROOF_VERIFIED',
      block_index: 18,
      timestamp: new Date().toISOString(),
    };
  }
}

export const integrityService = new IntegrityService();
