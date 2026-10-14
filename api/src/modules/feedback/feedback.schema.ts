import { z } from 'zod';

export const createFeedbackSchema = z.object({
  kesan: z.string().min(1, 'Kesan tidak boleh kosong.'),
  saran: z.string().min(1, 'Saran tidak boleh kosong.'),
  rating: z.number().int().min(1).max(5).optional().default(5),
});

export type CreateFeedbackInput = z.infer<typeof createFeedbackSchema>;
