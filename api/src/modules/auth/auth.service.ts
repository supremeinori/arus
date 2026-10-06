import { randomUUID } from 'crypto';
import { prisma } from '../../config/db';
import { env } from '../../config/env';
import { AppError } from '../../shared/errors';
import { signAccessToken } from '../../shared/jwt';
import {
  hashPassword,
  verifyPassword,
  generateRefreshToken,
  hashRefreshToken,
} from '../../shared/tokens';

export class AuthService {
  async login(emailInput: string, passwordInput: string, deviceLabel?: string) {
    const email = emailInput.trim().toLowerCase();

    const user = await prisma.user.findUnique({
      where: { email },
      include: {
        user_outlets: {
          include: { outlet: true },
        },
        settings: true,
      },
    });

    if (!user || !user.is_active) {
      throw new AppError(
        'AUTH_INVALID_CREDENTIALS',
        401,
        'Email atau password yang Anda masukkan salah.'
      );
    }

    // Periksa status penguncian akun (BR-AUTH-05)
    if (user.locked_until && user.locked_until > new Date()) {
      const remainingMinutes = Math.ceil(
        (user.locked_until.getTime() - Date.now()) / (60 * 1000)
      );
      throw new AppError(
        'AUTH_LOCKED',
        423,
        `Akun dikunci sementara karena terlalu banyak percobaan. Coba lagi dalam ${remainingMinutes} menit.`
      );
    }

    // Verifikasi password
    const isPasswordValid = await verifyPassword(passwordInput, user.password_hash);
    if (!isPasswordValid) {
      const newFailedCount = user.failed_login_count + 1;
      let lockUntil: Date | null = null;

      if (newFailedCount >= 5) {
        lockUntil = new Date(Date.now() + 15 * 60 * 1000); // Kunci 15 menit
      }

      await prisma.user.update({
        where: { id: user.id },
        data: {
          failed_login_count: newFailedCount >= 5 ? 0 : newFailedCount,
          locked_until: lockUntil,
        },
      });

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

    // Reset failed counter & update last login
    await prisma.user.update({
      where: { id: user.id },
      data: {
        failed_login_count: 0,
        locked_until: null,
        last_login_at: new Date(),
      },
    });

    // Generate JWT access token (15 menit)
    const accessToken = signAccessToken({
      sub: user.id,
      role: user.role,
      email: user.email,
    });

    // Generate Rotating Refresh Token (7 hari)
    const rawRefreshToken = generateRefreshToken();
    const tokenHash = hashRefreshToken(rawRefreshToken);
    const familyId = randomUUID();
    const expiresAt = new Date(Date.now() + env.REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000);

    await prisma.refreshToken.create({
      data: {
        user_id: user.id,
        token_hash: tokenHash,
        family_id: familyId,
        expires_at: expiresAt,
        device_label: deviceLabel,
      },
    });

    // Format outlets
    let accessibleOutlets = [];
    if (user.role === 'owner') {
      accessibleOutlets = await prisma.outlet.findMany({
        where: { is_active: true },
        select: { id: true, name: true, timezone: true, address: true },
      });
    } else {
      accessibleOutlets = user.user_outlets.map((uo) => ({
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
        outlets: accessibleOutlets,
        settings: user.settings,
      },
    };
  }

  async refresh(rawToken: string) {
    const tokenHash = hashRefreshToken(rawToken);

    const tokenRecord = await prisma.refreshToken.findUnique({
      where: { token_hash: tokenHash },
      include: { user: true },
    });

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

    if (!tokenRecord.user.is_active) {
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

    return {
      access_token: accessToken,
      refresh_token: newRawRefreshToken,
      expires_in: env.JWT_ACCESS_TTL_SEC,
    };
  }

  async logout(rawToken?: string) {
    if (rawToken) {
      const tokenHash = hashRefreshToken(rawToken);
      await prisma.refreshToken.updateMany({
        where: { token_hash: tokenHash },
        data: { revoked_at: new Date() },
      });
    }
  }

  async getMe(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        user_outlets: {
          include: { outlet: true },
        },
        settings: true,
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
      outlets = user.user_outlets.map((uo) => ({
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
      },
      outlets,
      settings: user.settings,
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

    await prisma.$transaction([
      prisma.user.update({
        where: { id: userId },
        data: { password_hash: newHash },
      }),
      // Cabut seluruh refresh token aktif untuk keamanan
      prisma.refreshToken.updateMany({
        where: { user_id: userId, revoked_at: null },
        data: { revoked_at: new Date() },
      }),
    ]);
  }
}

export const authService = new AuthService();
