import { prisma } from '../../config/db';
import { ConvertQueryInput } from './fx.schema';

// Fallback rates jika DB exchange_rates belum di-seed
const FALLBACK_RATES: Record<string, number> = {
  USD: 0.000062, // ~Rp 16.129 / USD
  EUR: 0.000058, // ~Rp 17.241 / EUR
};

export class FxService {
  private inMemoryRates = {
    USD: 0.000062,
    EUR: 0.000058,
  };

  async getRates() {
    const rates: Record<string, number> = {
      IDR: 1.0,
      USD: this.inMemoryRates.USD,
      EUR: this.inMemoryRates.EUR,
    };

    const asOf = new Date().toISOString().slice(0, 10);

    return {
      base: 'IDR',
      as_of: asOf,
      rates,
    };
  }

  async convert(input: ConvertQueryInput) {
    const { amount, from, to } = input;
    const { rates, as_of } = await this.getRates();

    let convertedAmount = amount;

    if (from === to) {
      convertedAmount = amount;
    } else if (from === 'IDR') {
      const targetRate = rates[to] || FALLBACK_RATES[to] || 1;
      convertedAmount = amount * targetRate;
    } else if (to === 'IDR') {
      const sourceRate = rates[from] || FALLBACK_RATES[from] || 1;
      convertedAmount = amount / sourceRate;
    } else {
      // Cross rate (misal USD -> EUR)
      const toIdr = amount / (rates[from] || 1);
      convertedAmount = toIdr * (rates[to] || 1);
    }

    return {
      original_amount: amount,
      from_currency: from,
      converted_amount: Number(convertedAmount.toFixed(to === 'IDR' ? 0 : 2)),
      to_currency: to,
      exchange_rate_used: rates[to] || rates[from],
      as_of,
    };
  }
}
