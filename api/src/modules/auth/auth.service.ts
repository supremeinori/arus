import { randomUUID } from 'crypto';
import { prisma } from '../../config/db';
import { env } from '../../config/env';
import { AppError } from '../../shared/errors';
import { signAccessToken } from '../../shared/jwt';
import { hashPassword, verifyPassword, generateRefreshToken, hashRefreshToken } from '../../shared/tokens';
import { DEFAULT_DISPLAY_CURRENCY } from '../users/users.schema';

export class AuthService {
  private failedAttempts: Map<string, { count: number; lockedUntil?: Date }> = new Map();

  /**
   * Preferensi tampilan milik pengguna. `display_currency` diambil dari kolom
   * `User.display_currency` (sumber kebenaran), sisanya default aplikasi.
   */
  private buildSettings(user: any) {
    return {
      display_currency: user?.display_currency ?? DEFAULT_DISPLAY_CURRENCY,
      display_timezone: 'Asia/Jakarta',
      biometric_enabled: false,
      shake_refresh_enabled: true,
      tilt_enabled: true,
    };
  }

  /** Outlet yang boleh diakses user (owner: semua outlet aktif). */
  private async resolveAccessibleOutlets(user: any) {
    if (user.role === 'owner') {
      return prisma.outlet.findMany({
        where: { is_active: true },
        select: { id: true, name: true, timezone: true, address: true },
      });
    }
    return (user.outlets || [])
      .filter((uo: any) => (uo.outlet ? uo.outlet.is_active : true))
      .map((uo: any) => ({
        id: uo.outlet?.id || uo.id,
        name: uo.outlet?.name || uo.name,
        timezone: uo.outlet?.timezone || uo.timezone,
        address: uo.outlet?.address || uo.address,
      }));
  }

