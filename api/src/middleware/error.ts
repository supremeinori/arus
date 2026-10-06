import { Request, Response, NextFunction } from 'express';
import { AppError, ErrorCodes } from '../shared/errors';
import { logger } from '../config/logger';

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const requestId = req.id || 'unknown';

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
      message: 'Terjadi kesalahan pada server. Tim kami akan memeriksa.',
      request_id: requestId,
    },
  });
}
