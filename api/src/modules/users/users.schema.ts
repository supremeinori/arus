import { z } from 'zod';
import { Role } from '@prisma/client';

/** Mata uang tampilan yang didukung (harus sinkron dengan lib/core/utils/money_formatter.dart). */
export const SUPPORTED_CURRENCIES = [
  'IDR',
  'USD',
  'EUR',
  'SGD',
  'JPY',
  'MYR',
  'GBP',
] as const;

export type Currency = (typeof SUPPORTED_CURRENCIES)[number];

/** Mata uang default bisnis. Semua nominal internal disimpan dalam IDR. */
export const DEFAULT_DISPLAY_CURRENCY: Currency = 'IDR';

export const createUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
  password: z.string().min(8),
  role: z.nativeEnum(Role),
  outlet_ids: z.array(z.string().uuid()).default([]),
});

export const updateUserSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  role: z.nativeEnum(Role).optional(),
  is_active: z.boolean().optional(),
  outlet_ids: z.array(z.string().uuid()).optional(),
});

export const updateUserSettingsSchema = z.object({
  display_currency: z.enum(SUPPORTED_CURRENCIES).optional(),
  display_timezone: z.string().min(1).max(50).optional(),
  biometric_enabled: z.boolean().optional(),
  shake_refresh_enabled: z.boolean().optional(),
  tilt_enabled: z.boolean().optional(),
  daily_revenue_target_idr: z.number().int().nonnegative().nullable().optional(),
});
