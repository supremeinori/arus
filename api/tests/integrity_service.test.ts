import { describe, expect, it } from 'vitest';
import { IntegrityService } from '../src/modules/integrity/integrity.service';

describe('IntegrityService live transaction integration', () => {
  it('starts empty and records actual POS transactions without demo data', () => {
    const service = new IntegrityService();
    const before = service.getVisualizationData('outlet-live');

    expect(before.totalDays).toBe(0);
    expect(before.currentActiveTxCount).toBe(0);

    service.recordTransaction('outlet-live', {
      transactionId: 'transaction-real-1',
      receiptNo: 'INV-20261016-0001',
      cashierId: 'cashier-real-1',
      totalAmount: 42000,
      items: [{ name: 'Cappuccino', qty: 2, price: 21000 }],
    });

    const after = service.getVisualizationData('outlet-live');
    expect(after.currentActiveTxCount).toBe(1);
    expect(after.days).toHaveLength(0);
  });

  it('closes the previous daily block when the next day transaction arrives', () => {
    const service = new IntegrityService();
    service.recordTransaction('outlet-live', {
      transactionId: 'transaction-day-1',
      receiptNo: 'INV-DAY-1',
      cashierId: 'cashier-1',
      totalAmount: 10000,
      items: [],
    }, '2026-10-15T12:00:00.000Z');
    service.recordTransaction('outlet-live', {
      transactionId: 'transaction-day-2',
      receiptNo: 'INV-DAY-2',
      cashierId: 'cashier-1',
      totalAmount: 20000,
      items: [],
    }, '2026-10-16T12:00:00.000Z');

    const tree = service.getVisualizationData('outlet-live');
    expect(tree.days).toHaveLength(1);
    expect(tree.days[0].date).toBe('2026-10-15');
    expect(tree.days[0].transactions[0].receiptNo).toBe('INV-DAY-1');
    expect(tree.currentActiveTxCount).toBe(1);
    expect(service.validateChain('outlet-live').isValid).toBe(true);
  });

  it('supports end-of-day settlement and creates a trusted recovery snapshot', () => {
    const service = new IntegrityService();
    service.recordTransaction('outlet-live', {
      transactionId: 'transaction-settlement',
      receiptNo: 'INV-SETTLE',
      cashierId: 'cashier-1',
      totalAmount: 25000,
      items: [],
    }, '2026-10-16T12:00:00.000Z');

    const dailyBlock = service.closeCurrentDay('outlet-live');
    expect(dailyBlock.date).toBe('2026-10-16');
    expect(service.getVisualizationData('outlet-live').currentActiveTxCount).toBe(0);
    expect(service.recoverChain('outlet-live', 0).success).toBe(true);
    expect(service.validateChain('outlet-live').isValid).toBe(true);
  });
});
