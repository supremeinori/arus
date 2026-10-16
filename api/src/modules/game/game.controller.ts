import { Request, Response, NextFunction } from 'express';
import { GameMode } from '@prisma/client';
import { gameService } from './game.service';
import { AppError } from '../../shared/errors';

export class GameController {
  async getQuestions(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const modeParam = (req.query.mode as string) || 'guess_name';
      const limitParam = parseInt(req.query.limit as string) || 5;

      const mode = modeParam === 'guess_price' ? GameMode.guess_price : GameMode.guess_name;
      const data = await gameService.getQuestions(mode, limitParam);

      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }

  async saveSession(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user?.id;
      if (!userId) {
        throw new AppError('AUTH_UNAUTHORIZED', 401, 'Silakan login terlebih dahulu.');
      }

      const { mode, score, correct_count, total_questions, duration_sec } = req.body;

      if (!mode || typeof score !== 'number') {
        throw new AppError('VALIDATION_ERROR', 400, 'Payload game session tidak valid.');
      }

      const gameMode = mode === 'guess_price' ? GameMode.guess_price : GameMode.guess_name;

      const result = await gameService.saveSession(userId, {
        mode: gameMode,
        score: Math.max(0, score),
        correct_count: correct_count || 0,
        total_questions: total_questions || 5,
        duration_sec: duration_sec || 0,
      });

      res.status(201).json({ data: result });
    } catch (err) {
      next(err);
    }
  }

  async getUserStats(req: Request, res: Response, next: NextFunction): Promise<void> {
    try {
      const userId = req.user?.id;
      if (!userId) {
        throw new AppError('AUTH_UNAUTHORIZED', 401, 'Silakan login terlebih dahulu.');
      }

      const data = await gameService.getUserStats(userId);
      res.status(200).json({ data });
    } catch (err) {
      next(err);
    }
  }
}

export const gameController = new GameController();
