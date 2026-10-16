import { randomUUID } from 'crypto';
import { prisma } from '../../config/db';
import { isDbAvailable } from '../../config/db-health';
import { env } from '../../config/env';
import { AppError } from '../../shared/errors';
import { signAccessToken, signRefreshToken, verifyRefreshToken } from '../../shared/jwt';
import {
  hashPassword,
  verifyPassword,
} from '../../shared/tokens';

export class AuthService {
  private failedAttempts: Map<string, { count: number; lockedUntil?: Date }> = new Map();

  private demoLogin(email: string, passwordInput: string) {
    const validPasswords = ['Demo1234', 'password123', 'demo1234', 'Password123!', 'password123!', 'owner123', 'staff123'];
    const demoAccounts: Record<string, { id: string; name: string; role: any }> = {
      'owner@arus.demo': {
        id: 'u-owner-001',
        name: 'Rina Kartika (Owner)',
        role: 'owner',
      },
      'owner@arus.local': {
        id: 'u-owner-001',
        name: 'Rina Kartika (Owner)',
        role: 'owner',
      },
      'manager@arus.demo': {
        id: 'u-mgr-001',
        name: 'Budi Santoso (Manager)',
        role: 'manager',
      },
      'manager@arus.local': {
        id: 'u-mgr-001',
        name: 'Budi Santoso (Manager)',
        role: 'manager',
      },
      'staff@arus.demo': {
        id: 'u-staff-001',
        name: 'Siti Rahma (Kasir)',
        role: 'staff',
      },
      'staff@arus.local': {
        id: 'u-staff-001',
        name: 'Siti Rahma (Kasir)',
        role: 'staff',
      },
    };

    const targetAccount = demoAccounts[email];
    if (!targetAccount) {
      throw new AppError(
        'AUTH_INVALID_CREDENTIALS',
        401,
        'Email atau password demo yang Anda masukkan salah.'
      );
    }

    if (!validPasswords.includes(passwordInput)) {
      throw new AppError(
        'AUTH_INVALID_CREDENTIALS',
        401,
        'Password salah. Gunakan password demo default "Demo1234".'
      );
    }

    const accessToken = signAccessToken({
      sub: targetAccount.id,
      role: targetAccount.role,
      email,
    });
    const rawRefreshToken = signRefreshToken({
      sub: targetAccount.id,
      role: targetAccount.role,
      email,
    });

    return {
      access_token: accessToken,
      refresh_token: rawRefreshToken,
      expires_in: env.JWT_ACCESS_TTL_SEC,
      user: {
        id: targetAccount.id,
        name: targetAccount.name,
        email,
        role: targetAccount.role,
        avatar_url: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
        outlets: [
          { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)', timezone: 'Asia/Jakarta', address: 'Jl. Jend. Sudirman No. 45, Jakarta Pusat' },
          { id: 'out-002', name: 'Kopi Arus - Senopati', timezone: 'Asia/Jakarta', address: 'Jl. Senopati No. 12, Jakarta Selatan' },
          { id: 'out-003', name: 'Kopi Arus - Canggu', timezone: 'Asia/Makassar', address: 'Jl. Pantai Batu Bolong, Bali' },
        ],
        settings: {
          display_currency: 'IDR',
          display_timezone: 'Asia/Jakarta',
          biometric_enabled: false,
          shake_refresh_enabled: true,
          tilt_enabled: true,
        },
      },
    };
  }

