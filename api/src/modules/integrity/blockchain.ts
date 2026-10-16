import crypto from 'node:crypto';

export const GENESIS_HASH = '0'.repeat(64);

export type BlockchainEventType = 'sale' | 'void_return' | 'restock' | 'correction' | 'waste';

export interface BlockchainEvent {
  eventId: string;
  eventType: BlockchainEventType;
  eventData: Record<string, unknown>;
  transactionId?: string;
}

export interface ChainValidationResult {
  isValid: boolean;
  status: 'VALID' | 'TAMPERED' | 'BROKEN_CHAIN';
  message: string;
  details?: {
    blockIndex: number;
    expectedHash?: string;
    actualHash?: string;
  };
}

export function sha256(value: string): string {
  return crypto.createHash('sha256').update(value).digest('hex');
}

export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== 'object') {
    if (typeof value === 'bigint') return JSON.stringify(value.toString());
    return JSON.stringify(value) ?? 'null';
  }
  if (value instanceof Date) return JSON.stringify(value.toISOString());
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;

  const objectValue = value as Record<string, unknown>;
  const entries = Object.keys(objectValue)
    .sort()
    .map((key) => `${JSON.stringify(key)}:${canonicalJson(objectValue[key])}`);
  return `{${entries.join(',')}}`;
}

export class TransactionBlock {
  constructor(
    public readonly outletId: string,
    public readonly index: number,
    public readonly eventId: string,
    public readonly eventType: BlockchainEventType | string,
    public readonly timestamp: string,
    public readonly eventData: Record<string, unknown>,
    public readonly previousHash: string,
    public readonly dataHash = sha256(canonicalJson(eventData)),
    public readonly hash = TransactionBlock.calculateBlockHash(outletId, index, dataHash, previousHash)
  ) {}

  static calculateBlockHash(outletId: string, index: number, dataHash: string, previousHash: string): string {
    return sha256(`${outletId}${index}${dataHash}${previousHash}`);
  }

  calculateDataHash(): string {
    return sha256(canonicalJson(this.eventData));
  }

  calculateHash(): string {
    return TransactionBlock.calculateBlockHash(this.outletId, this.index, this.dataHash, this.previousHash);
  }
}
