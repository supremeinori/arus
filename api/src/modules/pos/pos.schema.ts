import { z } from 'zod';

export const posCatalogQuerySchema = z.object({
  outlet_id: z.string().min(1, 'outlet_id wajib disertakan'),
});

export const posCheckoutSchema = z.object({
  outlet_id: z.string().min(1, 'outlet_id wajib disertakan'),
  client_request_id: z.string().min(1, 'client_request_id wajib disertakan'),
  payment_method: z.enum(['cash', 'qris_simulated', 'card_simulated']),
  paid_idr: z.number().int().nonnegative('paid_idr tidak boleh negatif'),
  discount_idr: z.number().int().nonnegative().default(0),
  items: z
    .array(
      z.object({
        product_id: z.string().min(1),
        quantity: z.number().int().positive('Quantity harus lebih dari 0'),
      })
    )
    .min(1, 'Keranjang transaksi tidak boleh kosong'),
});

export const posVoidSchema = z.object({
  transaction_id: z.string().min(1, 'transaction_id wajib disertakan'),
  outlet_id: z.string().min(1).optional(),
  reason: z.string().min(1, 'Alasan void wajib diisi'),
});

export type PosCheckoutInput = z.infer<typeof posCheckoutSchema>;
