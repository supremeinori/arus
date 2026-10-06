import { Router } from 'express';
import {
  login,
  refresh,
  logout,
  getMe,
  patchMe,
  changePassword,
} from './auth.controller';
import { requireAuth } from '../../middleware/auth';

const router = Router();

// Public routes
router.post('/auth/login', login);
router.post('/auth/refresh', refresh);

// Authenticated routes
router.post('/auth/logout', requireAuth, logout);
router.get('/auth/me', requireAuth, getMe);
router.patch('/auth/me', requireAuth, patchMe);
router.post('/auth/change-password', requireAuth, changePassword);

export default router;
