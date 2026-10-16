import { Router } from 'express';
import { gameController } from './game.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();

// Endpoint game dilindungi otentikasi
router.use('/game', requireAuth);

router.get('/game/scenarios', (req, res, next) => gameController.getScenarios(req, res, next));
router.get('/game/questions', (req, res, next) => gameController.getQuestions(req, res, next));
router.post('/game/sessions', (req, res, next) => gameController.saveSession(req, res, next));
router.get('/game/sessions/me', (req, res, next) => gameController.getUserStats(req, res, next));

export default router;
