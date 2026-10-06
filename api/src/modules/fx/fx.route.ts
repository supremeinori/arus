import { Router } from 'express';
import { FxController } from './fx.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();
const controller = new FxController();

router.use('/fx', requireAuth);

// 1. GET /api/fx/rates - Kurs IDR, USD, EUR
router.get('/fx/rates', (req, res, next) => controller.getRates(req, res, next));

// 2. GET /api/fx/convert - Konversi nilai mata uang
router.get('/fx/convert', (req, res, next) => controller.convert(req, res, next));

export default router;
