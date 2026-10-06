import { Request, Response } from 'express';

export function getHealth(req: Request, res: Response): void {
  res.status(200).json({
    data: {
      status: 'ok',
      db: 'connected', // will be linked to prisma.$queryRaw in Milestone 2
      time: new Date().toISOString(),
      version: '1.0.0',
    },
    meta: {
      request_id: req.id,
    },
  });
}
