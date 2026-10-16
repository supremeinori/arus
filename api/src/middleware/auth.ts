import { Request, Response, NextFunction } from 'express';
import { Role } from '@prisma/client';
import { verifyAccessToken } from '../shared/jwt';
import { AppError } from '../shared/errors';
import { prisma } from '../config/db';

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        email: string;
        name: string;
        role: Role;
      };
      userOutlets?: string[];
    }
  }
}

export async function requireAuth(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new AppError('AUTH_SESSION_INVALID', 401, 'Token autentikasi diperlukan.');
    }

    const token = authHeader.substring(7);
    const decoded = verifyAccessToken(token);

    let user = null;
    try {
      user = await prisma.user.findUnique({
        where: { id: decoded.sub },
        select: { id: true, email: true, name: true, role: true, is_active: true },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memvalidasi sesi.');
    }

    if (!user || !user.is_active) {
      throw new AppError('AUTH_SESSION_INVALID', 401, 'Sesi tidak valid atau akun dinonaktifkan.');
    }

    req.user = user;

    // Scope Outlets (SRS Section 2.2 & BR-LBS-01)
    if (user.role === Role.owner) {
      const allOutlets = typeof prisma.outlet?.findMany === 'function' ? await prisma.outlet.findMany({
        where: { is_active: true },
        select: { id: true },
      }) : [];
      req.userOutlets = (allOutlets || []).map((o) => o.id);
    } else {
      const assigned = typeof prisma.userOutlet?.findMany === 'function' ? await prisma.userOutlet.findMany({
        where: { user_id: user.id },
        select: { outlet_id: true },
      }) : [];
      req.userOutlets = (assigned || []).map((uo) => uo.outlet_id);
    }

    next();
  } catch (err) {
    next(err);
  }
}

export function requireRole(allowedRoles: Role[]) {
  return (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      return next(
        new AppError('FORBIDDEN', 403, 'Anda tidak memiliki hak akses untuk tindakan ini.')
      );
    }
    next();
  };
}

export function verifyOutletScope(req: Request, outletId: string): void {
  if (!req.userOutlets || !req.userOutlets.includes(outletId)) {
    // Gunakan 404 alih-alih 403 untuk mencegah kebocoran informasi (SRS 6.2)
    throw new AppError('NOT_FOUND', 404, 'Data outlet tidak ditemukan atau di luar wewenang Anda.');
  }
}

export async function optionalAuth(req: Request, _res: Response, next: NextFunction): Promise<void> {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next();
    }

    const token = authHeader.substring(7);
    const decoded = verifyAccessToken(token);

    const user = await prisma.user.findUnique({
      where: { id: decoded.sub },
      select: { id: true, email: true, name: true, role: true, is_active: true },
    });

    if (user && user.is_active) {
      req.user = user;
    }
    return next();
  } catch (_) {
    return next();
  }
}
