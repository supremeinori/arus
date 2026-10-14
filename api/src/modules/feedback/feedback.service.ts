import { prisma } from '../../config/db';
import { isDbAvailable } from '../../config/db-health';
import { CreateFeedbackInput } from './feedback.schema';
import { randomUUID } from 'crypto';

interface InMemoryFeedback {
  id: string;
  user_id: string;
  kesan: string;
  saran: string;
  rating?: number | null;
  created_at: Date;
}

export class FeedbackService {
  private static inMemoryFeedbacks: InMemoryFeedback[] = [];

  async createFeedback(userId: string, input: CreateFeedbackInput) {
    if (await isDbAvailable()) {
      return prisma.feedback.create({
        data: {
          user_id: userId,
          kesan: input.kesan,
          saran: input.saran,
          rating: input.rating ?? 5,
        },
        include: {
          user: {
            select: { id: true, name: true, email: true, role: true, avatar_url: true },
          },
        },
      });
    }

    // In-memory fallback mode
    const feedback: InMemoryFeedback = {
      id: randomUUID(),
      user_id: userId,
      kesan: input.kesan,
      saran: input.saran,
      rating: input.rating ?? 5,
      created_at: new Date(),
    };
    FeedbackService.inMemoryFeedbacks.unshift(feedback);
    return feedback;
  }

  async listFeedbacks(userId?: string) {
    if (await isDbAvailable()) {
      return prisma.feedback.findMany({
        where: userId ? { user_id: userId } : undefined,
        orderBy: { created_at: 'desc' },
        include: {
          user: {
            select: { id: true, name: true, email: true, role: true, avatar_url: true },
          },
        },
      });
    }

    if (userId) {
      return FeedbackService.inMemoryFeedbacks.filter((f) => f.user_id === userId);
    }
    return FeedbackService.inMemoryFeedbacks;
  }
}

export const feedbackService = new FeedbackService();
