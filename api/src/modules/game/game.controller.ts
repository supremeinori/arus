import { Request, Response, NextFunction } from 'express';
import { gameService } from './game.service';

export class GameController {
  getScenarios(_req: Request, res: Response, next: NextFunction): void {
    try {
      const scenarios = gameService.getScenarios();
      res.status(200).json({ data: scenarios });
    } catch (err) {
      next(err);
    }
  }

  submitSession(req: Request, res: Response, next: NextFunction): void {
    try {
      const { answers } = req.body;
      const result = gameService.submitSession(answers || []);
      res.status(200).json({ data: result });
    } catch (err) {
      next(err);
    }
  }
}

export const gameController = new GameController();
