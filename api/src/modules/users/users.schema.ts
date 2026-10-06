import { z } from 'zod';
import { Role } from '@prisma/client';

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
