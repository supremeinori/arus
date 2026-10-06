import { z } from 'zod';
import { NotificationType, NotificationPriority } from '@prisma/client';

export const createNotificationSchema = z.object({
  user_id: z.string().uuid(),
  type: z.nativeEnum(NotificationType),
  priority: z.nativeEnum(NotificationPriority).default(NotificationPriority.normal),
  title: z.string().min(1),
  body: z.string().min(1),
  payload: z.record(z.any()).optional(),
  dedup_key: z.string().optional(),
});

export type CreateNotificationInput = z.infer<typeof createNotificationSchema>;
