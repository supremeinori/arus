import { ethers } from 'ethers';
import { prisma } from '../../config/db';

const ARUS_LEDGER_ABI = [
  'event ReceiptAnchored(string indexed receiptNo, string blockHash, uint256 timestamp)',
  'function anchorReceipt(string memory _receiptNo, string memory _blockHash) public',
  'function verifyReceipt(string memory _receiptNo) public view returns (string memory blockHash, uint256 timestamp)',
  'function records(string memory) public view returns (string memory receiptNo, string memory blockHash, uint256 timestamp)',
];

export class Web3AnchorService {
  private contractAddress: string;
  private rpcUrl: string;
  private privateKey?: string;

  constructor() {
    this.contractAddress =
      process.env.SMART_CONTRACT_ADDRESS || '0x910d935f00922A340889Abf8221Db30c03CEE3C1';
    this.rpcUrl =
      process.env.SEPOLIA_RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com';
    this.privateKey = process.env.SEPOLIA_PRIVATE_KEY?.trim() || undefined;
  }

  /**
   * Status apakah konfigurasi private key sudah siap untuk broadcast transaksi
   */
  isConfigured(): boolean {
    const pk = this.getPrivateKey();
    return Boolean(pk && pk.length >= 64 && pk !== 'PASTE_PRIVATE_KEY_KAMU_DISINI');
  }

  private getPrivateKey(): string | undefined {
    return process.env.SEPOLIA_PRIVATE_KEY?.trim() || this.privateKey;
  }

  private getContractAddress(): string {
    return process.env.SMART_CONTRACT_ADDRESS?.trim() || this.contractAddress;
  }

  private getRpcUrl(): string {
    return process.env.SEPOLIA_RPC_URL?.trim() || this.rpcUrl;
  }

  getReadOnlyProvider(): ethers.JsonRpcProvider {
    return new ethers.JsonRpcProvider(this.getRpcUrl(), 11155111);
  }

  getReadOnlyContract(): ethers.Contract {
    const provider = this.getReadOnlyProvider();
    return new ethers.Contract(this.getContractAddress(), ARUS_LEDGER_ABI, provider);
  }

  getWritableContract(): { contract: ethers.Contract; wallet: ethers.Wallet } {
    const pk = this.getPrivateKey();
    if (!pk || pk.length < 64) {
      throw new Error('SEPOLIA_PRIVATE_KEY belum diisi di file .env');
    }
    const cleanPk = pk.startsWith('0x') ? pk : `0x${pk}`;
    const provider = this.getReadOnlyProvider();
    const wallet = new ethers.Wallet(cleanPk, provider);
    const contract = new ethers.Contract(this.getContractAddress(), ARUS_LEDGER_ABI, wallet);
    return { contract, wallet };
  }

  /**
   * Mencatat receipt ke smart contract Sepolia secara asinkron (non-blocking).
   * Fungsi ini tidak akan menghambat proses kasir di POS.
   */
  async anchorReceiptAsync(receiptNo: string, transactionId?: string): Promise<void> {
    // Jalankan di microtask/background agar tidak memblok caller
    setImmediate(async () => {
      try {
        if (!this.isConfigured()) {
          console.info(
            `[Web3AnchorService] Sepolia private key belum dikonfigurasi. Lewati on-chain anchoring untuk ${receiptNo}.`
          );
          return;
        }

        // Cari record block di DB untuk mendapatkan block_hash transaksi ini
        let blockHash = '';
        if (transactionId) {
          const record = await prisma.blockchainRecord.findFirst({
            where: { transaction_id: transactionId },
            select: { id: true, block_hash: true, event_data: true },
          });
          if (record) {
            blockHash = record.block_hash;
          }
        }

        if (!blockHash) {
          // Fallback hash jika block hash belum terindeks
          blockHash = ethers.id(`${receiptNo}:${Date.now()}`);
        }

        console.info(`[Web3AnchorService] Mengirim anchor ke Sepolia untuk struk ${receiptNo}...`);
        const { contract } = this.getWritableContract();

        // Panggil fungsi smart contract anchorReceipt(_receiptNo, _blockHash)
        const tx = await contract.anchorReceipt(receiptNo, blockHash);
        console.info(`[Web3AnchorService] Transaksi Sepolia terkirim! TxHash: ${tx.hash}`);

        // Tunggu 1 konfirmasi blok
        const receipt = await tx.wait(1);
        console.info(
          `[Web3AnchorService] Struk ${receiptNo} resmi terverifikasi on-chain di blok #${receipt?.blockNumber}! URL: https://sepolia.etherscan.io/tx/${tx.hash}`
        );

        // Update record blockchain di PostgreSQL dengan bukti on-chain
        if (transactionId) {
          const existing = await prisma.blockchainRecord.findFirst({
            where: { transaction_id: transactionId },
          });

          if (existing) {
            const updatedData = {
              ...(typeof existing.event_data === 'object' && existing.event_data !== null
                ? (existing.event_data as Record<string, unknown>)
                : {}),
              sepolia_anchored: true,
              sepolia_tx_hash: tx.hash,
              sepolia_block_number: receipt?.blockNumber ?? null,
              sepolia_contract_address: this.getContractAddress(),
              sepolia_anchored_at: new Date().toISOString(),
              etherscan_url: `https://sepolia.etherscan.io/tx/${tx.hash}`,
            };

            await prisma.blockchainRecord.update({
              where: { id: existing.id },
              data: {
                event_data: updatedData,
              },
            });
          }
        }
      } catch (err: any) {
        // Jangan crash server jika ada kegagalan gas atau network
        console.warn(
          `[Web3AnchorService] Gagal anchor ${receiptNo} ke Sepolia:`,
          err?.message || err
        );
      }
    });
  }

  /**
   * Verifikasi struk langsung dari smart contract publik Sepolia
   */
  async verifyReceiptOnChain(receiptNo: string): Promise<{
    verified: boolean;
    receiptNo: string;
    blockHash?: string;
    timestamp?: number;
    etherscanAddress: string;
    network: string;
    message?: string;
  }> {
    try {
      const contract = this.getReadOnlyContract();
      const result = await contract.verifyReceipt(receiptNo);
      const blockHash = result[0];
      const timestampSec = Number(result[1]);

      return {
        verified: true,
        receiptNo,
        blockHash,
        timestamp: timestampSec * 1000,
        etherscanAddress: `https://sepolia.etherscan.io/address/${this.getContractAddress()}`,
        network: 'Ethereum Sepolia (ChainID: 11155111)',
      };
    } catch (err: any) {
      return {
        verified: false,
        receiptNo,
        etherscanAddress: `https://sepolia.etherscan.io/address/${this.getContractAddress()}`,
        network: 'Ethereum Sepolia (ChainID: 11155111)',
        message: err?.message?.includes('Struk tidak ditemukan')
          ? 'Struk belum tercatat di smart contract Sepolia'
          : err?.message || 'Gagal memverifikasi di blockchain',
      };
    }
  }

  /**
   * Info status modul Web3
   */
  getStatus() {
    return {
      configured: this.isConfigured(),
      contractAddress: this.getContractAddress(),
      network: 'Ethereum Sepolia Testnet',
      chainId: 11155111,
      rpcUrl: this.getRpcUrl(),
      etherscanContractUrl: `https://sepolia.etherscan.io/address/${this.getContractAddress()}`,
    };
  }
}

export const web3AnchorService = new Web3AnchorService();
