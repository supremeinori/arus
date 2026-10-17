import { z } from 'zod';

export const recommendPriceSchema = z.object({
  menu_name: z.string().min(1, 'menu_name wajib diisi').max(120),
  total_cogs_idr: z.coerce.number().int().min(0).max(999999999),
  recipes: z
    .array(
      z.object({
        ingredient_id: z.string().min(1).optional(),
        amount_needed: z.coerce.number().min(0).optional(),
        ingredientId: z.string().min(1).optional(),
        amountNeeded: z.coerce.number().min(0).optional(),
      }).passthrough()
    )
    .optional()
    .default([]),
});

export const aiChatSchema = z.object({
  conversation_id: z.string().optional(),
  message: z.string().min(1, 'Pesan tidak boleh kosong'),
  outlet_id: z.string().optional(),
  screen_context: z.string().optional(),
});

export const ttsSchema = z.object({
  text: z.string().min(1, 'Teks wajib diisi').max(2000),
});

export type RecommendPriceInput = z.infer<typeof recommendPriceSchema>;
export type AiChatInput = z.infer<typeof aiChatSchema>;
export type TtsInput = z.infer<typeof ttsSchema>;

