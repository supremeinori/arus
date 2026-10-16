import { PrismaClient, Prisma } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import {
  BlockchainEvent,
  ChainValidationResult,
  canonicalJson,
  GENESIS_HASH,
  sha256,
  TransactionBlock,
} from './blockchain';

type StoredBlock = {
  id: string;
  outlet_id: string;
  block_index: number;
  event_id: string;
  event_type: string;
  transaction_id: string | null;
  event_data: Prisma.JsonValue | null;
  data_hash: string;
  prev_hash: string;
  block_hash: string;
  backup_event_data: Prisma.JsonValue | null;
  backup_data_hash: string | null;
  backup_prev_hash: string | null;
  backup_block_hash: string | null;
  created_at: Date;
  transaction?: {
    id: string;
    receipt_no: string;
    total_idr: number;
    cashier_id: string;
    items: Array<{
      product_name_snapshot: string;
      quantity: number;
      unit_price_idr: number;
    }>;
  } | null;
};

function isJsonObject(value: Prisma.JsonValue | null): value is Prisma.JsonObject {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function legacyTransactionData(block: StoredBlock): Record<string, unknown> {
  const transaction = block.transaction;
  if (!transaction) return {};
  return {
    transaction_id: transaction.id,
    receipt_no: transaction.receipt_no,
    total_idr: transaction.total_idr,
    cashier_id: transaction.cashier_id,
    items: transaction.items.map((item) => ({
      name: item.product_name_snapshot,
      quantity: item.quantity,
      unit_price_idr: item.unit_price_idr,
    })),
    legacy_block: true,
  };
}

export class IntegrityService {
  constructor(private readonly db: PrismaClient = prisma) {}

  /** Append one permanent event while holding an outlet-scoped transaction lock. */
  async appendEvent(
    tx: Prisma.TransactionClient,
    outletId: string,
    event: BlockchainEvent,
    timestamp = new Date()
  ) {
    await tx.$queryRaw`SELECT pg_advisory_xact_lock(hashtext(${outletId}))`;

    const existing = await tx.blockchainRecord.findUnique({ where: { event_id: event.eventId } });
    if (existing) return existing;

    const previous = await tx.blockchainRecord.findFirst({
      where: { outlet_id: outletId },
      orderBy: { block_index: 'desc' },
      select: { block_index: true, block_hash: true },
    });
    const index = (previous?.block_index ?? 0) + 1;
    const previousHash = previous?.block_hash ?? GENESIS_HASH;
    const eventData: Record<string, unknown> = {
      ...event.eventData,
      event_id: event.eventId,
      event_type: event.eventType,
      timestamp: timestamp.toISOString(),
    };
    const dataHash = sha256(canonicalJson(eventData));
    const blockHash = TransactionBlock.calculateBlockHash(outletId, index, dataHash, previousHash);

    return tx.blockchainRecord.create({
      data: {
        outlet_id: outletId,
        block_index: index,
        event_id: event.eventId,
        event_type: event.eventType,
        transaction_id: event.transactionId,
        event_data: eventData as Prisma.InputJsonValue,
        data_hash: dataHash,
        prev_hash: previousHash,
        block_hash: blockHash,
        backup_event_data: eventData as Prisma.InputJsonValue,
        backup_data_hash: dataHash,
        backup_prev_hash: previousHash,
        backup_block_hash: blockHash,
        created_at: timestamp,
      },
    });
  }

  async getVisualizationData(outletId: string) {
    const rows = (await this.db.blockchainRecord.findMany({
      where: { outlet_id: outletId },
      orderBy: { block_index: 'asc' },
      include: {
        transaction: {
          include: { items: true },
        },
      },
    })) as StoredBlock[];

    return {
      outletId,
      blockCount: rows.length,
      blocks: rows.map((row) => ({
        index: row.block_index,
        eventId: row.event_id,
        eventType: row.event_type,
        transactionId: row.transaction_id,
        timestamp: row.created_at.toISOString(),
        previousHash: row.prev_hash,
        dataHash: row.data_hash,
        hash: row.block_hash,
        data: isJsonObject(row.event_data) ? row.event_data : legacyTransactionData(row),
        recoverable: row.backup_event_data !== null && row.backup_data_hash !== null,
      })),
    };
  }

  async validateChain(outletId: string): Promise<ChainValidationResult> {
    const rows = (await this.db.blockchainRecord.findMany({
      where: { outlet_id: outletId },
      orderBy: { block_index: 'asc' },
    })) as StoredBlock[];

    let expectedPreviousHash = GENESIS_HASH;
    for (let position = 0; position < rows.length; position += 1) {
      const row = rows[position];
      if (row.block_index !== position + 1 || row.prev_hash !== expectedPreviousHash) {
        return {
          isValid: false,
          status: 'BROKEN_CHAIN',
          message: `Rantai terputus pada blok #${row.block_index}.`,
          details: { blockIndex: row.block_index, expectedHash: expectedPreviousHash, actualHash: row.prev_hash },
        };
      }

      if (isJsonObject(row.event_data)) {
        const calculatedDataHash = sha256(canonicalJson(row.event_data));
        if (calculatedDataHash !== row.data_hash) {
          return {
            isValid: false,
            status: 'TAMPERED',
            message: `Payload blok #${row.block_index} telah dimanipulasi.`,
            details: { blockIndex: row.block_index, expectedHash: calculatedDataHash, actualHash: row.data_hash },
          };
        }
      }

      const calculatedBlockHash = TransactionBlock.calculateBlockHash(
        outletId,
        row.block_index,
        row.data_hash,
        row.prev_hash
      );
      if (calculatedBlockHash !== row.block_hash) {
        return {
          isValid: false,
          status: 'TAMPERED',
          message: `Hash blok #${row.block_index} tidak cocok.`,
          details: { blockIndex: row.block_index, expectedHash: calculatedBlockHash, actualHash: row.block_hash },
        };
      }

      expectedPreviousHash = row.block_hash;
    }

    return {
      isValid: true,
      status: 'VALID',
      message: `Seluruh ${rows.length} blok transaksi tersambung dan hash-nya valid.`,
    };
  }

  async simulateTampering(outletId: string, blockIndex: number, fakeAmount: number) {
    const row = (await this.db.blockchainRecord.findFirst({
      where: { outlet_id: outletId, block_index: blockIndex },
    })) as StoredBlock | null;
    if (!row || !isJsonObject(row.event_data)) {
      throw new AppError('NOT_FOUND', 404, `Blok #${blockIndex} tidak ditemukan atau tidak memiliki payload yang dapat diuji.`);
    }

    const originalData = row.event_data as Record<string, Prisma.JsonValue>;
    const amountKey = typeof originalData.total_idr === 'number' ? 'total_idr' : 'totalAmount';
    const originalAmount = originalData[amountKey];
    const alteredData = { ...originalData, [amountKey]: fakeAmount };
    await this.db.blockchainRecord.update({
      where: { id: row.id },
      data: { event_data: alteredData as Prisma.InputJsonValue },
    });

    return {
      blockIndex,
      eventId: row.event_id,
      originalAmount: typeof originalAmount === 'number' ? originalAmount : null,
      tamperedAmount: fakeAmount,
      action: 'PERSISTED_PAYLOAD_TAMPERED',
    };
  }

  async recoverBlock(outletId: string, blockIndex: number) {
    const row = (await this.db.blockchainRecord.findFirst({
      where: { outlet_id: outletId, block_index: blockIndex },
    })) as StoredBlock | null;
    if (!row || !isJsonObject(row.backup_event_data) || !row.backup_data_hash || !row.backup_prev_hash || !row.backup_block_hash) {
      const validation = await this.validateChain(outletId);
      return { success: false, message: `Cadangan valid untuk blok #${blockIndex} tidak ditemukan.`, validation };
    }

    const snapshotHash = sha256(canonicalJson(row.backup_event_data));
    const snapshotBlockHash = TransactionBlock.calculateBlockHash(
      outletId,
      row.block_index,
      row.backup_data_hash,
      row.backup_prev_hash
    );
    if (snapshotHash !== row.backup_data_hash || snapshotBlockHash !== row.backup_block_hash) {
      const validation = await this.validateChain(outletId);
      return { success: false, message: `Cadangan blok #${blockIndex} gagal diverifikasi.`, validation };
    }

    await this.db.blockchainRecord.update({
      where: { id: row.id },
      data: {
        event_data: row.backup_event_data as Prisma.InputJsonValue,
        data_hash: row.backup_data_hash,
        prev_hash: row.backup_prev_hash,
        block_hash: row.backup_block_hash,
      },
    });
    const validation = await this.validateChain(outletId);
    return {
      success: validation.isValid,
      message: validation.isValid ? `Blok #${blockIndex} berhasil dipulihkan.` : `Rantai tetap tidak valid setelah pemulihan blok #${blockIndex}.`,
      validation,
    };
  }
}

export const integrityService = new IntegrityService();
