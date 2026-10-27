import { describe, it, expect } from 'vitest';
import { web3AnchorService } from '../src/modules/integrity/web3_anchor.service';

describe('Web3 Ethereum Sepolia Anchor Service', () => {
  it('harus membaca status dan detail smart contract Sepolia dengan benar', () => {
    const status = web3AnchorService.getStatus();
    expect(status.contractAddress.toLowerCase()).toBe(
      '0x910d935f00922A340889Abf8221Db30c03CEE3C1'.toLowerCase()
    );
    expect(status.chainId).toBe(11155111);
    expect(status.network).toContain('Sepolia');
    expect(status.etherscanContractUrl).toBe(
      'https://sepolia.etherscan.io/address/0x910d935f00922A340889Abf8221Db30c03CEE3C1'
    );
  });

  it('harus memverifikasi struk yang belum terdaftar langsung dari smart contract tanpa error fatal', async () => {
    const result = await web3AnchorService.verifyReceiptOnChain('TXN-NON-EXISTENT-999');
    expect(result.verified).toBe(false);
    expect(result.receiptNo).toBe('TXN-NON-EXISTENT-999');
    expect(result.network).toContain('Sepolia');
    expect(result.message).toBeDefined();
  });

  it('harus menangani anchorReceiptAsync secara aman tanpa melempar unhandled rejection', async () => {
    await expect(
      web3AnchorService.anchorReceiptAsync('TXN-DUMMY-TEST', 'dummy-uuid-123')
    ).resolves.toBeUndefined();
  });
});
