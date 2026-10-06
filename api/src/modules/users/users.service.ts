import { Role } from '@prisma/client';
import { prisma } from '../../config/db';
import { AppError } from '../../shared/errors';
import { hashPassword } from '../../shared/tokens';

export class UsersService {
  async listUsers(query: { role?: Role; is_active?: boolean; q?: string; page?: number; page_size?: number }) {
    const page = query.page ?? 1;
    const pageSize = Math.min(query.page_size ?? 20, 100);
    const skip = (page - 1) * pageSize;

    const where: any = {};
    if (query.role) where.role = query.role;
    if (typeof query.is_active === 'boolean') where.is_active = query.is_active;
    if (query.q) {
      where.OR = [
        { name: { contains: query.q, mode: 'insensitive' } },
        { email: { contains: query.q, mode: 'insensitive' } },
      ];
    }

    const [total, users] = await Promise.all([
      prisma.user.count({ where }),
      prisma.user.findMany({
        where,
        skip,
        take: pageSize,
        orderBy: { created_at: 'desc' },
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          is_active: true,
          created_at: true,
          user_outlets: {
            include: { outlet: { select: { id: true, name: true } } },
          },
        },
      }),
    ]);

    return {
      users: users.map((u) => ({
        ...u,
        outlets: u.user_outlets.map((uo) => uo.outlet),
      })),
      meta: {
        page,
        page_size: pageSize,
        total,
      },
    };
  }

  async createUser(data: {
    name: string;
    email: string;
    password: string;
    role: Role;
    outlet_ids: string[];
  }) {
    const existing = await prisma.user.findUnique({
      where: { email: data.email.toLowerCase() },
    });
    if (existing) {
      throw new AppError('USER_EMAIL_DUPLICATE', 409, 'Email sudah terdaftar pada sistem.');
    }

    const password_hash = await hashPassword(data.password);

    const newUser = await prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          name: data.name,
          email: data.email.toLowerCase(),
          password_hash,
          role: data.role,
          settings: {
            create: {
              display_currency: 'IDR',
              display_timezone: 'Asia/Jakarta',
            },
          },
        },
      });

      if (data.outlet_ids.length > 0) {
        await tx.userOutlet.createMany({
          data: data.outlet_ids.map((outlet_id) => ({
            user_id: user.id,
            outlet_id,
          })),
        });
      }

      return user;
    });

    return {
      id: newUser.id,
      name: newUser.name,
      email: newUser.email,
      role: newUser.role,
      is_active: newUser.is_active,
    };
  }

  async updateUser(
    id: string,
    data: {
      name?: string;
      role?: Role;
      is_active?: boolean;
      outlet_ids?: string[];
    }
  ) {
    const existing = await prisma.user.findUnique({ where: { id } });
    if (!existing) {
      throw new AppError('NOT_FOUND', 404, 'Pengguna tidak ditemukan.');
    }

    const updated = await prisma.$transaction(async (tx) => {
      const user = await tx.user.update({
        where: { id },
        data: {
          name: data.name,
          role: data.role,
          is_active: data.is_active,
        },
        select: {
          id: true,
          name: true,
          email: true,
          role: true,
          is_active: true,
        },
      });

      if (data.outlet_ids !== undefined) {
        await tx.userOutlet.deleteMany({ where: { user_id: id } });
        if (data.outlet_ids.length > 0) {
          await tx.userOutlet.createMany({
            data: data.outlet_ids.map((outlet_id) => ({
              user_id: id,
              outlet_id,
            })),
          });
        }
      }

      // Jika user dinonaktifkan, cabut semua token aktif (BR-AUTH-04)
      if (data.is_active === false) {
        await tx.refreshToken.updateMany({
          where: { user_id: id, revoked_at: null },
          data: { revoked_at: new Date() },
        });
      }

      return user;
    });

    return updated;
  }
}

export const usersService = new UsersService();
