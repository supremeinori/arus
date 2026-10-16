import { z } from 'zod';

export const createNotificationSchema = z.object({
  user_id: z.string().uuid(),
  type: z.string().default('system_alert'),
  title: z.string().min(1),
  body: z.string().min(1),
  payload: z.record(z.any()).optional(),
  dedup_key: z.string().optional(),
});

export type CreateNotificationInput = z.infer<typeof createNotificationSchema>;
