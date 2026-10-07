import { Router } from 'express';
import { gameController } from './game.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();

router.use('/game', requireAuth);

router.get('/game/scenarios', (req, res, next) => gameController.getScenarios(req, res, next));
router.post('/game/sessions', (req, res, next) => gameController.submitSession(req, res, next));

export default router;
