import { z } from 'zod';

export const createOutletSchema = z.object({
  name: z.string().min(3, 'Nama outlet minimal 3 karakter').max(100),
  address: z.string().min(5, 'Alamat outlet minimal 5 karakter'),
  latitude: z.number().min(-90).max(90, 'Latitude harus di antara -90 dan 90'),
  longitude: z.number().min(-180).max(180, 'Longitude harus di antara -180 dan 180'),
  timezone: z.string().default('Asia/Jakarta'),
  is_active: z.boolean().default(true),
});

export const updateOutletSchema = createOutletSchema.partial();

export const nearestOutletQuerySchema = z.object({
  lat: z.coerce.number().min(-90).max(90, 'Latitude tidak valid'),
  lng: z.coerce.number().min(-180).max(180, 'Longitude tidak valid'),
});

export type CreateOutletInput = z.infer<typeof createOutletSchema>;
export type UpdateOutletInput = z.infer<typeof updateOutletSchema>;
