import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  LOG_LEVEL: z.string().default('info'),

  DATABASE_URL: z.string().default('postgresql://postgres:postgres@localhost:5432/arus_db'),

  JWT_ACCESS_SECRET: z.string().min(32).default('arus_jwt_secret_dev_key_super_secure_32_chars_min'),
  JWT_ACCESS_TTL_SEC: z.coerce.number().default(900),
  REFRESH_TTL_DAYS: z.coerce.number().default(7),

  LLM_PROVIDER: z.enum(['gemini', 'anthropic']).default('gemini'),
  LLM_API_KEY: z.string().default(''),
  LLM_MODEL: z.string().default('gemini-2.0-flash'),
  AI_RATE_PER_MIN: z.coerce.number().default(10),
  AI_RATE_PER_DAY: z.coerce.number().default(100),

  FX_API_URL: z.string().url().default('https://api.frankfurter.dev/v1/latest'),

  FEATURE_INTEGRITY: z.coerce.boolean().default(true),
  FEATURE_NOTIFICATIONS: z.coerce.boolean().default(true),
  FEATURE_FX: z.coerce.boolean().default(true),
  FEATURE_GAME: z.coerce.boolean().default(true),
  FEATURE_AI: z.coerce.boolean().default(true),

  // Firebase Cloud Messaging (opsional). Bila kosong, push dinonaktifkan
  // dan aplikasi tetap berjalan normal.
  FIREBASE_PROJECT_ID: z.string().default(''),
  FIREBASE_CLIENT_EMAIL: z.string().default(''),
  FIREBASE_PRIVATE_KEY: z.string().default(''),
});

export const env = envSchema.parse(process.env);
