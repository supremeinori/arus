import { Request, Response } from 'express';
import { prisma } from '../../config/db';

export async function getHealth(req: Request, res: Response): Promise<void> {
  let dbStatus = 'disconnected';

  try {
    await prisma.$queryRaw`SELECT 1`;
    dbStatus = 'connected';
  } catch {
    dbStatus = 'disconnected';
  }

  res.status(200).json({
    data: {
      status: 'ok',
      db: dbStatus,
      time: new Date().toISOString(),
      version: '1.0.0',
    },
    meta: {
      request_id: req.id,
    },
  });
}
