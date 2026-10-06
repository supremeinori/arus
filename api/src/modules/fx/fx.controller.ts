import { Request, Response, NextFunction } from 'express';
import { FxService } from './fx.service';
import { convertQuerySchema } from './fx.schema';

const fxService = new FxService();

export class FxController {
  async getRates(req: Request, res: Response, next: NextFunction) {
    try {
      const data = await fxService.getRates();
      res.json({
        success: true,
        data,
      });
    } catch (err) {
      next(err);
    }
  }

  async convert(req: Request, res: Response, next: NextFunction) {
    try {
      const validated = convertQuerySchema.parse(req.query);
      const data = await fxService.convert(validated);
      res.json({
        success: true,
        data,
      });
    } catch (err) {
      next(err);
    }
  }
}
