import { z } from 'zod';

export const convertQuerySchema = z.object({
  amount: z.coerce.number().positive('Nominal harus lebih besar dari 0'),
  from: z.enum(['IDR', 'USD', 'EUR']).default('IDR'),
  to: z.enum(['IDR', 'USD', 'EUR']).default('USD'),
});

export type ConvertQueryInput = z.infer<typeof convertQuerySchema>;
