import { Router } from 'express';
import { listUsers, createUser, updateUser, getUserSettings, updateUserSettings } from './users.controller';
import { requireAuth, requireRole } from '../../middleware/auth';
import { Role } from '@prisma/client';

const router = Router();

// User settings (accessible by any authenticated user)
router.get('/users/me/settings', requireAuth, getUserSettings);
router.patch('/users/me/settings', requireAuth, updateUserSettings);

// User administration (Owner only)
router.get('/users', requireAuth, requireRole([Role.owner]), listUsers);
router.post('/users', requireAuth, requireRole([Role.owner]), createUser);
router.patch('/users/:id', requireAuth, requireRole([Role.owner]), updateUser);

export default router;
