import { beforeEach, describe, expect, it, vi } from 'vitest';
import { Prisma } from '@prisma/client';
import { IntegrityService } from '../src/modules/integrity/blockchain.service';

describe('Persistent single-layer transaction blockchain', () => {
  let records: Array<Record<string, unknown>>;
  let db: Record<string, any>;
  let service: IntegrityService;

  beforeEach(() => {
    records = [];
    db = {
      $queryRaw: vi.fn().mockResolvedValue([]),
      $executeRaw: vi.fn().mockResolvedValue(0),
      blockchainRecord: {
        findUnique: vi.fn(async ({ where }: { where: { event_id?: string; id?: string } }) =>
          records.find((record) => record.event_id === where.event_id || record.id === where.id) ?? null,
        ),
        findFirst: vi.fn(async ({ where }: { where: { outlet_id: string } }) =>
          records
            .filter((record) => record.outlet_id === where.outlet_id)
            .sort((a, b) => Number(b.block_index) - Number(a.block_index))[0] ?? null,
        ),
        findMany: vi.fn(async ({ where }: { where: { outlet_id: string } }) =>
          records
            .filter((record) => record.outlet_id === where.outlet_id)
            .sort((a, b) => Number(a.block_index) - Number(b.block_index)),
        ),
        create: vi.fn(async ({ data }: { data: Record<string, unknown> }) => {
          const record = { id: `block-${records.length + 1}`, created_at: new Date(), ...data };
          records.push(record);
          return record;
        }),
        update: vi.fn(async ({ where, data }: { where: { id: string }; data: Record<string, unknown> }) => {
          const record = records.find((candidate) => candidate.id === where.id);
          if (!record) throw new Error('block not found');
          Object.assign(record, data);
          return record;
        }),
      },
    };
    service = new IntegrityService(db as never);
  });

  it('persists sales and inventory events in one continuous outlet chain', async () => {
    const tx = db as unknown as Prisma.TransactionClient;
    const first = await service.appendEvent(tx, 'outlet-1', {
      eventId: 'sale:txn-1',
      eventType: 'sale',
      transactionId: 'txn-1',
      eventData: { receipt_no: 'INV-1', total_idr: 12000 },
    });
    const second = await service.appendEvent(tx, 'outlet-1', {
      eventId: 'inventory:movement-1',
      eventType: 'restock',
      eventData: { ingredient_id: 'ing-1', quantity_delta: 30 },
    });

    expect(first.block_index).toBe(1);
    expect(second.block_index).toBe(2);
    expect(second.prev_hash).toBe(first.block_hash);
    expect(second.event_type).toBe('restock');
    expect(records).toHaveLength(2);
    expect(db.blockchainRecord.create).toHaveBeenCalledTimes(2);
  });

  it('rebuilds the visible chain from database rows in a fresh service instance', async () => {
    const tx = db as unknown as Prisma.TransactionClient;
    await service.appendEvent(tx, 'outlet-1', {
      eventId: 'sale:txn-1',
      eventType: 'sale',
      eventData: { receipt_no: 'INV-1', total_idr: 12000 },
    });
    await service.appendEvent(tx, 'outlet-1', {
      eventId: 'void:txn-1',
      eventType: 'void_return',
      eventData: { receipt_no: 'INV-1', reason: 'mistake' },
    });

    const restartedService = new IntegrityService(db as never);
    const visualization = await restartedService.getVisualizationData('outlet-1');

    expect(visualization.blockCount).toBe(2);
    expect(visualization.blocks.map((block: { eventType: string }) => block.eventType)).toEqual([
      'sale',
      'void_return',
    ]);
  });

  it('detects altered persisted payload and restores it from the verified database backup', async () => {
    const tx = db as unknown as Prisma.TransactionClient;
    await service.appendEvent(tx, 'outlet-1', {
      eventId: 'sale:txn-1',
      eventType: 'sale',
      eventData: { receipt_no: 'INV-1', total_idr: 12000 },
    });
    const blockId = records[0].id as string;

    await service.simulateTampering('outlet-1', 1, 999999);
    expect((await service.validateChain('outlet-1')).status).toBe('TAMPERED');

    const recovery = await service.recoverBlock('outlet-1', 1);
    expect(recovery.success).toBe(true);
    expect((await service.validateChain('outlet-1')).status).toBe('VALID');
    const restored = records.find((record) => record.id === blockId);
    expect(restored?.event_data).toEqual(restored?.backup_event_data);
  });
});
