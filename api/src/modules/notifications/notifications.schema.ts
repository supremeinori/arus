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

export const registerDeviceTokenSchema = z.object({
  token: z.string().min(1),
  platform: z.enum(['android', 'ios', 'web']).default('android'),
});

export type RegisterDeviceTokenInput = z.infer<typeof registerDeviceTokenSchema>;
