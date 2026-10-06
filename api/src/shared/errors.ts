export class AppError extends Error {
  constructor(
    public readonly code: string,
    public readonly statusCode: number,
    message: string,
    public readonly details?: Array<{ field?: string; issue: string; [key: string]: unknown }>
  ) {
    super(message);
    this.name = 'AppError';
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export const ErrorCodes = {
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  NOT_FOUND: 'NOT_FOUND',
  FORBIDDEN: 'FORBIDDEN',
  INTERNAL: 'INTERNAL',
  DB_UNAVAILABLE: 'DB_UNAVAILABLE',
  AUTH_INVALID_CREDENTIALS: 'AUTH_INVALID_CREDENTIALS',
  AUTH_TOKEN_EXPIRED: 'AUTH_TOKEN_EXPIRED',
  AUTH_REFRESH_REUSED: 'AUTH_REFRESH_REUSED',
} as const;
