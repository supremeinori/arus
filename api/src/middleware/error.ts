import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { AppError, ErrorCodes } from '../shared/errors';
import { logger } from '../config/logger';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const requestId = req.id || 'unknown';

  if (err instanceof ZodError) {
    const details = err.issues.map((issue) => ({
      field: issue.path.join('.'),
      issue: issue.message,
    }));
    logger.warn({
      requestId,
      code: ErrorCodes.VALIDATION_FAILED,
      message: 'Validasi input gagal.',
      statusCode: 400,
      details,
    });
    res.status(400).json({
      error: {
        code: ErrorCodes.VALIDATION_FAILED,
        message: 'Validasi input gagal.',
        details,
        request_id: requestId,
      },
    });
    return;
  }

  if (err instanceof AppError) {
    logger.warn({
      requestId,
      code: err.code,
      message: err.message,
      statusCode: err.statusCode,
      details: err.details,
    });

    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        details: err.details,
        request_id: requestId,
      },
    });
    return;
  }

  // Unexpected / Internal errors
  logger.error({
    requestId,
    err,
    url: req.originalUrl,
    method: req.method,
  }, 'Unhandled internal error');

  res.status(500).json({
    error: {
      code: ErrorCodes.INTERNAL,
      message: err?.message || 'Terjadi kesalahan pada server. Tim kami akan memeriksa.',
      details: err?.message || String(err),
      request_id: requestId,
    },
  });
}
