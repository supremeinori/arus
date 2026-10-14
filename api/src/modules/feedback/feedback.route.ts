import { Router } from 'express';
import { submitFeedback, getFeedbacks } from './feedback.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();

router.post('/feedback', requireAuth, submitFeedback);
router.get('/feedback', requireAuth, getFeedbacks);

export default router;
