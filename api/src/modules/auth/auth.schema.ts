import { z } from 'zod';

export const loginSchema = z.object({
  email: z.string().email('Format email tidak valid'),
  password: z.string().min(1, 'Password tidak boleh kosong'),
});

export const refreshSchema = z.object({
  refresh_token: z.string().min(1, 'Refresh token tidak boleh kosong'),
});

export const logoutSchema = z.object({
  refresh_token: z.string().optional(),
});

export const changePasswordSchema = z.object({
  current_password: z.string().min(1, 'Password saat ini harus diisi'),
  new_password: z
    .string()
    .min(8, 'Password baru minimal 8 karakter')
    .regex(/[A-Za-z]/, 'Password baru harus mengandung minimal 1 huruf')
    .regex(/[0-9]/, 'Password baru harus mengandung minimal 1 angka'),
});

export const updateProfileSchema = z.object({
  name: z.string().min(1).max(100).optional(),
});