  async login(emailInput: string, passwordInput: string, deviceLabel?: string) {
    const email = emailInput.trim().toLowerCase();

    let user: any = null;
    try {
      user = await prisma.user.findUnique({
        where: { email },
        include: {
          outlets: {
            include: { outlet: true },
          },
        },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memproses login.');
    }

    if (!user || !user.is_active) {
      throw new AppError(
        'AUTH_INVALID_CREDENTIALS',
        401,
        'Email atau password yang Anda masukkan salah.'
      );
    }

    const userLockedUntil = (user as any).locked_until;
    if (userLockedUntil && new Date(userLockedUntil) > new Date()) {
      throw new AppError(
        'AUTH_LOCKED',
        423,
        'Akun dikunci sementara karena terlalu banyak percobaan. Coba lagi nanti.'
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
    const rawRefreshToken = generateRefreshToken();
    const tokenHash = hashRefreshToken(rawRefreshToken);
    const expiresAt = new Date(Date.now() + env.REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);

    if (prisma.refreshToken?.create) {
      try {
        await prisma.refreshToken.create({
          data: {
            user_id: user.id,
            token_hash: tokenHash,
            family_id: randomUUID(),
            expires_at: expiresAt,
          },
        });
      } catch (_) {}
    }

    const accessibleOutlets = await this.resolveAccessibleOutlets(user);

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
        settings: this.buildSettings(user),
      },
    };
  }

  async refresh(rawToken: string) {
    if (!rawToken) {
      throw new AppError('AUTH_SESSION_INVALID', 401, 'Token refresh diperlukan.');
    }

    const tokenHash = hashRefreshToken(rawToken);

    let tokenRecord: any = null;
    try {
      tokenRecord = await prisma.refreshToken.findUnique({
        where: { token_hash: tokenHash },
        include: { user: true },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memperbarui sesi.');
    }

    if (!tokenRecord) {
      throw new AppError('AUTH_SESSION_INVALID', 401, 'Sesi tidak valid. Silakan login kembali.');
    }

    // REUSE DETECTION (BR-AUTH-02): Jika token yang sudah di-rotate dipakai lagi, cabut seluruh keluarga token
    if (tokenRecord.revoked_at !== null) {
      await prisma.refreshToken.updateMany({
        where: { family_id: tokenRecord.family_id },
        data: { revoked_at: new Date() },
      });
      throw new AppError(
        'AUTH_REFRESH_REUSED',
        401,
        'Terdeteksi penggunaan ulang token sesi yang mencurigakan. Seluruh sesi dicabut.'
      );
    }

    // Cek kedaluwarsa
    if (tokenRecord.expires_at < new Date()) {
      await prisma.refreshToken.update({
        where: { id: tokenRecord.id },
        data: { revoked_at: new Date() },
      });
      throw new AppError('AUTH_TOKEN_EXPIRED', 401, 'Sesi telah kedaluwarsa. Silakan login kembali.');
    }

    if (!tokenRecord.user || !tokenRecord.user.is_active) {
      throw new AppError('AUTH_SESSION_INVALID', 401, 'Akun pengguna dinonaktifkan.');
    }

    // ROTASI TOKEN: Cabut token lama, buat token baru dalam family yang sama
    const newRawRefreshToken = generateRefreshToken();
    const newTokenHash = hashRefreshToken(newRawRefreshToken);
    const expiresAt = new Date(Date.now() + env.REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);

    await prisma.$transaction([
      prisma.refreshToken.update({
        where: { id: tokenRecord.id },
        data: {
          revoked_at: new Date(),
          replaced_by: newTokenHash,
        },
      }),
      prisma.refreshToken.create({
        data: {
          user_id: tokenRecord.user_id,
          token_hash: newTokenHash,
          family_id: tokenRecord.family_id,
          expires_at: expiresAt,
        },
      }),
    ]);

    const accessToken = signAccessToken({
      sub: tokenRecord.user.id,
      role: tokenRecord.user.role,
      email: tokenRecord.user.email,
    });

    // PENTING: user ikut dikembalikan. Tanpa ini, sisi client akan mengganti
    // profil sesi dengan user kosong sehingga display_currency (dan outlet)
    // hilang setiap kali token di-refresh.
    const refreshedUser = tokenRecord.user;
    const accessibleOutlets = await this.resolveAccessibleOutlets(refreshedUser);
    const settings = this.buildSettings(refreshedUser);

    return {
      access_token: accessToken,
      refresh_token: newRawRefreshToken,
      expires_in: env.JWT_ACCESS_TTL_SEC,
      user: {
        id: refreshedUser.id,
        name: refreshedUser.name,
        email: refreshedUser.email,
        role: refreshedUser.role,
        avatar_url:
          refreshedUser.avatar_url ||
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
        outlets: accessibleOutlets,
        settings,
      },
      settings,
    };
  }

  async logout(rawToken?: string) {
    // Stateless token - client drops token from local secure storage
    return;
  }

  async getMe(userId: string) {
    return this.me(userId);
  }

  async me(userId: string) {
    let user: any = null;
    try {
      user = await prisma.user.findUnique({
        where: { id: userId },
        include: {
          outlets: {
            include: { outlet: true },
          },
        },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memuat profil.');
    }

    if (!user) {
      throw new AppError('NOT_FOUND', 404, 'Pengguna tidak ditemukan.');
    }

    const outlets = await this.resolveAccessibleOutlets(user);
    const settings = this.buildSettings(user);

    return {
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        avatar_url: user.avatar_url,
        outlets,
        settings,
      },
      outlets,
      settings,
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
    try {
      const updated = await prisma.user.update({
        where: { id: userId },
        data: {
          name: data.name,
        },
        select: { id: true, name: true, email: true, role: true },
      });
      return updated;
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memperbarui profil.');
    }
  }

  async changePassword(userId: string, currentPass: string, newPass: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new AppError('NOT_FOUND', 404, 'Pengguna tidak ditemukan.');

    const isValid = await verifyPassword(currentPass, user.password_hash);
    if (!isValid) {
      throw new AppError('AUTH_INVALID_CREDENTIALS', 400, 'Password saat ini tidak cocok.');
    }

    const newHash = await hashPassword(newPass);

    try {
      await prisma.user.update({
        where: { id: userId },
        data: { password_hash: newHash },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal mengubah password.');
    }
  }
}

export const authService = new AuthService();
