import { Request, Response, NextFunction } from 'express';
import { feedbackService } from './feedback.service';
import { createFeedbackSchema } from './feedback.schema';

export const submitFeedback = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const input = createFeedbackSchema.parse(req.body);
    const userId = (req as any).user.id;
    const feedback = await feedbackService.createFeedback(userId, input);
    res.status(201).json({ data: feedback });
  } catch (err) {
    next(err);
  }
};

export const getFeedbacks = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const user = (req as any).user;
    const userId = user?.role === 'owner' ? undefined : user?.id;
    const feedbacks = await feedbackService.listFeedbacks(userId);
    res.status(200).json({ data: feedbacks });
  } catch (err) {
    next(err);
  }
};