  async login(emailInput: string, passwordInput: string, deviceLabel?: string) {
    const email = emailInput.trim().toLowerCase();

    let user: any = null;
    if (!(await isDbAvailable())) {
      return this.demoLogin(email, passwordInput);
    }

    try {
      user = await prisma.user.findUnique({
        where: { email },
        include: {
          outlets: {
            include: { outlet: true },
          },
        },
      });
    } catch (_) {
      return this.demoLogin(email, passwordInput);
    }

    if (!user || !user.is_active) {
      throw new AppError(
        'AUTH_INVALID_CREDENTIALS',
        401,
        'Email atau password yang Anda masukkan salah.'
      );
    }

    const lockInfo = this.failedAttempts.get(email);
    if (lockInfo?.lockedUntil && lockInfo.lockedUntil > new Date()) {
      const remainingMinutes = Math.ceil(
        (lockInfo.lockedUntil.getTime() - Date.now()) / (60 * 1000)
      );
      throw new AppError(
        'AUTH_LOCKED',
        423,
        `Akun dikunci sementara karena terlalu banyak percobaan. Coba lagi dalam ${remainingMinutes} menit.`
      );
    }

    const isPasswordValid = await verifyPassword(passwordInput, user.password_hash);
    if (!isPasswordValid) {
      const currentCount = (lockInfo?.count || 0) + 1;
      let lockUntil: Date | undefined = undefined;
      if (currentCount >= 5) {
        lockUntil = new Date(Date.now() + 15 * 60 * 1000);
      }
      this.failedAttempts.set(email, { count: currentCount >= 5 ? 0 : currentCount, lockedUntil: lockUntil });

      if (lockUntil) {
        throw new AppError(
          'AUTH_LOCKED',
          423,
          'Akun dikunci sementara selama 15 menit karena 5 kali percobaan gagal berturut-turut.'
        );
      }

      throw new AppError(
        'AUTH_INVALID_CREDENTIALS',
        401,
        'Email atau password yang Anda masukkan salah.'
      );
    }

    this.failedAttempts.delete(email);

    const accessToken = signAccessToken({
      sub: user.id,
      role: user.role,
      email: user.email,
    });
    const rawRefreshToken = signRefreshToken({
      sub: user.id,
      role: user.role,
      email: user.email,
    });

    let accessibleOutlets = [];
    if (user.role === 'owner') {
      accessibleOutlets = await prisma.outlet.findMany({
        where: { is_active: true },
        select: { id: true, name: true, timezone: true, address: true },
      });
    } else {
      accessibleOutlets = user.outlets.map((uo: any) => ({
        id: uo.outlet.id,
        name: uo.outlet.name,
        timezone: uo.outlet.timezone,
        address: uo.outlet.address,
      }));
    }

    return {
      access_token: accessToken,
      refresh_token: rawRefreshToken,
      expires_in: env.JWT_ACCESS_TTL_SEC,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        avatar_url: user.avatar_url || 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
        outlets: accessibleOutlets,
        settings: {
          display_currency: 'IDR',
          display_timezone: 'Asia/Jakarta',
          biometric_enabled: false,
          shake_refresh_enabled: true,
          tilt_enabled: true,
        },
      },
    };
  }

  async refresh(rawToken: string) {
    if (rawToken && rawToken.startsWith('demo-refresh-')) {
      const accessToken = signAccessToken({
        sub: 'u-owner-001',
        role: 'owner',
        email: 'owner@arus.demo',
      });
      return {
        access_token: accessToken,
        refresh_token: signRefreshToken({
          sub: 'u-owner-001',
          role: 'owner',
          email: 'owner@arus.demo',
        }),
        expires_in: env.JWT_ACCESS_TTL_SEC,
        user: {
          id: 'u-owner-001',
          name: 'Rina Kartika (Owner)',
          email: 'owner@arus.demo',
          role: 'owner',
          outlets: [],
        },
      };
    }

    const payload = verifyRefreshToken(rawToken);
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
    });

    if (!user || !user.is_active) {
      throw new AppError('AUTH_SESSION_INVALID', 401, 'Sesi tidak valid atau akun dinonaktifkan.');
    }

    const newAccessToken = signAccessToken({
      sub: user.id,
      role: user.role,
      email: user.email,
    });
    const newRefreshToken = signRefreshToken({
      sub: user.id,
      role: user.role,
      email: user.email,
    });

    return {
      access_token: newAccessToken,
      refresh_token: newRefreshToken,
      expires_in: env.JWT_ACCESS_TTL_SEC,
    };
  }

  async logout(rawToken?: string) {
    // Stateless token - client drops token from flutter_secure_storage
    return;
  }

  async getMe(userId: string) {
    return this.me(userId);
  }

  async me(userId: string) {
    if (userId.startsWith('u-')) {
      return {
        user: {
          id: userId,
          name: userId === 'u-owner-001' ? 'Rina Kartika (Owner)' : 'Staff Kasir',
          email: userId === 'u-owner-001' ? 'owner@arus.demo' : 'staff@arus.demo',
          role: userId === 'u-owner-001' ? 'owner' : 'staff',
        },
        outlets: [
          { id: 'out-001', name: 'Kopi Arus - Sudirman (HQ)', timezone: 'Asia/Jakarta', address: 'Jl. Jend. Sudirman No. 45, Jakarta Pusat' },
          { id: 'out-002', name: 'Kopi Arus - Senopati', timezone: 'Asia/Jakarta', address: 'Jl. Senopati No. 12, Jakarta Selatan' },
          { id: 'out-003', name: 'Kopi Arus - Canggu', timezone: 'Asia/Makassar', address: 'Jl. Pantai Batu Bolong, Bali' },
        ],
        settings: {
          display_currency: 'IDR',
          display_timezone: 'Asia/Jakarta',
          biometric_enabled: false,
          shake_refresh_enabled: true,
          tilt_enabled: true,
        },
      };
    }

    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        outlets: {
          include: { outlet: true },
        },
      },
    });

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'Pengguna tidak ditemukan.');
    }

    let outlets = [];
    if (user.role === 'owner') {
      outlets = await prisma.outlet.findMany({
        where: { is_active: true },
        select: { id: true, name: true, timezone: true, address: true },
      });
    } else {
      outlets = user.outlets.map((uo) => ({
        id: uo.outlet.id,
        name: uo.outlet.name,
        timezone: uo.outlet.timezone,
        address: uo.outlet.address,
      }));
    }

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        avatar_url: user.avatar_url,
      },
      outlets,
      settings: {
        display_currency: 'IDR',
        display_timezone: 'Asia/Jakarta',
        biometric_enabled: false,
        shake_refresh_enabled: true,
        tilt_enabled: true,
      },
      features: {
        integrity: env.FEATURE_INTEGRITY,
        notifications: env.FEATURE_NOTIFICATIONS,
        fx: env.FEATURE_FX,
        game: env.FEATURE_GAME,
        ai: env.FEATURE_AI,
      },
    };
  }

  async updateProfile(userId: string, data: { name?: string }) {
    const updated = await prisma.user.update({
      where: { id: userId },
      data: {
        name: data.name,
      },
      select: { id: true, name: true, email: true, role: true },
    });
    return updated;
  }

  async changePassword(userId: string, currentPass: string, newPass: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new AppError('NOT_FOUND', 404, 'Pengguna tidak ditemukan.');

    const isValid = await verifyPassword(currentPass, user.password_hash);
    if (!isValid) {
      throw new AppError('AUTH_INVALID_CREDENTIALS', 400, 'Password saat ini tidak cocok.');
    }

    const newHash = await hashPassword(newPass);

    await prisma.user.update({
      where: { id: userId },
      data: { password_hash: newHash },
    });
  }
}

export const authService = new AuthService();
