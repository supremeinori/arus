import { env } from '../../config/env';
import { ConvertQueryInput } from './fx.schema';

/**
 * Fallback kurs (basis IDR) — dipakai hanya bila API kurs eksternal gagal.
 * Nilai dibulatkan dari kurs live terakhir yang diketahui.
 */
const FALLBACK_RATES: Record<string, number> = {
  IDR: 1,
  USD: 0.0000559, // 1 USD ≈ Rp 17.885
  EUR: 0.0000499, // 1 EUR ≈ Rp 20.037
  SGD: 0.0001786, // 1 SGD ≈ Rp 5.599
  JPY: 0.0088492, // 1 JPY ≈ Rp 112,99
  MYR: 0.0002284, // 1 MYR ≈ Rp 4.378
  GBP: 0.0000423, // 1 GBP ≈ Rp 23.636
};

const RATE_TTL_MS = 10 * 60 * 1000;

export class FxService {
  private cachedRates: Record<string, number> | null = null;
  private cachedAsOf = '';
  private cachedAt = 0;

  /**
   * Ambil kurs live dari FX_API_URL lalu normalkan ke basis IDR.
   *
   * API publik (frankfurter) menerbitkan basis EUR, sedangkan seluruh nominal
   * internal ARUS disimpan dalam IDR. Karena itu setiap kurs dibagi dengan
   * kurs IDR agar hasilnya "1 IDR = X mata uang".
   */
  private async fetchLiveRates(): Promise<{ rates: Record<string, number>; asOf: string } | null> {
    const now = Date.now();
    if (this.cachedRates && now - this.cachedAt < RATE_TTL_MS) {
      return { rates: this.cachedRates, asOf: this.cachedAsOf };
    }

    try {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 5000);
      const response = await fetch(env.FX_API_URL, { signal: controller.signal });
      clearTimeout(timer);

      if (!response.ok) return null;

      const payload: any = await response.json();
      const rawRates = payload?.rates;
      if (!rawRates || typeof rawRates !== 'object') return null;

      const idrPerBase = Number(rawRates.IDR);
      if (!Number.isFinite(idrPerBase) || idrPerBase <= 0) return null;

      const rates: Record<string, number> = { IDR: 1 };
      for (const [code, value] of Object.entries(rawRates as Record<string, unknown>)) {
        const num = Number(value);
        if (!Number.isFinite(num) || num <= 0) continue;
        rates[code] = num / idrPerBase;
      }

      this.cachedRates = rates;
      this.cachedAsOf = String(payload?.date ?? new Date().toISOString().slice(0, 10));
      this.cachedAt = now;

      return { rates, asOf: this.cachedAsOf };
    } catch (_) {
      return null;
    }
  }

  async getRates() {
    const live = await this.fetchLiveRates();
    const rates = live?.rates ?? { ...FALLBACK_RATES };
    const asOf = live?.asOf ?? new Date().toISOString().slice(0, 10);

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
