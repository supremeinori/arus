import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { AppError } from './errors';

export interface JwtPayload {
  sub: string;
  role: 'owner' | 'manager' | 'staff';
  email: string;
}

export function signAccessToken(payload: JwtPayload): string {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: env.JWT_ACCESS_TTL_SEC,
  });
}

export function verifyAccessToken(token: string): JwtPayload {
  try {
    return jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtPayload;
  } catch (err: unknown) {
    if (err instanceof jwt.TokenExpiredError) {
      throw new AppError('AUTH_TOKEN_EXPIRED', 401, 'Sesi telah berakhir. Silakan perbarui token.');
    }
    throw new AppError('AUTH_SESSION_INVALID', 401, 'Token autentikasi tidak valid.');
  }
}

export function signRefreshToken(payload: JwtPayload): string {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn: '7d',
  });
}

export function verifyRefreshToken(token: string): JwtPayload {
  try {
    return jwt.verify(token, env.JWT_ACCESS_SECRET) as JwtPayload;
  } catch (err: unknown) {
    if (err instanceof jwt.TokenExpiredError) {
      throw new AppError('AUTH_TOKEN_EXPIRED', 401, 'Sesi refresh token telah kedaluwarsa. Silakan login kembali.');
    }
    throw new AppError('AUTH_SESSION_INVALID', 401, 'Sesi tidak valid. Silakan login kembali.');
  }
}
