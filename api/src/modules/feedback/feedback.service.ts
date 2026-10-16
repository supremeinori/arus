import { prisma } from '../../config/db';
import { CreateFeedbackInput } from './feedback.schema';
import { AppError } from '../../shared/errors';

export class FeedbackService {
  async createFeedback(userId: string, input: CreateFeedbackInput) {
    try {
      return await prisma.feedback.create({
        data: {
          user_id: userId,
          kesan: input.kesan,
          saran: input.saran,
        },
        include: {
          user: {
            select: { id: true, name: true, email: true, role: true, avatar_url: true },
          },
        },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal mengirim feedback.');
    }
  }

  async listFeedbacks(userId?: string) {
    try {
      return await prisma.feedback.findMany({
        where: userId ? { user_id: userId } : undefined,
        orderBy: { created_at: 'desc' },
        include: {
          user: {
            select: { id: true, name: true, email: true, role: true, avatar_url: true },
          },
        },
      });
    } catch (err: any) {
      if (err instanceof AppError) throw err;
      throw new AppError('DATABASE_ERROR', 503, 'Koneksi ke database terputus. Gagal memuat feedback.');
    }
  }
}

export const feedbackService = new FeedbackService();
